#!/usr/bin/env python3
"""Proves the test ids reach UiAutomator, the tree Appium's UiAutomator2 driver reads, on a running emulator.

CI runs it (the `android-device-ids` job in .github/workflows/build.yml) after installing the debug APK on an emulator.
It walks every screen with `adb`, dumps the accessibility tree with `uiautomator dump` at each, and checks each screen's
ids are there as `resource-id`, on the right kind of node. It also opens the deep link, signed out from a cold start and
signed in while running, and checks the care guide loads with no INTERNET permission. It needs only Python's standard
library and one device on `adb`.

    python3 tool/android_ids_check.py [--serial emulator-5554] [--out build/android-ids] [--wait 20]

The walk is a list of parts, and each part starts from a cold start (signed out, empty cart, no orders: SPEC.md §2). A
part that cannot go on (a control it must tap is missing) is recorded and the next part starts fresh, so one run
reports every missing id on every screen, then fails once at the end. In --out it leaves a screenshot of each screen,
the tree and a screenshot at each failure, `ids-seen.json` and `report.txt`.

Never run it against a phone or emulator you did not start for it: it taps, types and installs nothing else, but it
drives whatever `adb -s <serial>` points at.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

PACKAGE = "com.nthcase.sample"
DEEP_LINK = "nthcase-sample://item/7"
SPEC_IDS = re.compile(
    r"^(nav_|top_bar_|snackbar|dialog|signin_|shop_|item_|cart_|lab_|form_|gestures_|webview|slow_|orders_|settings_|lobby_)"
)


class CannotGoOn(Exception):
    """The part cannot continue: what it must tap is not there. Already recorded as a failure."""


class Device:
    def __init__(self, serial, out, wait):
        self.serial = serial
        self.out = out
        self.wait = wait
        self.seen = {}
        self.last = None
        self.part = "start"
        self.failures = []
        self.missing = {}
        self.shots = 0

    def adb(self, *args, check=True, binary=False):
        command = ["adb"] + (["-s", self.serial] if self.serial else []) + list(args)
        result = subprocess.run(command, capture_output=True, text=not binary)
        if check and result.returncode != 0:
            stderr = result.stderr if isinstance(result.stderr, str) else result.stderr.decode(errors="replace")
            raise SystemExit(f"adb {' '.join(args)} failed: {stderr.strip()}")
        return result.stdout

    def dump(self):
        for _ in range(5):
            result = self.adb("shell", "uiautomator", "dump", "/sdcard/mossgrove-window.xml", check=False)
            if "dumped" in result:
                break
            time.sleep(1)
        text = self.adb("exec-out", "cat", "/sdcard/mossgrove-window.xml", check=False)
        self.last = text
        try:
            return ET.fromstring(text)
        except ET.ParseError:
            # no window to dump (the app is starting or has stopped): an empty tree, so the wait goes on
            return ET.fromstring("<hierarchy/>")

    def app_nodes(self, root):
        return [n for n in root.iter("node") if n.get("package") == PACKAGE]

    def ids(self, root):
        return {n.get("resource-id"): n for n in self.app_nodes(root) if n.get("resource-id")}

    def _file(self, folder, name):
        os.makedirs(os.path.join(self.out, folder), exist_ok=True)
        self.shots += 1
        safe = re.sub(r"[^a-z0-9_-]+", "-", f"{self.part}-{name}".lower()).strip("-")
        return os.path.join(self.out, folder, f"{self.shots:03d}-{safe}")

    def screenshot(self, folder, name):
        path = self._file(folder, name)
        png = self.adb("exec-out", "screencap", "-p", check=False, binary=True)
        if png:
            with open(path + ".png", "wb") as f:
                f.write(png)
        return path

    def fail(self, message):
        """Records a failure with the tree and a screenshot of the moment, and goes on."""
        path = self.screenshot("failures", message[:40])
        if self.last:
            with open(path + ".xml", "w") as f:
                f.write(self.last)
        self.failures.append((self.part, message))
        print(f"FAIL [{self.part}] {message}", flush=True)

    def expect(self, *wanted, timeout=None):
        """Waits until every id is on screen as a resource-id; records each one that never came. Returns the ids seen."""
        deadline = time.time() + (timeout or self.wait)
        while True:
            have = self.ids(self.dump())
            if all(w in have for w in wanted) or time.time() > deadline:
                break
            time.sleep(1)
        for w in wanted:
            if w in have:
                node = have[w]
                self.seen[w] = {"class": node.get("class"), "text": node.get("text"), "content-desc": node.get("content-desc")}
        absent = [w for w in wanted if w not in have]
        if absent:
            self.missing.setdefault(self.part, []).extend(a for a in absent if a not in self.missing.get(self.part, []))
            self.fail(f"missing {absent}; on screen: {sorted(have)}")
        else:
            self.screenshot("screens", wanted[0])
        return have

    def node(self, id_):
        node = self.expect(id_).get(id_)
        if node is None:
            raise CannotGoOn(id_)
        return node

    def says(self, id_, text, timeout=None):
        """Waits until the node with this id reads `text` (Flutter puts a label in content-desc, a field's value in text)."""
        deadline = time.time() + (timeout or self.wait)
        while True:
            node = self.ids(self.dump()).get(id_)
            said = ((node.get("content-desc") or "") + "\n" + (node.get("text") or "")) if node is not None else None
            if said is not None and text in said:
                return
            if time.time() > deadline:
                if node is None:
                    self.expect(id_, timeout=1)
                else:
                    self.fail(f"{id_} reads {said!r}, not {text!r}")
                return
            time.sleep(1)

    def is_class(self, id_, cls):
        node = self.expect(id_).get(id_)
        if node is not None and node.get("class") != cls:
            self.fail(f"{id_} is a {node.get('class')}, not a {cls}")

    def tap(self, id_):
        bounds = self.node(id_).get("bounds")
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", bounds))
        self.adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
        time.sleep(1)

    def scroll_to(self, id_, swipes=6):
        """Swipes the screen up, then down, until the id is on screen, as Appium scrolls to an element."""
        for direction in (1, -1):
            for _ in range(swipes):
                root = self.dump()
                if id_ in self.ids(root):
                    return
                screen = root.find("node")
                bounds = screen.get("bounds") if screen is not None else "[0,0][1080,2400]"
                _, _, width, height = map(int, re.findall(r"\d+", bounds))
                low, high = str(height * 7 // 10), str(height * 3 // 10)
                start, end = (low, high) if direction == 1 else (high, low)
                self.adb("shell", "input", "swipe", str(width // 2), start, str(width // 2), end, "400")
                time.sleep(1)

    def back(self):
        self.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(1)

    def gone(self, id_, timeout=15):
        deadline = time.time() + timeout
        while id_ in self.ids(self.dump()):
            if time.time() > deadline:
                self.fail(f"{id_} is still on screen")
                return
            time.sleep(1)

    def absent(self, id_):
        """The id is not on screen now: a screen that covers another hides the one below."""
        if id_ in self.ids(self.dump()):
            self.fail(f"{id_} is on screen, and should not be")

    def cold_start(self, link=None):
        self.adb("shell", "am", "force-stop", PACKAGE)
        if link:
            self.adb("shell", "am", "start", "-W", "-a", "android.intent.action.VIEW", "-d", link, PACKAGE)
        else:
            self.adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/.MainActivity")

    def sign_in(self):
        self.expect("signin_screen", timeout=60)
        self.tap("signin_use_test_account")
        self.tap("signin_submit")


# The parts of the walk. Each starts from a cold start, signed out.


def sign_in(d):
    d.expect("signin_screen", "signin_email", "signin_password", "signin_password_toggle", "signin_submit",
             "signin_test_account", "signin_use_test_account", timeout=60)
    d.is_class("signin_email", "android.widget.EditText")
    d.is_class("signin_submit", "android.widget.Button")
    d.tap("signin_submit")
    d.says("signin_error", "Enter your email and password")
    d.tap("signin_use_test_account")
    d.says("signin_email", "tester@mossgrove.test")
    d.tap("signin_submit")
    d.expect("shop_screen", "shop_search", "shop_count", "shop_list", "shop_item_1", "shop_item_2",
             "nav_shop", "nav_cart", "nav_lab", "nav_settings")
    d.says("shop_count", "40 drawers · No. 001–040")


def orders_empty(d):
    # a fresh start has no orders (SPEC.md §2): the empty state, and Start shopping opens the Shop tab
    d.sign_in()
    d.tap("nav_lab")
    d.tap("lab_orders")
    d.expect("orders_screen", "orders_empty", "orders_empty_action", "top_bar_title", "top_bar_back")
    d.tap("orders_empty_action")
    d.expect("shop_screen")


def item_cart_order(d):
    d.sign_in()
    d.tap("shop_item_1")
    d.expect("item_screen", "item_image", "item_number", "item_name", "item_price", "item_description",
             "item_qty_decrease", "item_qty_value", "item_qty_increase", "item_add_to_cart", "top_bar_title", "top_bar_back")
    d.says("item_name", "Stoneware Mug")
    d.tap("item_qty_increase")
    d.says("item_qty_value", "2")
    d.tap("item_add_to_cart")
    d.expect("snackbar", "snackbar_text", "snackbar_action")
    d.tap("snackbar_action")
    d.expect("cart_screen", "cart_list", "cart_line_1", "cart_line_decrease_1", "cart_line_qty_1", "cart_line_increase_1",
             "cart_line_remove_1", "cart_line_total_1", "cart_total", "cart_checkout")
    d.says("cart_total", "$28.00")
    d.says("nav_cart", "Cart, 2 items")
    d.gone("snackbar")
    d.tap("cart_checkout")
    d.expect("dialog", "dialog_title", "dialog_text", "dialog_confirm", "dialog_dismiss")
    d.tap("dialog_confirm")
    d.expect("cart_empty", "cart_empty_action", "snackbar_action")
    d.tap("snackbar_action")
    # the order just placed is listed (SPEC.md §3, Orders): no empty state now
    d.expect("orders_screen", "orders_list", "orders_row_1")
    d.absent("orders_empty")
    d.back()
    # Settings › Empty the cart and orders, then Order history shows the empty state again
    d.tap("nav_settings")
    d.scroll_to("settings_reset")
    d.tap("settings_reset")
    d.expect("settings_reset_confirm", "settings_reset_cancel")
    d.tap("settings_reset_confirm")
    d.expect("snackbar", "snackbar_text")
    d.gone("snackbar")
    d.scroll_to("settings_orders")
    d.tap("settings_orders")
    d.expect("orders_screen", "orders_empty", "orders_empty_action")


def lab_form(d):
    d.sign_in()
    d.tap("nav_lab")
    d.expect("lab_screen", "lab_form", "lab_gestures", "lab_webview", "lab_slow", "lab_orders", "lab_gift_cards")
    d.tap("lab_form")
    d.expect("form_screen", "form_name", "form_email", "form_age", "form_password", "form_password_toggle")
    d.is_class("form_name", "android.widget.EditText")


def lab_gestures(d):
    d.sign_in()
    d.tap("nav_lab")
    d.tap("lab_gestures")
    d.expect("gestures_screen", "gestures_status", "gestures_orientation", "gestures_tap", "gestures_tap_count",
             "gestures_double_tap", "gestures_long_press", "gestures_swipe", "gestures_scroll")
    d.tap("gestures_tap")
    d.says("gestures_status", "Tapped")
    d.says("gestures_tap_count", "Taps: 1")


def lab_webview(d):
    permissions = d.adb("shell", "dumpsys", "package", PACKAGE)
    if "android.permission.INTERNET" in permissions:
        d.fail("the installed app holds the INTERNET permission")
    d.sign_in()
    d.tap("nav_lab")
    d.tap("lab_webview")
    d.expect("webview_screen", "webview", "webview_status")
    # the bundled page loads with no INTERNET permission
    d.says("webview_status", "Care guide loaded", timeout=30)
    if not any(n.get("class") == "android.webkit.WebView" for n in d.dump().iter("node")):
        d.fail("no android.webkit.WebView under the webview id")


def lab_slow(d):
    d.sign_in()
    d.tap("nav_lab")
    d.tap("lab_slow")
    d.expect("slow_screen", "slow_content", "slow_slot_1", "slow_slot_5", "slow_reload", timeout=15)


def gift_cards(d):
    d.sign_in()
    d.tap("nav_lab")
    d.tap("lab_gift_cards")
    deadline = time.time() + 15
    while True:
        root = d.dump()
        texts = " ".join((n.get("content-desc") or "") + " " + (n.get("text") or "") for n in d.app_nodes(root))
        if "Check a balance" in texts:
            d.screenshot("screens", "gift-cards")
            break
        if time.time() > deadline:
            d.fail("the gift-cards screen did not open")
            return
        time.sleep(1)
    stray = sorted(i for i in d.ids(root) if SPEC_IDS.match(i))
    if stray:
        d.fail(f"the gift-cards screen shows ids: {stray}")


def settings(d):
    d.sign_in()
    d.tap("nav_settings")
    d.expect("settings_screen", "settings_account_email", "settings_orders", "settings_sign_out", "settings_theme",
             "settings_theme_system", "settings_theme_light", "settings_theme_dark")
    d.says("settings_account_email", "tester@mossgrove.test")
    d.is_class("settings_theme_system", "android.widget.RadioButton")


def deep_link_signed_out(d):
    # SPEC.md §5, Deep link: signed out, sign-in comes first and the item opens right after; Back lands on the Shop
    d.cold_start(DEEP_LINK)
    d.expect("signin_screen", timeout=60)
    d.tap("signin_use_test_account")
    d.tap("signin_submit")
    d.says("item_name", "Wall Clock")
    d.says("item_number", "No. 007")
    d.absent("shop_screen")
    d.back()
    d.expect("shop_screen")


def deep_link_running(d):
    # signed in, from another tab: the item opens over the Shop tab
    d.sign_in()
    d.tap("nav_settings")
    d.expect("settings_screen")
    d.adb("shell", "am", "start", "-W", "-a", "android.intent.action.VIEW", "-d", DEEP_LINK, PACKAGE)
    d.says("item_name", "Wall Clock")
    d.says("item_number", "No. 007")
    d.back()
    d.expect("shop_screen")


def scrollables(d, name):
    """The scrollable nodes in the order UiAutomator2 meets them (`new UiSelector().scrollable(true)` takes the first),
    each named by its own resource-id or the nearest one above it: Flutter puts an id on a node around its scroller,
    with the same bounds. Leaves the tree in --out as evidence."""
    root = d.dump()
    path = d._file("lobby", name)
    with open(path + ".xml", "w") as f:
        f.write(d.last or "")
    parents = {child: parent for parent in root.iter() for child in parent}
    out = []
    for n in root.iter("node"):
        if n.get("scrollable") != "true" or n.get("package") != PACKAGE:
            continue
        owner, up = n.get("resource-id"), n
        while not owner and up in parents:
            up = parents[up]
            owner = up.get("resource-id")
        out.append((owner or "", n.get("bounds"), n.get("class")))
    with open(path + "-scrollables.txt", "w") as f:
        f.write("\n".join(f"{o} {b} {c}" for o, b, c in out) + "\n")
    return out


def lobby(d):
    # SPEC.md §5 (1.1): the pager is the first scrollable; with Show the pager off it is absent and the Top 10 row is
    # first; Saved is absent from the bar until its delay has passed. Flutter builds the Lobby once: no lab_lobby_views.
    d.sign_in()
    d.tap("nav_lab")
    d.scroll_to("lab_lobby")
    d.absent("lab_lobby_views")
    d.tap("lab_lobby")
    d.expect("lobby_screen", "lobby_touch_log", "lobby_touch_count", "lobby_touch_reset", "lobby_saved_delay",
             "lobby_saved_delay_0", "lobby_saved_delay_12", "lobby_pager_shown", "lobby_pager", "lobby_banner_1",
             "lobby_pager_position", "lobby_pager_auto", "lobby_top_row_position", "lobby_top_row",
             "lobby_top_row_tile_1", "lobby_page", "lobby_bar", "lobby_bar_home", "lobby_bar_saved")
    d.says("lobby_touch_log", "Nothing touched")
    order = [o for o, _, _ in scrollables(d, "pager-on")]
    if order[:3] != ["lobby_pager", "lobby_top_row", "lobby_page"]:
        d.fail(f"pager on: the scrollables run {order[:5]}, not lobby_pager, lobby_top_row, lobby_page")
    d.tap("lobby_pager_shown")
    time.sleep(1)
    for gone in ("lobby_pager", "lobby_pager_position", "lobby_pager_auto", "lobby_banner_1"):
        d.absent(gone)
    order = [o for o, _, _ in scrollables(d, "pager-off")]
    if not order or order[0] != "lobby_top_row":
        d.fail(f"pager off: the first scrollable is {order[:1]}, not lobby_top_row")
    d.tap("lobby_saved_delay_12")
    d.absent("lobby_bar_saved")
    d.expect("lobby_bar_home", "lobby_bar_live", "lobby_bar_offers")
    time.sleep(14)
    d.expect("lobby_bar_saved")
    d.says("lobby_touch_log", "Nothing touched")


PARTS = [sign_in, orders_empty, item_cart_order, lab_form, lab_gestures, lab_webview, lab_slow, gift_cards, settings,
         deep_link_signed_out, deep_link_running, lobby]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial", default=os.environ.get("ANDROID_SERIAL"))
    parser.add_argument("--out", default="build/android-ids")
    parser.add_argument("--wait", type=float, default=20, help="seconds to wait for a screen's ids")
    args = parser.parse_args()
    d = Device(args.serial, args.out, args.wait)

    for part in PARTS:
        d.part = part.__name__
        print(f"-- {d.part}", flush=True)
        try:
            if part not in (deep_link_signed_out,):
                d.cold_start()
            part(d)
        except CannotGoOn as stop:
            d.failures.append((d.part, f"stopped: nothing to tap at {stop}; the rest of this part was not walked"))
            print(f"FAIL [{d.part}] stopped at {stop}", flush=True)

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "ids-seen.json"), "w") as f:
        json.dump(d.seen, f, indent=2, ensure_ascii=False, sort_keys=True)
    lines = [f"{len(d.seen)} ids reached UiAutomator as resource-id"]
    lines += [f"  {id_:32} {info['class']}" for id_, info in sorted(d.seen.items())]
    if d.failures:
        lines.append(f"{len(d.failures)} failures:")
        lines += [f"  [{part}] {message}" for part, message in d.failures]
        lines.append("missing ids, by part:")
        lines += [f"  {part}: {' '.join(ids)}" for part, ids in d.missing.items()]
    report = "\n".join(lines)
    with open(os.path.join(args.out, "report.txt"), "w") as f:
        f.write(report + "\n")
    print(("FAIL: " if d.failures else "OK: ") + report)
    return 1 if d.failures else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Proves the test ids reach UiAutomator, the tree Appium's UiAutomator2 driver reads, on a running emulator.

CI runs it (the `device-ids` job in .github/workflows/build.yml) after installing the debug APK on an emulator. It walks
every screen with `adb`, dumps the accessibility tree with `uiautomator dump` at each, and checks each screen's ids
are there as `resource-id`, on the right kind of node. It also opens the deep link, and checks the care guide loads
with no INTERNET permission. It needs only Python's standard library and one device on `adb`.

    python3 tool/android_ids_check.py [--serial emulator-5554] [--out build/android-ids]

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
SPEC_IDS = re.compile(
    r"^(nav_|top_bar_|snackbar|dialog|signin_|shop_|item_|cart_|lab_|form_|gestures_|webview|slow_|orders_|settings_)"
)


class Device:
    def __init__(self, serial, out):
        self.serial = serial
        self.out = out
        self.seen = {}
        self.last = None

    def adb(self, *args, check=True):
        command = ["adb"] + (["-s", self.serial] if self.serial else []) + list(args)
        result = subprocess.run(command, capture_output=True, text=True)
        if check and result.returncode != 0:
            raise SystemExit(f"adb {' '.join(args)} failed: {result.stderr.strip()}")
        return result.stdout

    def dump(self):
        for _ in range(5):
            result = self.adb("shell", "uiautomator", "dump", "/sdcard/mossgrove-window.xml", check=False)
            if "dumped" in result:
                break
            time.sleep(1)
        text = self.adb("exec-out", "cat", "/sdcard/mossgrove-window.xml")
        self.last = text
        return ET.fromstring(text)

    def app_nodes(self, root):
        return [n for n in root.iter("node") if n.get("package") == PACKAGE]

    def ids(self, root):
        return {n.get("resource-id"): n for n in self.app_nodes(root) if n.get("resource-id")}

    def fail(self, message):
        os.makedirs(self.out, exist_ok=True)
        if self.last:
            with open(os.path.join(self.out, "last-window.xml"), "w") as f:
                f.write(self.last)
        raise SystemExit(f"FAIL: {message}")

    def expect(self, *wanted, timeout=20):
        """Waits until every id is on screen as a resource-id; returns the tree."""
        deadline = time.time() + timeout
        while True:
            root = self.dump()
            have = self.ids(root)
            if all(w in have for w in wanted):
                for w in wanted:
                    node = have[w]
                    self.seen[w] = {"class": node.get("class"), "text": node.get("text"), "content-desc": node.get("content-desc")}
                return root
            if time.time() > deadline:
                self.fail(f"missing {sorted(set(wanted) - set(have))}; on screen: {sorted(have)}")
            time.sleep(1)

    def node(self, id_):
        return self.ids(self.expect(id_))[id_]

    def says(self, id_, text, timeout=20):
        """Waits until the node with this id reads `text` (Flutter puts a label in content-desc, a field's value in text)."""
        deadline = time.time() + timeout
        while True:
            node = self.ids(self.expect(id_))[id_]
            said = (node.get("content-desc") or "") + "\n" + (node.get("text") or "")
            if text in said:
                return
            if time.time() > deadline:
                self.fail(f"{id_} reads {said!r}, not {text!r}")
            time.sleep(1)

    def is_class(self, id_, cls):
        actual = self.node(id_).get("class")
        if actual != cls:
            self.fail(f"{id_} is a {actual}, not a {cls}")

    def tap(self, id_):
        bounds = self.node(id_).get("bounds")
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", bounds))
        self.adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
        time.sleep(1)

    def back(self):
        self.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(1)

    def gone(self, id_, timeout=15):
        deadline = time.time() + timeout
        while id_ in self.ids(self.dump()):
            if time.time() > deadline:
                self.fail(f"{id_} is still on screen")
            time.sleep(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial", default=os.environ.get("ANDROID_SERIAL"))
    parser.add_argument("--out", default="build/android-ids")
    args = parser.parse_args()
    d = Device(args.serial, args.out)

    permissions = d.adb("shell", "dumpsys", "package", PACKAGE)
    if "android.permission.INTERNET" in permissions:
        d.fail("the installed app holds the INTERNET permission")

    d.adb("shell", "am", "force-stop", PACKAGE)
    d.adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/.MainActivity")

    # Sign in
    d.expect("signin_screen", "signin_email", "signin_password", "signin_password_toggle", "signin_submit",
             "signin_test_account", "signin_use_test_account", timeout=60)
    d.is_class("signin_email", "android.widget.EditText")
    d.is_class("signin_submit", "android.widget.Button")
    d.tap("signin_submit")
    d.says("signin_error", "Enter your email and password")
    d.tap("signin_use_test_account")
    d.says("signin_email", "tester@mossgrove.test")
    d.tap("signin_submit")

    # Shop, tab bar, item, snackbar, cart, dialog, orders
    d.expect("shop_screen", "shop_search", "shop_count", "shop_list", "shop_item_1", "shop_item_2",
             "nav_shop", "nav_cart", "nav_lab", "nav_settings")
    d.says("shop_count", "40 drawers · No. 001–040")
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
    d.expect("orders_screen", "orders_list", "orders_row_1")
    d.back()

    # Lab and its benches
    d.tap("nav_lab")
    d.expect("lab_screen", "lab_form", "lab_gestures", "lab_webview", "lab_slow", "lab_orders", "lab_gift_cards")
    d.tap("lab_form")
    d.expect("form_screen", "form_name", "form_email", "form_age", "form_password", "form_password_toggle")
    d.is_class("form_name", "android.widget.EditText")
    d.back()
    d.tap("lab_gestures")
    d.expect("gestures_screen", "gestures_status", "gestures_orientation", "gestures_tap", "gestures_tap_count",
             "gestures_double_tap", "gestures_long_press", "gestures_swipe", "gestures_scroll")
    d.tap("gestures_tap")
    d.says("gestures_status", "Tapped")
    d.says("gestures_tap_count", "Taps: 1")
    d.back()
    d.tap("lab_webview")
    d.expect("webview_screen", "webview", "webview_status")
    # the bundled page loads with no INTERNET permission
    d.says("webview_status", "Care guide loaded", timeout=30)
    if not any(n.get("class") == "android.webkit.WebView" for n in d.dump().iter("node")):
        d.fail("no android.webkit.WebView under the webview id")
    d.back()
    d.tap("lab_slow")
    d.expect("slow_screen", "slow_content", "slow_slot_1", "slow_slot_5", "slow_reload", timeout=15)
    d.back()
    d.tap("lab_orders")
    d.expect("orders_screen", "orders_empty", "orders_empty_action")
    d.back()
    d.tap("lab_gift_cards")
    deadline = time.time() + 15
    while True:
        root = d.dump()
        texts = " ".join((n.get("content-desc") or "") + " " + (n.get("text") or "") for n in d.app_nodes(root))
        if "Check a balance" in texts:
            break
        if time.time() > deadline:
            d.fail("the gift-cards screen did not open")
        time.sleep(1)
    stray = sorted(i for i in d.ids(root) if SPEC_IDS.match(i))
    if stray:
        d.fail(f"the gift-cards screen shows ids: {stray}")
    d.back()

    # Settings
    d.tap("nav_settings")
    d.expect("settings_screen", "settings_account_email", "settings_orders", "settings_sign_out", "settings_theme",
             "settings_theme_system", "settings_theme_light", "settings_theme_dark")
    d.says("settings_account_email", "tester@mossgrove.test")
    d.is_class("settings_theme_system", "android.widget.RadioButton")

    # The deep link, while running: the item opens over the Shop tab
    d.adb("shell", "am", "start", "-W", "-a", "android.intent.action.VIEW", "-d", "nthcase-sample://item/7", PACKAGE)
    d.says("item_name", "Wall Clock")
    d.says("item_number", "No. 007")
    d.back()
    d.expect("shop_screen")

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "ids-seen.json"), "w") as f:
        json.dump(d.seen, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"OK: {len(d.seen)} ids reached UiAutomator as resource-id")
    for id_, info in sorted(d.seen.items()):
        print(f"  {id_:32} {info['class']}")


if __name__ == "__main__":
    sys.exit(main())

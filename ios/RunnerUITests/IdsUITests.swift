import XCTest

/// Proves the test ids reach XCUITest, the tree Appium's XCUITest driver reads: each id is an element's
/// `identifier` (its accessibilityIdentifier, Appium's `name`). CI runs it on a simulator (the `ios-device-ids` job in
/// .github/workflows/build.yml); it never runs on the operator's Mac.
///
/// One test per part of the walk, each from a fresh launch (signed out, empty cart, no orders: SPEC.md §2), so a part
/// that fails leaves the others to run. A missing id is recorded with the caller's line, a screenshot and the tree, and
/// the part goes on; only a control it must tap ends the part. Every screen reached leaves a screenshot.
final class IdsUITests: XCTestCase {
  private let app = XCUIApplication()

  /// The part cannot continue: what it must tap is not there. Already recorded as a failure.
  private struct CannotGoOn: Error, CustomStringConvertible {
    let id: String
    var description: String { "nothing to tap at \(id); the rest of this part was not walked" }
  }

  override func setUp() {
    continueAfterFailure = true
    app.launch()
  }

  private func element(_ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }

  private func attach(_ name: String, tree: Bool) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
    if tree {
      let text = XCTAttachment(string: app.debugDescription)
      text.name = "\(name) (tree)"
      text.lifetime = .keepAlways
      add(text)
    }
  }

  /// Waits until every id is on screen; records each one that never came, at the caller's line. True when all came.
  @discardableResult
  private func expect(_ ids: String..., timeout: TimeInterval = 15, file: StaticString = #filePath,
                      line: UInt = #line) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    let missing = ids.filter { !element($0).waitForExistence(timeout: max(deadline.timeIntervalSinceNow, 1)) }
    if missing.isEmpty {
      attach(ids[0], tree: false)
      return true
    }
    let shown = app.descendants(matching: .any).allElementsBoundByIndex.map(\.identifier).filter { !$0.isEmpty }
    XCTFail("missing \(missing); on screen: \(shown)", file: file, line: line)
    attach("missing \(missing.joined(separator: " "))", tree: true)
    return false
  }

  /// A screen that covers another hides the one below.
  private func absent(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
    if element(id).exists {
      XCTFail("\(id) is on screen, and should not be", file: file, line: line)
      attach("\(id) on screen", tree: true)
    }
  }

  private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws {
    guard expect(id, file: file, line: line) else { throw CannotGoOn(id: id) }
    element(id).tap()
  }

  /// Swipes up, then down, until the id is on screen, as Appium scrolls to an element.
  private func scrollTo(_ id: String) {
    for swipe in [{ self.app.swipeUp(velocity: .slow) }, { self.app.swipeDown(velocity: .slow) }] {
      for _ in 0..<6 where !element(id).exists {
        swipe()
      }
    }
  }

  private func signIn() throws {
    XCTAssertTrue(element("signin_screen").waitForExistence(timeout: 60), "signin_screen after launch")
    try tap("signin_use_test_account")
    try tap("signin_submit")
  }

  func test01SignIn() throws {
    expect("signin_screen", "signin_email", "signin_password", "signin_password_toggle", "signin_submit",
           "signin_test_account", "signin_use_test_account", timeout: 60)
    XCTAssertEqual(element("signin_email").elementType, .textField)
    try tap("signin_submit")
    expect("signin_error")
    try tap("signin_use_test_account")
    try tap("signin_submit")
    expect("shop_screen", "shop_search", "shop_count", "shop_list", "shop_item_1", "nav_shop", "nav_cart", "nav_lab",
           "nav_settings")
  }

  /// A fresh start has no orders: the empty state, and Start shopping opens the Shop tab.
  func test02OrdersEmptyOnAFreshStart() throws {
    try signIn()
    try tap("nav_lab")
    try tap("lab_orders")
    expect("orders_screen", "orders_empty", "orders_empty_action", "top_bar_title", "top_bar_back")
    try tap("orders_empty_action")
    expect("shop_screen")
  }

  func test03ItemCartOrderAndEmpty() throws {
    try signIn()
    try tap("shop_item_1")
    expect("item_screen", "item_image", "item_number", "item_name", "item_price", "item_description",
           "item_qty_decrease", "item_qty_value", "item_qty_increase", "item_add_to_cart", "top_bar_title", "top_bar_back")
    try tap("item_add_to_cart")
    expect("snackbar", "snackbar_text", "snackbar_action")
    try tap("snackbar_action")
    expect("cart_screen", "cart_list", "cart_line_1", "cart_line_decrease_1", "cart_line_qty_1", "cart_line_increase_1",
           "cart_line_remove_1", "cart_line_total_1", "cart_total", "cart_checkout")
    // the snackbar sits over Check out for its 10 s
    XCTAssertTrue(element("snackbar").waitForNonExistence(timeout: 15), "the snackbar goes after 10 s")
    try tap("cart_checkout")
    expect("dialog", "dialog_title", "dialog_text", "dialog_confirm", "dialog_dismiss")
    try tap("dialog_confirm")
    expect("cart_empty", "cart_empty_action", "snackbar_action")
    try tap("snackbar_action")
    // the order just placed is listed (SPEC.md §3, Orders): no empty state now
    expect("orders_screen", "orders_list", "orders_row_1")
    absent("orders_empty")
    try tap("top_bar_back")
    // Settings › Empty the cart and orders, then Order history shows the empty state again
    try tap("nav_settings")
    scrollTo("settings_reset")
    try tap("settings_reset")
    expect("settings_reset_confirm", "settings_reset_cancel")
    try tap("settings_reset_confirm")
    expect("snackbar", "snackbar_text")
    scrollTo("settings_orders")
    try tap("settings_orders")
    expect("orders_screen", "orders_empty", "orders_empty_action")
  }

  func test04Form() throws {
    try signIn()
    try tap("nav_lab")
    expect("lab_screen", "lab_form", "lab_gestures", "lab_webview", "lab_slow", "lab_orders", "lab_gift_cards")
    try tap("lab_form")
    expect("form_screen", "form_name", "form_email", "form_age", "form_password", "form_password_toggle")
  }

  func test05Gestures() throws {
    try signIn()
    try tap("nav_lab")
    try tap("lab_gestures")
    expect("gestures_screen", "gestures_status", "gestures_orientation", "gestures_tap", "gestures_tap_count",
           "gestures_double_tap", "gestures_long_press", "gestures_swipe", "gestures_scroll")
  }

  func test06CareGuide() throws {
    try signIn()
    try tap("nav_lab")
    try tap("lab_webview")
    expect("webview_screen", "webview", "webview_status")
    XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15), "a WKWebView under the webview id")
  }

  func test07DeliverySlots() throws {
    try signIn()
    try tap("nav_lab")
    try tap("lab_slow")
    expect("slow_screen", "slow_content", "slow_slot_1", "slow_slot_5", "slow_reload")
  }

  func test08GiftCardsHaveNoIds() throws {
    try signIn()
    try tap("nav_lab")
    try tap("lab_gift_cards")
    guard app.staticTexts["Check a balance"].waitForExistence(timeout: 15) else {
      XCTFail("the gift-cards screen did not open")
      attach("no gift cards", tree: true)
      return
    }
    attach("gift cards", tree: false)
    let prefixes = ["nav_", "top_bar_", "snackbar", "dialog", "signin_", "shop_", "item_", "cart_", "lab_", "form_",
                    "gestures_", "webview", "slow_", "orders_", "settings_"]
    let identified = app.descendants(matching: .any).allElementsBoundByIndex.map(\.identifier)
      .filter { id in prefixes.contains { id.hasPrefix($0) } }
    XCTAssertEqual(identified, [], "the gift-cards screen has no ids")
  }

  func test09Settings() throws {
    try signIn()
    try tap("nav_settings")
    expect("settings_screen", "settings_account_email", "settings_orders", "settings_sign_out", "settings_theme",
           "settings_theme_system", "settings_theme_light", "settings_theme_dark")
  }

  /// SPEC.md §5, Deep link: signed out, sign-in comes first and the item opens right after it, over the Shop; Back
  /// lands on the Shop. The first CI run looked for shop_screen right after sign-in, where the item covers it.
  func test10DeepLinkSignedOut() throws {
    expect("signin_screen", timeout: 60)
    app.open(URL(string: "nthcase-sample://item/7")!)
    try signIn()
    if expect("item_name", "item_number") {
      XCTAssertEqual(element("item_name").label, "Wall Clock")
      XCTAssertEqual(element("item_number").label, "No. 007")
    }
    absent("shop_screen")
    try tap("top_bar_back")
    expect("shop_screen")
  }

  /// Signed in, from another tab: the item opens over the Shop tab, and Back lands on the Shop. The link goes to the
  /// running app the way the system sends it; `app.open(_:)` relaunched the app (a cold start is signed out), which the
  /// second CI run showed as sign-in.
  func test11DeepLinkWhileRunning() throws {
    try signIn()
    try tap("nav_settings")
    expect("settings_screen")
    XCUIDevice.shared.system.open(URL(string: "nthcase-sample://item/7")!)
    // the system may first ask to open the app
    let open = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
    if open.waitForExistence(timeout: 5) { open.tap() }
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app is in front after the link")
    if expect("item_name", "item_number") {
      XCTAssertEqual(element("item_name").label, "Wall Clock")
      XCTAssertEqual(element("item_number").label, "No. 007")
    }
    absent("signin_screen")
    absent("shop_screen")
    try tap("top_bar_back")
    expect("shop_screen")
  }
}

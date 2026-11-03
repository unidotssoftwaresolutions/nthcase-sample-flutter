import XCTest

/// Proves the test ids reach XCUITest, the tree Appium's XCUITest driver reads: each id is an element's
/// `identifier` (its accessibilityIdentifier, Appium's `name`). CI runs it on a simulator (the `device-ids` job in
/// .github/workflows/build.yml); it never runs on the operator's Mac.
final class IdsUITests: XCTestCase {
  private let app = XCUIApplication()

  override func setUp() {
    continueAfterFailure = false
    app.launch()
  }

  private func element(_ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }

  private func expect(_ ids: String..., timeout: TimeInterval = 15) {
    for id in ids {
      XCTAssertTrue(element(id).waitForExistence(timeout: timeout), "\(id) is an accessibility identifier on screen")
    }
  }

  private func tap(_ id: String) {
    expect(id)
    element(id).tap()
  }

  private func signIn() {
    tap("signin_use_test_account")
    tap("signin_submit")
    expect("shop_screen")
  }

  func testEveryScreenShowsItsIds() {
    expect("signin_screen", "signin_email", "signin_password", "signin_password_toggle", "signin_submit",
           "signin_test_account", "signin_use_test_account", timeout: 60)
    XCTAssertEqual(element("signin_email").elementType, .textField)
    tap("signin_submit")
    expect("signin_error")
    signIn()

    expect("shop_search", "shop_count", "shop_list", "shop_item_1", "nav_shop", "nav_cart", "nav_lab", "nav_settings")
    tap("shop_item_1")
    expect("item_screen", "item_image", "item_number", "item_name", "item_price", "item_description",
           "item_qty_decrease", "item_qty_value", "item_qty_increase", "item_add_to_cart", "top_bar_title", "top_bar_back")
    tap("item_add_to_cart")
    expect("snackbar", "snackbar_text", "snackbar_action")
    tap("snackbar_action")
    expect("cart_screen", "cart_list", "cart_line_1", "cart_line_decrease_1", "cart_line_qty_1", "cart_line_increase_1",
           "cart_line_remove_1", "cart_line_total_1", "cart_total", "cart_checkout")
    // the snackbar sits over Check out for its 10 s
    XCTAssertTrue(element("snackbar").waitForNonExistence(timeout: 15))
    tap("cart_checkout")
    expect("dialog", "dialog_title", "dialog_text", "dialog_confirm", "dialog_dismiss")
    tap("dialog_confirm")
    expect("cart_empty", "cart_empty_action")

    tap("nav_lab")
    expect("lab_screen", "lab_form", "lab_gestures", "lab_webview", "lab_slow", "lab_orders", "lab_gift_cards")
    tap("lab_form")
    expect("form_screen", "form_name", "form_email", "form_age", "form_password", "form_password_toggle")
    tap("top_bar_back")
    tap("lab_gestures")
    expect("gestures_screen", "gestures_status", "gestures_orientation", "gestures_tap", "gestures_tap_count",
           "gestures_double_tap", "gestures_long_press", "gestures_swipe", "gestures_scroll")
    tap("top_bar_back")
    tap("lab_webview")
    expect("webview_screen", "webview", "webview_status")
    XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15), "a WKWebView under the webview id")
    tap("top_bar_back")
    tap("lab_slow")
    expect("slow_screen", "slow_content", "slow_slot_1", "slow_slot_5", "slow_reload")
    tap("top_bar_back")
    tap("lab_orders")
    expect("orders_screen", "orders_empty", "orders_empty_action")
    tap("top_bar_back")

    tap("lab_gift_cards")
    XCTAssertTrue(app.staticTexts["Check a balance"].waitForExistence(timeout: 15))
    let prefixes = ["nav_", "top_bar_", "snackbar", "dialog", "signin_", "shop_", "item_", "cart_", "lab_", "form_",
                    "gestures_", "webview", "slow_", "orders_", "settings_"]
    let identified = app.descendants(matching: .any).allElementsBoundByIndex.map(\.identifier)
      .filter { id in prefixes.contains { id.hasPrefix($0) } }
    XCTAssertEqual(identified, [], "the gift-cards screen has no ids")
    app.buttons.element(boundBy: 0).tap()

    tap("nav_settings")
    expect("settings_screen", "settings_account_email", "settings_orders", "settings_sign_out", "settings_theme",
           "settings_theme_system", "settings_theme_light", "settings_theme_dark")
  }

  func testDeepLinkOpensTheItemAfterSignIn() {
    expect("signin_screen", timeout: 60)
    app.open(URL(string: "nthcase-sample://item/7")!)
    expect("signin_screen")
    signIn()
    expect("item_name", "item_number")
    XCTAssertEqual(element("item_number").label, "No. 007")
    tap("top_bar_back")
    expect("shop_screen")
  }
}

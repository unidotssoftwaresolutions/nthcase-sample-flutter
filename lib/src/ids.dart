/// Every test id of SPEC.md §7, by screen. The names are the spec's; the tests check this list against
/// `nthcase/test-ids.json` and check every id is on its screen, in the semantics tree Appium reads. Ids with an
/// argument take the item, slot or order number, or the aisle key. The gift-cards screen has none on purpose.
abstract final class TestIds {
  // app chrome
  static const navShop = 'nav_shop';
  static const navCart = 'nav_cart';
  static const navLab = 'nav_lab';
  static const navSettings = 'nav_settings';
  static const topBarTitle = 'top_bar_title';
  static const topBarBack = 'top_bar_back';
  static const snackbar = 'snackbar';
  static const snackbarText = 'snackbar_text';
  static const snackbarAction = 'snackbar_action';
  static const dialog = 'dialog';
  static const dialogTitle = 'dialog_title';
  static const dialogText = 'dialog_text';
  static const dialogConfirm = 'dialog_confirm';
  static const dialogDismiss = 'dialog_dismiss';

  // sign in
  static const signinScreen = 'signin_screen';
  static const signinEmail = 'signin_email';
  static const signinPassword = 'signin_password';
  static const signinPasswordToggle = 'signin_password_toggle';
  static const signinSubmit = 'signin_submit';
  static const signinError = 'signin_error';
  static const signinTestAccount = 'signin_test_account';
  static const signinUseTestAccount = 'signin_use_test_account';

  // shop (the long list)
  static const shopScreen = 'shop_screen';
  static const shopSearch = 'shop_search';
  static const shopSearchClear = 'shop_search_clear';
  static const shopCount = 'shop_count';
  static const shopList = 'shop_list';
  static const shopLoading = 'shop_loading';
  static const shopError = 'shop_error';
  static const shopRetry = 'shop_retry';
  static const shopEmpty = 'shop_empty';
  static const shopEmptyAction = 'shop_empty_action';
  static String shopItem(int id) => 'shop_item_$id';

  // item detail
  static const itemScreen = 'item_screen';
  static const itemImage = 'item_image';
  static const itemNumber = 'item_number';
  static const itemName = 'item_name';
  static const itemPrice = 'item_price';
  static const itemDescription = 'item_description';
  static const itemQtyDecrease = 'item_qty_decrease';
  static const itemQtyValue = 'item_qty_value';
  static const itemQtyIncrease = 'item_qty_increase';
  static const itemAddToCart = 'item_add_to_cart';
  static const itemNotFound = 'item_not_found';
  static const itemNotFoundAction = 'item_not_found_action';

  // cart
  static const cartScreen = 'cart_screen';
  static const cartList = 'cart_list';
  static const cartTotal = 'cart_total';
  static const cartCheckout = 'cart_checkout';
  static const cartEmpty = 'cart_empty';
  static const cartEmptyAction = 'cart_empty_action';
  static String cartLine(int id) => 'cart_line_$id';
  static String cartLineDecrease(int id) => 'cart_line_decrease_$id';
  static String cartLineQty(int id) => 'cart_line_qty_$id';
  static String cartLineIncrease(int id) => 'cart_line_increase_$id';
  static String cartLineRemove(int id) => 'cart_line_remove_$id';
  static String cartLineTotal(int id) => 'cart_line_total_$id';

  // lab (the hub of test benches)
  static const labScreen = 'lab_screen';
  static const labForm = 'lab_form';
  static const labGestures = 'lab_gestures';
  static const labWebview = 'lab_webview';
  static const labSlow = 'lab_slow';
  static const labOrders = 'lab_orders';
  static const labGiftCards = 'lab_gift_cards';
  static const labLobby = 'lab_lobby';

  // form
  static const formScreen = 'form_screen';
  static const formName = 'form_name';
  static const formNameError = 'form_name_error';
  static const formEmail = 'form_email';
  static const formEmailError = 'form_email_error';
  static const formAge = 'form_age';
  static const formAgeError = 'form_age_error';
  static const formPassword = 'form_password';
  static const formPasswordToggle = 'form_password_toggle';
  static const formPasswordError = 'form_password_error';
  static const formCategory = 'form_category';
  static const formCategoryError = 'form_category_error';
  static String formCategoryOption(String key) => 'form_category_option_$key';
  static const formDate = 'form_date';
  static const formDateError = 'form_date_error';
  static const formDatePicker = 'form_date_picker';
  static const formDateConfirm = 'form_date_confirm';
  static const formDateCancel = 'form_date_cancel';
  static const formNewsletter = 'form_newsletter';
  static const formBudget = 'form_budget';
  static const formBudgetValue = 'form_budget_value';
  static const formTerms = 'form_terms';
  static const formTermsError = 'form_terms_error';
  static const formSubmit = 'form_submit';
  static const formResult = 'form_result';

  // gestures
  static const gesturesScreen = 'gestures_screen';
  static const gesturesStatus = 'gestures_status';
  static const gesturesOrientation = 'gestures_orientation';
  static const gesturesTap = 'gestures_tap';
  static const gesturesTapCount = 'gestures_tap_count';
  static const gesturesDoubleTap = 'gestures_double_tap';
  static const gesturesLongPress = 'gestures_long_press';
  static const gesturesSwipe = 'gestures_swipe';
  static const gesturesDragSource = 'gestures_drag_source';
  static const gesturesDropTarget = 'gestures_drop_target';
  static const gesturesPinch = 'gestures_pinch';
  static const gesturesZoomValue = 'gestures_zoom_value';
  static const gesturesRotate = 'gestures_rotate';
  static const gesturesRotationValue = 'gestures_rotation_value';
  static const gesturesScroll = 'gestures_scroll';
  static const gesturesScrollTarget = 'gestures_scroll_target';

  // web view
  static const webviewScreen = 'webview_screen';
  static const webview = 'webview';
  static const webviewStatus = 'webview_status';

  // slow screen
  static const slowScreen = 'slow_screen';
  static const slowLoading = 'slow_loading';
  static const slowContent = 'slow_content';
  static const slowReload = 'slow_reload';
  static String slowSlot(int n) => 'slow_slot_$n';

  // orders (empty and error states)
  static const ordersScreen = 'orders_screen';
  static const ordersList = 'orders_list';
  static const ordersLoading = 'orders_loading';
  static const ordersEmpty = 'orders_empty';
  static const ordersEmptyAction = 'orders_empty_action';
  static const ordersError = 'orders_error';
  static const ordersRetry = 'orders_retry';
  static String ordersRow(int n) => 'orders_row_$n';

  // settings (plain Material widgets: Flutter has no second toolkit)
  static const settingsScreen = 'settings_screen';
  static const settingsAccountEmail = 'settings_account_email';
  static const settingsOrders = 'settings_orders';
  static const settingsSignOut = 'settings_sign_out';
  static const settingsTheme = 'settings_theme';
  static const settingsThemeSystem = 'settings_theme_system';
  static const settingsThemeLight = 'settings_theme_light';
  static const settingsThemeDark = 'settings_theme_dark';
  static const settingsNotifications = 'settings_notifications';
  static const settingsNotificationsStatus = 'settings_notifications_status';
  static const settingsSendNotification = 'settings_send_notification';
  static const settingsSlowLoading = 'settings_slow_loading';
  static const settingsFailLoading = 'settings_fail_loading';
  static const settingsReset = 'settings_reset';
  static const settingsResetConfirm = 'settings_reset_confirm';
  static const settingsResetCancel = 'settings_reset_cancel';
  static const settingsVersion = 'settings_version';

  // the Lobby (spec 1.1): a test bench for scrolling. Flutter builds it once, so `lab_lobby_views` is not here.
  static const lobbyScreen = 'lobby_screen';
  static const lobbyTouchLog = 'lobby_touch_log';
  static const lobbyTouchCount = 'lobby_touch_count';
  static const lobbyTouchReset = 'lobby_touch_reset';
  static const lobbySavedDelay = 'lobby_saved_delay';
  static String lobbySavedDelayChoice(int seconds) => 'lobby_saved_delay_$seconds';
  static const lobbyPagerShown = 'lobby_pager_shown';
  static const lobbyPager = 'lobby_pager';
  static String lobbyBanner(int n) => 'lobby_banner_$n';
  static const lobbyPagerPosition = 'lobby_pager_position';
  static const lobbyPagerAuto = 'lobby_pager_auto';
  static const lobbyTopRowPosition = 'lobby_top_row_position';
  static const lobbyTopRow = 'lobby_top_row';
  static String lobbyTopRowTile(int m) => 'lobby_top_row_tile_$m';
  static const lobbyPage = 'lobby_page';
  static const lobbyChips = 'lobby_chips';
  static String lobbyChip(int n) => 'lobby_chip_$n';
  static String lobbyRow(int n) => 'lobby_row_$n';
  static String lobbyRowPosition(int n) => 'lobby_row_${n}_position';
  static String lobbyRowTile(int n, int m) => 'lobby_row_${n}_tile_$m';
  static const lobbyGrid = 'lobby_grid';
  static String lobbyGridCell(int n) => 'lobby_grid_cell_$n';
  static const lobbyInnerList = 'lobby_inner_list';
  static String lobbyInnerRow(int n) => 'lobby_inner_row_$n';
  static const lobbyBoard = 'lobby_board';
  static const lobbyBoardPosition = 'lobby_board_position';

  /// [col] and [row] from 1: (13, 18) is `lobby_board_cell_m18`.
  static String lobbyBoardCell(int col, int row) => 'lobby_board_cell_${String.fromCharCode(96 + col)}$row';
  static const lobbyFooter = 'lobby_footer';
  static const lobbyBar = 'lobby_bar';
  static const lobbyBarHome = 'lobby_bar_home';
  static const lobbyBarLive = 'lobby_bar_live';
  static const lobbyBarSaved = 'lobby_bar_saved';
  static const lobbyBarOffers = 'lobby_bar_offers';
  static const lobbySavedScreen = 'lobby_saved_screen';
  static const lobbyDetail = 'lobby_detail';
  static const lobbyDetailBack = 'lobby_detail_back';
  static const lobbyPromo = 'lobby_promo';
  static const lobbyPromoBack = 'lobby_promo_back';
  static const lobbySheet = 'lobby_sheet';
  static const lobbySheetTitle = 'lobby_sheet_title';
  static const lobbySheetOpen = 'lobby_sheet_open';
  static const lobbySheetPreview = 'lobby_sheet_preview';
  static const lobbySheetSaved = 'lobby_sheet_saved';
  static const lobbySheetRate = 'lobby_sheet_rate';
  static const lobbyBarItems = [lobbyBarHome, lobbyBarLive, lobbyBarSaved, lobbyBarOffers];
  static const lobbySheetButtons = [lobbySheetOpen, lobbySheetPreview, lobbySheetSaved, lobbySheetRate];
}

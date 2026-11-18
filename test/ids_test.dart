// The id census: every id in nthcase/test-ids.json is on its screen, in the state the spec names, as a node of its
// own in the semantics tree the engine sends to Android (resource-id) and iOS (accessibilityIdentifier). Not in the
// widget tree: a Key or an id folded into a parent node would pass a widget test and still be invisible to Appium.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show CheckedState, SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/data/app_state.dart';
import 'package:mossgrove/src/data/lobby.dart';
import 'package:mossgrove/src/ids.dart';

import 'support/harness.dart';
import 'support/lobby.dart';

/// Every id seen in every state below, with the node it was on.
final Map<String, SemanticsData> seen = {};

void main() {
  final spec = jsonDecode(File('nthcase/test-ids.json').readAsStringSync()) as Map<String, Object?>;
  final entries = (spec['ids'] as List).cast<Map<String, Object?>>();
  // `lab_lobby_views` is the classic-toolkit Lobby, built by the Android and iOS apps only: Flutter has one toolkit
  final native = entries
      .map((e) => e['id'] as String)
      .where((id) => !id.startsWith('web_') && id != 'lab_lobby_views')
      .toList();

  /// Scrolls each id on screen, as Appium scrolls to an element, and checks it is there as a node of its own.
  Future<void> present(TestApp app, List<String> ids) async {
    for (final id in ids) {
      final widget = app.byId(id);
      expect(widget, findsAtLeastNWidgets(1), reason: '$id is built');
      await app.tester.ensureVisible(widget.first);
      await app.tester.pumpAndSettle();
      final nodes = app.appiumNodes();
      expect(nodes.keys, contains(id), reason: '$id is a node the platform receives');
      seen[id] = nodes[id]!;
    }
  }

  void presentNow(TestApp app, List<String> ids) {
    final nodes = app.appiumNodes();
    for (final id in ids) {
      expect(nodes.keys, contains(id), reason: '$id is a node the platform receives');
      seen[id] = nodes[id]!;
    }
  }

  testWidgets('sign in', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await present(app, [
      TestIds.signinScreen,
      TestIds.signinEmail,
      TestIds.signinPassword,
      TestIds.signinPasswordToggle,
      TestIds.signinSubmit,
      TestIds.signinTestAccount,
      TestIds.signinUseTestAccount,
    ]);
    await app.tap(TestIds.signinSubmit);
    await present(app, [TestIds.signinError]);
    semantics.dispose();
  });

  testWidgets('shop, the tab bar, and all forty rows', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await present(app, [
      TestIds.shopScreen,
      TestIds.shopSearch,
      TestIds.shopCount,
      TestIds.shopList,
      TestIds.shopItem(1),
    ]);
    presentNow(app, [TestIds.navShop, TestIds.navCart, TestIds.navLab, TestIds.navSettings]);
    final list = find.descendant(of: app.byId(TestIds.shopList), matching: find.byType(Scrollable)).first;
    for (var id = 1; id <= 40; id++) {
      await tester.scrollUntilVisible(app.byId(TestIds.shopItem(id)), 200, scrollable: list);
      await tester.pumpAndSettle();
      presentNow(app, [TestIds.shopItem(id)]);
    }
    await app.type(TestIds.shopSearch, 'zzz');
    await present(app, [TestIds.shopSearchClear, TestIds.shopEmpty, TestIds.shopEmptyAction]);
    semantics.dispose();
  });

  testWidgets('shop loading and error', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    app.state.slowLoading = true;
    await app.tap(TestIds.navLab);
    await tester.tap(app.byId(TestIds.navShop));
    await tester.pump();
    presentNow(app, [TestIds.shopLoading]);
    await app.waitOut(const Duration(seconds: 3));
    app.state
      ..slowLoading = false
      ..failFirstLoad = true;
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.navShop);
    await present(app, [TestIds.shopError, TestIds.shopRetry]);
    semantics.dispose();
  });

  testWidgets('item, snackbar, cart, dialog, empty cart, orders', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.shopItem(1));
    await present(app, [
      TestIds.itemScreen,
      TestIds.itemImage,
      TestIds.itemNumber,
      TestIds.itemName,
      TestIds.itemPrice,
      TestIds.itemDescription,
      TestIds.itemQtyDecrease,
      TestIds.itemQtyValue,
      TestIds.itemQtyIncrease,
      TestIds.itemAddToCart,
      TestIds.topBarTitle,
      TestIds.topBarBack,
    ]);
    await app.tap(TestIds.itemAddToCart);
    presentNow(app, [TestIds.snackbar, TestIds.snackbarText, TestIds.snackbarAction]);
    await app.tap(TestIds.snackbarAction);
    await present(app, [
      TestIds.cartScreen,
      TestIds.cartList,
      TestIds.cartLine(1),
      TestIds.cartLineDecrease(1),
      TestIds.cartLineQty(1),
      TestIds.cartLineIncrease(1),
      TestIds.cartLineRemove(1),
      TestIds.cartLineTotal(1),
      TestIds.cartTotal,
      TestIds.cartCheckout,
    ]);
    await app.tap(TestIds.cartCheckout);
    presentNow(app, [
      TestIds.dialog,
      TestIds.dialogTitle,
      TestIds.dialogText,
      TestIds.dialogConfirm,
      TestIds.dialogDismiss,
    ]);
    await app.tap(TestIds.dialogConfirm);
    await present(app, [TestIds.cartEmpty, TestIds.cartEmptyAction]);
    await app.tap(TestIds.snackbarAction);
    await present(app, [TestIds.ordersScreen, TestIds.ordersList, TestIds.ordersRow(1)]);
    semantics.dispose();
  });

  testWidgets('lab', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await present(app, [
      TestIds.labScreen,
      TestIds.labForm,
      TestIds.labGestures,
      TestIds.labWebview,
      TestIds.labSlow,
      TestIds.labOrders,
      TestIds.labGiftCards,
      TestIds.labLobby,
    ]);
    expect(app.appiumNodes().keys, isNot(contains('lab_lobby_views')), reason: 'Flutter builds the Lobby once');
    semantics.dispose();
  });

  testWidgets('the Lobby: every id, every tile, banner, chip, cell and line, in its state', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await openLobby(app);
    presentNow(app, [
      TestIds.lobbyScreen,
      TestIds.lobbyTouchLog,
      TestIds.lobbyTouchCount,
      TestIds.lobbyTouchReset,
      TestIds.lobbySavedDelay,
      for (final s in Lobby.delays) TestIds.lobbySavedDelayChoice(s),
      TestIds.lobbyPagerShown,
      TestIds.lobbyPager,
      TestIds.lobbyPagerPosition,
      TestIds.lobbyPagerAuto,
      TestIds.lobbyTopRowPosition,
      TestIds.lobbyTopRow,
      TestIds.lobbyPage,
      TestIds.lobbyBar,
      ...TestIds.lobbyBarItems,
    ]);

    /// Scrolls a horizontal or inner list through all its children, checking each one's node.
    Future<void> through(String listId, List<String> ids, {Offset step = const Offset(-100, 0)}) async {
      await reveal(app, listId);
      // by drags only, as a swipe scrolls: no jump (support/lobby.dart, reveal, says why)
      final area = tester.getRect(app.byId(listId));
      for (final id in ids) {
        for (var i = 0; i < 40; i++) {
          final found = app.byId(id).evaluate().isNotEmpty;
          final r = found ? tester.getRect(app.byId(id)) : null;
          if (r != null &&
              r.left >= area.left &&
              r.right <= area.right &&
              r.top >= area.top &&
              r.bottom <= area.bottom) {
            break;
          }
          await tester.dragFrom(area.center, step);
          await tester.pumpAndSettle();
        }
        presentNow(app, [id]);
      }
    }

    await through(TestIds.lobbyPager, [
      for (var n = 1; n <= Lobby.banners; n++) TestIds.lobbyBanner(n),
    ], step: const Offset(-300, 0));
    await through(TestIds.lobbyTopRow, [for (var m = 1; m <= Lobby.topTiles; m++) TestIds.lobbyTopRowTile(m)]);
    await reveal(app, TestIds.lobbyChips);
    presentNow(app, [TestIds.lobbyChips]);
    await through(TestIds.lobbyChips, [for (var n = 1; n <= Lobby.chips.length; n++) TestIds.lobbyChip(n)]);
    for (var row = 1; row <= Lobby.rows; row++) {
      await reveal(app, TestIds.lobbyRowPosition(row));
      presentNow(app, [TestIds.lobbyRowPosition(row)]);
      await reveal(app, TestIds.lobbyRow(row));
      presentNow(app, [TestIds.lobbyRow(row)]);
      await through(TestIds.lobbyRow(row), [for (var m = 1; m <= Lobby.tiles; m++) TestIds.lobbyRowTile(row, m)]);
    }
    await reveal(app, TestIds.lobbyGrid);
    presentNow(app, [TestIds.lobbyGrid]);
    // The grid is taller than the page, so Flutter keeps its cells' hidden flags from where they were when the grid
    // last changed its clipped size (lobby_test.dart, "a node taller than the page", pins this). Cells 1–6 are
    // checked on the way down, while the grid's top comes in; 7–12 on the way back up from the footer, while its
    // bottom does.
    for (var n = 1; n <= 6; n++) {
      await reveal(app, TestIds.lobbyGridCell(n));
      presentNow(app, [TestIds.lobbyGridCell(n)]);
    }
    await reveal(app, TestIds.lobbyFooter);
    for (var n = Lobby.gridCells; n >= 7; n--) {
      await reveal(app, TestIds.lobbyGridCell(n));
      presentNow(app, [TestIds.lobbyGridCell(n)]);
    }
    await reveal(app, TestIds.lobbyInnerList);
    presentNow(app, [TestIds.lobbyInnerList]);
    await through(TestIds.lobbyInnerList, [
      for (var n = 1; n <= Lobby.innerLines; n++) TestIds.lobbyInnerRow(n),
    ], step: const Offset(0, -50));
    await reveal(app, TestIds.lobbyBoard);
    presentNow(app, [TestIds.lobbyBoard, TestIds.lobbyBoardCell(1, 1)]);
    await reveal(app, TestIds.lobbyBoardPosition);
    presentNow(app, [TestIds.lobbyBoardPosition]);
    // the board's far corners, reached by its two scrollers
    final board = tester.stateList<ScrollableState>(
      // the two-axis scroll view's Scrollables are private subclasses: match by type test, not exact type
      find.descendant(of: app.byId(TestIds.lobbyBoard), matching: find.byWidgetPredicate((w) => w is Scrollable)),
    );
    expect(board, hasLength(2));
    for (final (col, row) in [(13, 18), (26, 26), (26, 1), (1, 26)]) {
      for (final s in board) {
        final to = s.position.axis == Axis.vertical ? (row - 1) * 56.0 : (col - 1) * 56.0;
        s.position.jumpTo(to.clamp(0, s.position.maxScrollExtent));
      }
      await tester.pumpAndSettle();
      final id = TestIds.lobbyBoardCell(col, row);
      await reveal(app, id);
      presentNow(app, [id]);
    }
    await reveal(app, TestIds.lobbyFooter);
    presentNow(app, [TestIds.lobbyFooter]);

    // the panels and the sheet
    await reveal(app, TestIds.lobbyRowTile(1, 1));
    await tester.tap(app.byId(TestIds.lobbyRowTile(1, 1)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    presentNow(app, [TestIds.lobbyDetail, TestIds.lobbyDetailBack]);
    await app.tap(TestIds.lobbyDetailBack);
    await reveal(app, TestIds.lobbyRowTile(1, 1));
    await tester.longPress(app.byId(TestIds.lobbyRowTile(1, 1)));
    await tester.pumpAndSettle();
    presentNow(app, [TestIds.lobbySheet, TestIds.lobbySheetTitle, ...TestIds.lobbySheetButtons]);
    await app.tap(TestIds.lobbySheetOpen);
    presentNow(app, [TestIds.lobbyDetail]);
    await app.tap(TestIds.lobbyDetailBack);
    tester
        .state<ScrollableState>(
          find.descendant(of: app.byId(TestIds.lobbyPage), matching: find.byType(Scrollable)).first,
        )
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(app.byId(TestIds.lobbyBanner(5)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    presentNow(app, [TestIds.lobbyPromo, TestIds.lobbyPromoBack]);
    await app.tap(TestIds.lobbyPromoBack);
    await app.tap(TestIds.lobbyBarSaved);
    presentNow(app, [TestIds.lobbySavedScreen]);
    semantics.dispose();
  });

  testWidgets('form: fields, errors, dropdown, date picker, result', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labForm);
    await present(app, [
      TestIds.formScreen,
      TestIds.formName,
      TestIds.formEmail,
      TestIds.formAge,
      TestIds.formPassword,
      TestIds.formPasswordToggle,
      TestIds.formCategory,
      TestIds.formDate,
      TestIds.formNewsletter,
      TestIds.formBudget,
      TestIds.formBudgetValue,
      TestIds.formTerms,
      TestIds.formSubmit,
    ]);
    await app.tap(TestIds.formSubmit);
    await present(app, [
      TestIds.formNameError,
      TestIds.formEmailError,
      TestIds.formAgeError,
      TestIds.formPasswordError,
      TestIds.formCategoryError,
      TestIds.formDateError,
      TestIds.formTermsError,
    ]);
    await app.tap(TestIds.formCategory);
    presentNow(app, [
      for (final key in ['kitchen', 'desk', 'garden', 'home']) TestIds.formCategoryOption(key),
    ]);
    await app.tap(TestIds.formCategoryOption('garden'));
    await app.tap(TestIds.formDate);
    presentNow(app, [TestIds.formDatePicker, TestIds.formDateConfirm, TestIds.formDateCancel]);
    await app.tap(TestIds.formDateCancel);

    await app.type(TestIds.formName, 'Sam Rivera');
    await app.type(TestIds.formEmail, 'sam@example.test');
    await app.type(TestIds.formAge, '34');
    await app.type(TestIds.formPassword, 'garden42x');
    await app.tap(TestIds.formDate);
    await app.tapText('15');
    await app.tap(TestIds.formDateConfirm);
    await app.tap(TestIds.formTerms);
    await app.tap(TestIds.formSubmit);
    await present(app, [TestIds.formResult]);
    semantics.dispose();
  });

  testWidgets('gestures', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labGestures);
    await present(app, [
      TestIds.gesturesScreen,
      TestIds.gesturesStatus,
      TestIds.gesturesOrientation,
      TestIds.gesturesTap,
      TestIds.gesturesTapCount,
      TestIds.gesturesDoubleTap,
      TestIds.gesturesLongPress,
      TestIds.gesturesSwipe,
      TestIds.gesturesDragSource,
      TestIds.gesturesDropTarget,
      TestIds.gesturesPinch,
      TestIds.gesturesZoomValue,
      TestIds.gesturesRotate,
      TestIds.gesturesRotationValue,
      TestIds.gesturesScroll,
      TestIds.gesturesScrollTarget,
    ]);
    semantics.dispose();
  });

  testWidgets('web view and slow screen', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labWebview);
    await present(app, [TestIds.webviewScreen, TestIds.webview, TestIds.webviewStatus]);
    await app.tap(TestIds.topBarBack);
    await tester.tap(app.byId(TestIds.labSlow));
    await tester.pump();
    // past the page transition (its semantics arrive when it ends), well before the 3 s load
    await tester.pump(const Duration(milliseconds: 500));
    presentNow(app, [TestIds.slowScreen, TestIds.slowLoading]);
    await app.waitOut(const Duration(seconds: 3));
    await present(app, [TestIds.slowContent, for (var n = 1; n <= 5; n++) TestIds.slowSlot(n), TestIds.slowReload]);
    semantics.dispose();
  });

  testWidgets('orders: empty, error, loading', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labOrders);
    await present(app, [TestIds.ordersScreen, TestIds.ordersEmpty, TestIds.ordersEmptyAction]);
    await app.tap(TestIds.topBarBack);
    app.state.failFirstLoad = true;
    await app.tap(TestIds.labOrders);
    await present(app, [TestIds.ordersError, TestIds.ordersRetry]);
    await app.tap(TestIds.topBarBack);
    app.state
      ..failFirstLoad = false
      ..slowLoading = true;
    await tester.tap(app.byId(TestIds.labOrders));
    await tester.pump();
    // past the page transition (its semantics arrive when it ends), well before the 3 s load
    await tester.pump(const Duration(milliseconds: 500));
    presentNow(app, [TestIds.ordersLoading]);
    await app.waitOut(const Duration(seconds: 3));
    semantics.dispose();
  });

  testWidgets('deep link to an unknown item', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    app.state.openDeepLink('999');
    await tester.pumpAndSettle();
    await present(app, [TestIds.itemNotFound, TestIds.itemNotFoundAction]);
    semantics.dispose();
  });

  testWidgets('settings and its dialog', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navSettings);
    await present(app, [
      TestIds.settingsScreen,
      TestIds.settingsAccountEmail,
      TestIds.settingsOrders,
      TestIds.settingsSignOut,
      TestIds.settingsTheme,
      TestIds.settingsThemeSystem,
      TestIds.settingsThemeLight,
      TestIds.settingsThemeDark,
      TestIds.settingsNotifications,
      TestIds.settingsNotificationsStatus,
      TestIds.settingsSendNotification,
      TestIds.settingsSlowLoading,
      TestIds.settingsFailLoading,
      TestIds.settingsReset,
      TestIds.settingsVersion,
    ]);
    await app.tap(TestIds.settingsReset);
    presentNow(app, [TestIds.settingsResetConfirm, TestIds.settingsResetCancel]);
    semantics.dispose();
  });

  testWidgets('gift cards has no ids at all', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labGiftCards);
    // the whole tree the platform receives, the top bar included; the tab bar is covered by the screen
    expect(semanticsIds(tester), isEmpty);
    // and none below the fold either
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(semanticsIds(tester), isEmpty);
    expect(find.text('Gift cards'), findsOneWidget);
    semantics.dispose();
  });

  test('every id in test-ids.json was seen, and no other', () {
    final missing = <String>[];
    for (final id in native) {
      final pattern = RegExp('^${id.replaceAll(RegExp(r'\{[a-z]+\}'), '[a-z0-9]+')}\$');
      if (!seen.keys.any(pattern.hasMatch)) missing.add(id);
    }
    expect(missing, isEmpty, reason: 'ids the spec lists that no screen showed');

    final patterns = [for (final id in native) RegExp('^${id.replaceAll(RegExp(r'\{[a-z]+\}'), '[a-z0-9]+')}\$')];
    final strays = seen.keys.where((id) => !patterns.any((p) => p.hasMatch(id))).toList();
    expect(strays, isEmpty, reason: 'ids on screen that the spec does not list');
    expect([for (var i = 1; i <= 40; i++) TestIds.shopItem(i)].where((id) => !seen.containsKey(id)), isEmpty);
  });

  test('each id sits on the control itself, not on a wrapper around it', () {
    const textFields = [
      TestIds.signinEmail,
      TestIds.signinPassword,
      TestIds.shopSearch,
      TestIds.formName,
      TestIds.formEmail,
      TestIds.formAge,
      TestIds.formPassword,
    ];
    final buttons = [
      TestIds.signinPasswordToggle,
      TestIds.signinSubmit,
      TestIds.signinUseTestAccount,
      TestIds.shopSearchClear,
      TestIds.shopRetry,
      TestIds.shopEmptyAction,
      TestIds.itemQtyDecrease,
      TestIds.itemQtyIncrease,
      TestIds.itemAddToCart,
      TestIds.itemNotFoundAction,
      TestIds.cartLineDecrease(1),
      TestIds.cartLineIncrease(1),
      TestIds.cartLineRemove(1),
      TestIds.cartCheckout,
      TestIds.cartEmptyAction,
      TestIds.dialogConfirm,
      TestIds.dialogDismiss,
      TestIds.snackbarAction,
      TestIds.topBarBack,
      TestIds.formPasswordToggle,
      TestIds.formDate,
      TestIds.formDateConfirm,
      TestIds.formDateCancel,
      TestIds.formSubmit,
      TestIds.gesturesScrollTarget,
      TestIds.slowReload,
      TestIds.ordersRetry,
      TestIds.ordersEmptyAction,
      TestIds.settingsOrders,
      TestIds.settingsSignOut,
      TestIds.settingsSendNotification,
      TestIds.settingsReset,
      TestIds.settingsResetConfirm,
      TestIds.settingsResetCancel,
    ];
    final tappable = [
      for (var i = 1; i <= 40; i++) TestIds.shopItem(i),
      TestIds.labForm,
      TestIds.labGestures,
      TestIds.labWebview,
      TestIds.labSlow,
      TestIds.labOrders,
      TestIds.labGiftCards,
      TestIds.navShop,
      TestIds.navCart,
      TestIds.navLab,
      TestIds.navSettings,
      TestIds.formCategory,
      // menu items: Flutter gives them the menu-item role, not the button flag
      for (final key in ['kitchen', 'desk', 'garden', 'home']) TestIds.formCategoryOption(key),
      TestIds.gesturesTap,
    ];
    const switches = [
      TestIds.formNewsletter,
      TestIds.settingsNotifications,
      TestIds.settingsSlowLoading,
      TestIds.settingsFailLoading,
    ];
    const radios = [TestIds.settingsThemeSystem, TestIds.settingsThemeLight, TestIds.settingsThemeDark];

    for (final id in textFields) {
      expect(seen[id]!.flagsCollection.isTextField, isTrue, reason: '$id is the text field');
    }
    for (final id in buttons) {
      expect(seen[id]!.flagsCollection.isButton, isTrue, reason: '$id is the button');
    }
    for (final id in tappable) {
      expect(seen[id]!.hasAction(SemanticsAction.tap), isTrue, reason: '$id takes a tap itself');
    }
    for (final id in switches) {
      expect(seen[id]!.flagsCollection.isToggled, isNot(Tristate.none), reason: '$id is the switch');
      expect(seen[id]!.label, isNotEmpty, reason: '$id says what it switches');
    }
    for (final id in radios) {
      expect(seen[id]!.flagsCollection.isChecked, isNot(CheckedState.none), reason: '$id is the radio button');
      expect(seen[id]!.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    }
    // the Lobby: every touchable takes a tap and a long press on its own node; buttons are buttons; the choices say
    // which one is chosen
    final lobbyTouchables = [
      for (var n = 1; n <= Lobby.banners; n++) TestIds.lobbyBanner(n),
      for (var m = 1; m <= Lobby.topTiles; m++) TestIds.lobbyTopRowTile(m),
      for (var n = 1; n <= Lobby.chips.length; n++) TestIds.lobbyChip(n),
      for (var r = 1; r <= Lobby.rows; r++)
        for (var m = 1; m <= Lobby.tiles; m++) TestIds.lobbyRowTile(r, m),
      for (var n = 1; n <= Lobby.gridCells; n++) TestIds.lobbyGridCell(n),
      for (var n = 1; n <= Lobby.innerLines; n++) TestIds.lobbyInnerRow(n),
      TestIds.lobbyBoardCell(1, 1),
      TestIds.lobbyBoardCell(13, 18),
    ];
    for (final id in lobbyTouchables) {
      expect(seen[id]!.hasAction(SemanticsAction.tap), isTrue, reason: '$id takes a tap itself');
      expect(seen[id]!.hasAction(SemanticsAction.longPress), isTrue, reason: '$id takes a long press itself');
    }
    for (final id in [
      TestIds.lobbyTouchReset,
      TestIds.lobbyDetailBack,
      TestIds.lobbyPromoBack,
      ...TestIds.lobbySheetButtons,
      for (final s in Lobby.delays) TestIds.lobbySavedDelayChoice(s),
    ]) {
      expect(seen[id]!.flagsCollection.isButton, isTrue, reason: '$id is the button');
    }
    for (final id in TestIds.lobbyBarItems) {
      expect(seen[id]!.hasAction(SemanticsAction.tap), isTrue, reason: '$id takes a tap itself');
    }
    for (final id in [TestIds.lobbyPagerShown, TestIds.lobbyPagerAuto]) {
      expect(seen[id]!.flagsCollection.isToggled, isNot(Tristate.none), reason: '$id is the switch');
      expect(seen[id]!.label, isNotEmpty);
    }
    expect(seen[TestIds.lobbySavedDelayChoice(0)]!.flagsCollection.isSelected, Tristate.isTrue);
    expect(seen[TestIds.lobbyChip(1)]!.flagsCollection.isSelected, Tristate.isTrue);
    expect(seen[TestIds.lobbyTopRowTile(2)]!.label, 'Pocket Notebook');
    expect(seen[TestIds.lobbyRowTile(3, 15)]!.label, allOf(contains('Bedside Lamp'), contains('No. 035')));
    expect(seen[TestIds.lobbyBoardCell(13, 18)]!.label, 'M18');
    expect(seen[TestIds.formTerms]!.flagsCollection.isChecked, isNot(CheckedState.none));
    expect(seen[TestIds.formBudget]!.flagsCollection.isSlider, isTrue);
    expect(seen[TestIds.formBudget]!.value, r'$50');
    expect(seen[TestIds.navCart]!.label, contains('Cart'));
    // value ids hold the value alone, so a check reads exactly it
    expect(seen[TestIds.itemQtyValue]!.label, '1');
    expect(seen[TestIds.formBudgetValue]!.label, r'$50');
    expect(
      seen[TestIds.shopItem(1)]!.label,
      allOf(contains('Stoneware Mug'), contains('No. 001'), contains(r'$14.00')),
    );
  });

  test('the shared ids list and the app agree on every name', () {
    expect(spec['spec'], '1.1');
    expect(entries.length, 193);
    final pattern = RegExp(spec['pattern'] as String);
    for (final e in entries) {
      final id = e['id'] as String;
      expect(pattern.hasMatch(id.replaceAll(RegExp(r'\{[a-z]+\}'), 'x')), isTrue, reason: id);
    }
    // the page's ids live in the bundled HTML, as id and data-testid
    final page = File('assets/web/care-guide.html').readAsStringSync();
    for (final id in entries.map((e) => e['id'] as String).where((id) => id.startsWith('web_'))) {
      expect(page, contains('id="$id"'), reason: id);
      expect(page, contains('data-testid="$id"'), reason: id);
    }
    expect(AppState.testEmail, 'tester@mossgrove.test');
  });
}

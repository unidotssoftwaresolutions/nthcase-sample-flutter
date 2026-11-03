// The scenarios in nthcase/scenarios/01–10, played as widget tests: the same steps, the same checks, read from the
// semantics tree Appium reads. No device: everything runs on the host.
import 'dart:math' as math;
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/data/app_state.dart';
import 'package:mossgrove/src/data/form_rules.dart';
import 'package:mossgrove/src/ids.dart';
import 'package:mossgrove/src/platform/device.dart';
import 'package:mossgrove/src/ui/screens/gestures_screen.dart';
import 'package:mossgrove/src/ui/screens/settings_screen.dart';

import 'support/harness.dart';

void main() {
  testWidgets('01 a wrong password is refused, and the test account signs in', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    expect(find.text('Mossgrove'), findsOneWidget);
    expect(find.text('Home and desk goods'), findsOneWidget);

    await app.type(TestIds.signinEmail, 'tester@mossgrove.test');
    await app.type(TestIds.signinPassword, 'letmein1');
    await app.tap(TestIds.signinSubmit);
    expect(app.read(TestIds.signinError), 'Wrong email or password');

    await app.tap(TestIds.signinPasswordToggle);
    expect(app.read(TestIds.signinPassword), 'letmein1');

    await app.type(TestIds.signinPassword, 'Mossgrove123');
    await app.tap(TestIds.signinSubmit);
    expect(find.text('Stoneware Mug'), findsOneWidget);
    expect(app.read(TestIds.shopCount), '40 drawers · No. 001–040');
    semantics.dispose();
  });

  testWidgets('01 empty fields, and the test-account button', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.tap(TestIds.signinSubmit);
    expect(app.read(TestIds.signinError), 'Enter your email and password');
    await app.tap(TestIds.signinUseTestAccount);
    expect(app.read(TestIds.signinEmail), AppState.testEmail);
    // the email is matched ignoring case and surrounding spaces; the password is exact
    await app.type(TestIds.signinEmail, '  Tester@Mossgrove.TEST ');
    await app.tap(TestIds.signinSubmit);
    expect(app.state.signedInEmail, AppState.testEmail);
    semantics.dispose();
  });

  testWidgets('02 search narrows the list, scrolls to the end, and refreshes', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();

    await app.type(TestIds.shopSearch, 'lamp');
    expect(app.read(TestIds.shopCount), '4 of 40 drawers');
    expect(find.text('Floor Lamp'), findsOneWidget);
    await app.tap(TestIds.shopSearchClear);
    expect(app.read(TestIds.shopCount), '40 drawers · No. 001–040');

    await app.type(TestIds.shopSearch, 'velvet');
    expect(find.text('No drawers match "velvet"'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);
    await app.tap(TestIds.shopEmptyAction);

    final list = find.descendant(of: app.byId(TestIds.shopList), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Fruit Bowl'), 400, scrollable: list);
    expect(find.text('No. 040'), findsOneWidget);
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();

    // pull to refresh: 0.8 s, then the snackbar
    await tester.fling(list, const Offset(0, 400), 1000);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(app.read(TestIds.snackbarText), 'Catalogue is up to date');
    await app.waitOut();

    await app.type(TestIds.shopSearch, '7');
    expect(app.read(TestIds.shopCount), '1 of 40 drawers');
    expect(find.text('Wall Clock'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('03 fill the cart, cancel the modal, and place the order', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();

    await app.tap(TestIds.shopItem(1));
    expect(app.read(TestIds.itemNumber), 'No. 001');
    expect(app.read(TestIds.itemPrice), r'$14.00');
    await app.tap(TestIds.itemQtyIncrease);
    expect(app.read(TestIds.itemQtyValue), '2');
    await app.tap(TestIds.itemAddToCart);
    expect(app.read(TestIds.snackbarText), 'Added to cart');
    await app.tap(TestIds.snackbarAction);
    expect(app.read(TestIds.cartTotal), r'$28.00');
    expect(app.read(TestIds.navCart), contains('Cart, 2 items'));

    await app.tap(TestIds.navShop);
    await app.tap(TestIds.shopItem(5));
    await app.tap(TestIds.itemAddToCart);
    // the item page covers the tab bar (SPEC.md §4): Back, then the Cart tab
    await app.tap(TestIds.topBarBack);
    await app.tap(TestIds.navCart);
    expect(app.read(TestIds.cartTotal), r'$70.00');

    await app.tap(TestIds.cartLineRemove(1));
    expect(find.text('Stoneware Mug'), findsNothing);
    expect(app.read(TestIds.cartTotal), r'$42.00');
    final orderTotal = app.read(TestIds.cartTotal);

    // the "Added to cart" snackbar has gone by now on a phone; here, let its 10 s run out
    await app.waitOut();
    await app.tap(TestIds.cartCheckout);
    expect(app.read(TestIds.dialogTitle), 'Place this order?');
    expect(app.read(TestIds.dialogText), r'1 item · $42.00. This is a sample shop: nothing is charged or shipped.');
    await app.tap(TestIds.dialogDismiss);
    expect(app.appiumNodes().containsKey(TestIds.dialog), isFalse);
    expect(find.text('Brass Desk Lamp'), findsOneWidget);

    await app.tap(TestIds.cartCheckout);
    await app.tap(TestIds.dialogConfirm);
    expect(app.read(TestIds.snackbarText), 'Order 1 placed');
    expect(find.text('Your cart is empty'), findsOneWidget);
    await app.tap(TestIds.snackbarAction);
    expect(app.read(TestIds.ordersRow(1)), allOf(contains('Order 1'), contains(orderTotal)));
    semantics.dispose();
  });

  testWidgets('03 the stepper stays within 1–9, and adding caps at 9', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.shopItem(2));
    expect(app.appiumNodes()[TestIds.itemQtyDecrease]!.flagsCollection.isEnabled, Tristate.isFalse);
    for (var i = 0; i < 10; i++) {
      await tester.tap(app.byId(TestIds.itemQtyIncrease));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(app.read(TestIds.itemQtyValue), '9');
    expect(find.text(r'Add to cart · $85.50'), findsOneWidget);
    await app.tap(TestIds.itemAddToCart);
    await app.tap(TestIds.itemAddToCart);
    expect(app.state.cart.quantityOf(2), 9);
    semantics.dispose();
  });

  testWidgets('04 the form shows every error, then joins', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labForm);

    await app.tap(TestIds.formSubmit);
    for (final (id, text) in [
      (TestIds.formNameError, FormRules.name),
      (TestIds.formEmailError, FormRules.email),
      (TestIds.formAgeError, FormRules.age),
      (TestIds.formPasswordError, FormRules.password),
      (TestIds.formCategoryError, FormRules.category),
      (TestIds.formDateError, FormRules.date),
      (TestIds.formTermsError, FormRules.terms),
    ]) {
      expect(await app.see(id), text);
    }

    await app.type(TestIds.formName, 'Sam Rivera');
    await app.type(TestIds.formEmail, 'sam@example');
    expect(find.text(FormRules.email), findsOneWidget);
    await app.type(TestIds.formEmail, 'sam@example.test');
    expect(find.text(FormRules.email), findsNothing);
    await app.type(TestIds.formAge, '34x5');
    expect(app.read(TestIds.formAge), '345');
    await app.type(TestIds.formAge, '34');
    await app.type(TestIds.formPassword, 'garden42x');
    await app.tap(TestIds.formPasswordToggle);
    expect(app.read(TestIds.formPassword), 'garden42x');

    await app.tap(TestIds.formCategory);
    await app.tap(TestIds.formCategoryOption('garden'));
    expect(find.text('Garden'), findsOneWidget);

    await app.tap(TestIds.formDate);
    expect(find.text('November 2026'), findsOneWidget);
    await app.tapText('15');
    await app.tap(TestIds.formDateConfirm);
    expect(find.text('15 Nov 2026'), findsOneWidget);

    await app.tap(TestIds.formNewsletter);
    expect(app.appiumNodes()[TestIds.formNewsletter]!.flagsCollection.isToggled, Tristate.isTrue);

    // drag the slider to about 60 percent
    final slider = tester.getRect(app.byId(TestIds.formBudget));
    await tester.tapAt(Offset(slider.left + slider.width * 0.6, slider.center.dy));
    await tester.pumpAndSettle();
    expect(app.read(TestIds.formBudgetValue), r'$120');

    await app.tap(TestIds.formTerms);
    await app.tap(TestIds.formSubmit);
    expect(
      await app.see(TestIds.formResult),
      "Welcome, Sam Rivera. We'll write to sam@example.test about the Garden aisle and deliver on 15 Nov 2026.",
    );
    expect(app.read(TestIds.snackbarText), 'Welcome to the club');
    expect(app.appiumNodes().containsKey(TestIds.formNameError), isFalse);
    semantics.dispose();
  });

  testWidgets('05 every gesture says what it was', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labGestures);
    String status() => app.read(TestIds.gesturesStatus);
    expect(status(), GestureWords.ready);
    expect(app.read(TestIds.gesturesOrientation), 'Portrait');

    await app.tap(TestIds.gesturesTap);
    expect(status(), GestureWords.tapped);
    expect(app.read(TestIds.gesturesTapCount), 'Taps: 1');

    final doubleTap = tester.getCenter(app.byId(TestIds.gesturesDoubleTap));
    await tester.tapAt(doubleTap);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(doubleTap);
    await tester.pumpAndSettle();
    expect(status(), GestureWords.doubleTapped);

    await tester.longPress(app.byId(TestIds.gesturesLongPress));
    await tester.pumpAndSettle();
    expect(status(), GestureWords.longPressed);

    for (final (direction, offset) in [
      ('left', const Offset(-200, 0)),
      ('right', const Offset(200, 0)),
      ('up', const Offset(0, -100)),
      ('down', const Offset(0, 100)),
    ]) {
      await tester.drag(app.byId(TestIds.gesturesSwipe), offset);
      await tester.pumpAndSettle();
      expect(status(), GestureWords.swiped(direction));
    }
    // a swipe shorter than 48 dp is not a swipe
    await tester.drag(app.byId(TestIds.gesturesSwipe), const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(status(), GestureWords.swiped('down'));

    final source = tester.getCenter(app.byId(TestIds.gesturesDragSource));
    final target = tester.getCenter(app.byId(TestIds.gesturesDropTarget));
    await tester.timedDragFrom(source, target - source, const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(status(), GestureWords.dropped);
    await tester.timedDragFrom(source, const Offset(0, 150), const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(status(), GestureWords.dropMissed);

    await tester.ensureVisible(app.byId(TestIds.gesturesPinch));
    await tester.pumpAndSettle();
    final pinch = tester.getCenter(app.byId(TestIds.gesturesPinch));
    final a = await tester.startGesture(pinch - const Offset(20, 0), pointer: 1);
    final b = await tester.startGesture(pinch + const Offset(20, 0), pointer: 2);
    for (var step = 1; step <= 10; step++) {
      await a.moveTo(pinch - Offset(20.0 + 3 * step, 0));
      await b.moveTo(pinch + Offset(20.0 + 3 * step, 0));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(status(), GestureWords.pinchedOut);
    expect(app.read(TestIds.gesturesZoomValue), 'Zoom 2.5×');

    // two fingers on an 50 px radius, turned a quarter clockwise (screen y points down)
    final rotate = tester.getCenter(app.byId(TestIds.gesturesRotate));
    final c = await tester.startGesture(rotate - const Offset(50, 0), pointer: 3);
    final d = await tester.startGesture(rotate + const Offset(50, 0), pointer: 4);
    for (var step = 1; step <= 10; step++) {
      final angle = 9.0 * step * math.pi / 180;
      final o = Offset(50 * math.cos(angle), 50 * math.sin(angle));
      await c.moveTo(rotate - o);
      await d.moveTo(rotate + o);
    }
    await c.up();
    await d.up();
    await tester.pumpAndSettle();
    expect(status(), GestureWords.rotatedClockwise);
    expect(app.read(TestIds.gesturesRotationValue), 'Rotation 90°');

    await app.tap(TestIds.gesturesScrollTarget);
    expect(status(), GestureWords.scrolledTo);
    semantics.dispose();
  });

  testWidgets('05 the gestures are accessibility actions too', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labGestures);
    void perform(String id, String label) {
      final node = tester.getSemantics(app.byId(id));
      final action = CustomSemanticsAction(label: label);
      node.owner!.performAction(node.id, SemanticsAction.customAction, CustomSemanticsAction.getIdentifier(action));
    }

    perform(TestIds.gesturesDoubleTap, 'Double tap');
    await tester.pump();
    expect(app.read(TestIds.gesturesStatus), GestureWords.doubleTapped);
    perform(TestIds.gesturesSwipe, 'Swipe up');
    await tester.pump();
    expect(app.read(TestIds.gesturesStatus), GestureWords.swiped('up'));
    perform(TestIds.gesturesDragSource, 'Drop on the drawer');
    await tester.pump();
    expect(app.read(TestIds.gesturesStatus), GestureWords.dropped);
    final longPress = tester.getSemantics(app.byId(TestIds.gesturesLongPress));
    longPress.owner!.performAction(longPress.id, SemanticsAction.longPress);
    await tester.pump();
    expect(app.read(TestIds.gesturesStatus), GestureWords.longPressed);
    semantics.dispose();
  });

  testWidgets('06 the device: orientation, back, shake, and a cart that survives', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.shopItem(1));
    await app.tap(TestIds.itemAddToCart);
    await app.waitOut();
    await app.tap(TestIds.topBarBack);
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labGestures);
    expect(app.read(TestIds.gesturesOrientation), 'Portrait');

    tester.view.physicalSize = const Size(780, 360) * 2;
    await tester.pumpAndSettle();
    expect(app.read(TestIds.gesturesOrientation), 'Landscape');
    tester.view.physicalSize = phone * 2;
    await tester.pumpAndSettle();
    expect(app.read(TestIds.gesturesOrientation), 'Portrait');

    // Android: three jolts over 2.5 g within a second, from the accelerometer channel
    for (var i = 0; i < 3; i++) {
      app.device.motionController.add(Reading(0, 30, 0, 1000 + i * 200));
    }
    await tester.pumpAndSettle();
    expect(app.read(TestIds.gesturesStatus), GestureWords.shaken);
    // iOS: UIKit's motionEnded, sent as a finished shake
    await app.tap(TestIds.gesturesTap);
    app.device.motionController.add(const Shaken());
    await tester.pumpAndSettle();
    expect(app.read(TestIds.gesturesStatus), GestureWords.shaken);

    // system Back, as the Android button and the iOS edge swipe do
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Join the club'), findsOneWidget);
    await app.tap(TestIds.navCart);
    expect(find.text('Stoneware Mug'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('07 the care guide reports its page loaded', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labWebview);
    expect(app.read(TestIds.webviewStatus), 'Care guide loaded');
    expect(app.appiumNodes().containsKey(TestIds.webview), isTrue);
    semantics.dispose();
  });

  testWidgets('08 a slow screen, an error with retry, and the empty states', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);

    await tester.tap(app.byId(TestIds.labSlow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(app.read(TestIds.slowLoading), contains('Finding delivery slots…'));
    await tester.pump(const Duration(milliseconds: 2400));
    expect(app.appiumNodes().containsKey(TestIds.slowContent), isFalse, reason: 'still waiting at 2.9 s');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Monday · 8:00–10:00'), findsOneWidget);
    expect(find.text('Saturday · 10:00–12:00'), findsOneWidget);
    await tester.tap(app.byId(TestIds.slowReload));
    await tester.pump();
    expect(app.appiumNodes().containsKey(TestIds.slowLoading), isTrue);
    await app.waitOut(const Duration(seconds: 3));

    await app.tap(TestIds.topBarBack);
    await app.tap(TestIds.labOrders);
    expect(find.text('No orders yet'), findsOneWidget);
    await app.tap(TestIds.topBarBack);

    await app.tap(TestIds.navSettings);
    await app.tap(TestIds.settingsFailLoading);
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labOrders);
    expect(find.text("Orders didn't load"), findsOneWidget);
    await app.tap(TestIds.ordersRetry);
    expect(find.text('No orders yet'), findsOneWidget);
    await app.tap(TestIds.topBarBack);

    await app.tap(TestIds.navSettings);
    await app.tap(TestIds.settingsFailLoading);
    await app.tap(TestIds.settingsSlowLoading);
    await tester.tap(app.byId(TestIds.navShop));
    await tester.pump();
    expect(app.read(TestIds.shopLoading), contains('Opening the drawers…'));
    await app.waitOut(const Duration(seconds: 3));
    expect(find.text('Stoneware Mug'), findsOneWidget);

    await app.tap(TestIds.navCart);
    expect(find.text('Your cart is empty'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('08 the shop fails its first load, then Try again succeeds', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    app.state.failFirstLoad = true;
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.navShop);
    expect(find.text("The catalogue didn't load"), findsOneWidget);
    await app.tap(TestIds.shopRetry);
    expect(app.read(TestIds.shopCount), '40 drawers · No. 001–040');
    semantics.dispose();
  });

  testWidgets('09 settings: theme, the notification prompt, the dialog, sign out', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navSettings);
    expect(app.read(TestIds.settingsAccountEmail), 'tester@mossgrove.test');
    expect(app.read(TestIds.settingsNotificationsStatus), notificationsNotAllowed);
    expect(app.appiumNodes()[TestIds.settingsSendNotification]!.flagsCollection.isEnabled, Tristate.isFalse);

    await app.tap(TestIds.settingsThemeDark);
    expect(app.appiumNodes()[TestIds.settingsThemeDark]!.flagsCollection.isChecked, CheckedState.isTrue);
    expect(Theme.of(tester.element(app.byId(TestIds.settingsScreen))).brightness, Brightness.dark);
    await app.tap(TestIds.settingsThemeSystem);
    expect(app.appiumNodes()[TestIds.settingsThemeSystem]!.flagsCollection.isChecked, CheckedState.isTrue);

    await app.tap(TestIds.settingsNotifications);
    expect(app.device.prompts, 1, reason: 'the system asks once');
    expect(app.read(TestIds.settingsNotificationsStatus), notificationsOn);
    await app.tap(TestIds.settingsSendNotification);
    expect(app.read(TestIds.snackbarText), notificationSent);
    expect(app.device.posted.single.$1, 'Your order is packed');
    await app.waitOut();

    await app.tap(TestIds.settingsReset);
    expect(find.text('Empty the cart and orders?'), findsOneWidget);
    expect(find.text("You stay signed in. This can't be undone."), findsOneWidget);
    await app.tap(TestIds.settingsResetCancel);
    expect(find.text('Empty the cart and orders?'), findsNothing);

    await app.tap(TestIds.settingsSignOut);
    expect(find.text('Test account'), findsOneWidget);
    expect(app.state.signedIn, isFalse);
    semantics.dispose();
  });

  testWidgets('09 a refused prompt leaves updates off; with updates on, an order posts a notification', (tester) async {
    final semantics = tester.ensureSemantics();
    final device = FakeDevice(grantOnRequest: false);
    final app = await TestApp.start(tester, device: device);
    await app.signIn();
    await app.tap(TestIds.navSettings);
    await app.tap(TestIds.settingsNotifications);
    expect(app.read(TestIds.settingsNotificationsStatus), notificationsNotAllowed);
    expect(app.state.orderUpdates, isFalse);

    device.grantOnRequest = true;
    await app.tap(TestIds.settingsNotifications);
    expect(app.state.orderUpdates, isTrue);
    await app.tap(TestIds.settingsReset);
    await app.tap(TestIds.settingsResetConfirm);
    expect(app.read(TestIds.snackbarText), 'Cart and orders emptied');
    await app.waitOut();

    await app.tap(TestIds.navShop);
    await app.tap(TestIds.shopItem(3));
    await app.tap(TestIds.itemAddToCart);
    await app.tap(TestIds.snackbarAction);
    await app.tap(TestIds.cartCheckout);
    await app.tap(TestIds.dialogConfirm);
    expect(device.posted.last.$1, 'Order 1 placed');
    semantics.dispose();
  });

  testWidgets('10 gift cards: found by text and position alone', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labGiftCards);
    expect(find.text('Check a balance'), findsOneWidget);

    final code = find.descendant(of: find.byType(TextField), matching: find.byType(EditableText));
    await tester.enterText(code, 'moss-0025');
    await tester.pumpAndSettle();
    expect(find.text('MOSS-0025'), findsOneWidget, reason: 'the field upper-cases what is typed');
    await app.tapText('Check balance');
    expect(find.text(r'Balance: $25.00'), findsOneWidget);
    await tester.enterText(code, 'MOSS-9999');
    await app.tapText('Check balance');
    expect(find.text("We don't recognise that code"), findsOneWidget);

    await app.tapText(r'$50');
    final choose = find.text('Choose');
    expect(choose, findsNWidgets(2));
    final left = tester.getCenter(choose.at(0)).dx < tester.getCenter(choose.at(1)).dx ? 0 : 1;
    await tester.tap(choose.at(1 - left));
    await tester.pumpAndSettle();
    expect(find.text(r'A $50 card with the Stone design'), findsOneWidget);
    await tester.tap(choose.at(left));
    await tester.pumpAndSettle();
    expect(find.text(r'A $50 card with the Fern design'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a tab opens at its first screen, from any depth and from a snackbar', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.shopItem(1));
    await app.tap(TestIds.itemAddToCart);
    // View cart on an item page opens the Cart tab's first screen, not a cart above the item
    await app.tap(TestIds.snackbarAction);
    expect(app.state.stack, isEmpty);
    expect(app.appiumNodes().containsKey(TestIds.cartScreen), isTrue);

    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labGestures);
    await app.tap(TestIds.gesturesTap);
    expect(app.state.stack, hasLength(1));
    // a deeper screen covers the tab bar, so a tab is reached by Back, then the bar
    expect(app.appiumNodes().containsKey(TestIds.navCart), isFalse);
    await app.tap(TestIds.topBarBack);
    await app.tap(TestIds.navCart);
    await app.tap(TestIds.navLab);
    expect(app.appiumNodes().containsKey(TestIds.labScreen), isTrue);
    expect(app.appiumNodes().containsKey(TestIds.gesturesScreen), isFalse);

    // Order history from Settings opens Orders over Settings; the Settings tab then opens at Settings
    await app.tap(TestIds.navSettings);
    await app.tap(TestIds.settingsOrders);
    expect(app.appiumNodes().containsKey(TestIds.ordersScreen), isTrue);
    await app.tap(TestIds.ordersEmptyAction);
    expect(app.appiumNodes().containsKey(TestIds.shopScreen), isTrue);
    await app.tap(TestIds.navSettings);
    expect(app.appiumNodes().containsKey(TestIds.settingsScreen), isTrue);
    expect(app.appiumNodes().containsKey(TestIds.ordersScreen), isFalse);

    // the shop opens fresh: no search kept from the last visit
    await app.tap(TestIds.navShop);
    await app.type(TestIds.shopSearch, 'lamp');
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.navShop);
    expect(app.read(TestIds.shopCount), '40 drawers · No. 001–040');
    semantics.dispose();
  });

  testWidgets('sign out clears the back stack and the cart', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.shopItem(3));
    await app.tap(TestIds.itemAddToCart);
    await app.waitOut();
    await app.tap(TestIds.topBarBack);
    await app.tap(TestIds.navSettings);
    await app.tap(TestIds.settingsSignOut);
    expect(app.appiumNodes().containsKey(TestIds.signinScreen), isTrue);
    expect(await tester.binding.handlePopRoute(), isFalse, reason: 'nothing below the sign-in screen');
    await app.signIn();
    await app.tap(TestIds.navCart);
    expect(find.text('Your cart is empty'), findsOneWidget);
    semantics.dispose();
  });

  // The first CI run's id walks placed an order, then looked for "No orders yet": the app was right to list the order
  // (SPEC.md §3, Orders). The empty state comes from a fresh start, or from Settings › Empty, as the walks now do.
  testWidgets('a placed order stays in Orders until Settings › Empty', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labOrders);
    expect(app.appiumNodes().keys, containsAll([TestIds.ordersEmpty, TestIds.ordersEmptyAction]));
    await app.tap(TestIds.topBarBack);

    await app.tap(TestIds.navShop);
    await app.tap(TestIds.shopItem(1));
    await app.tap(TestIds.itemAddToCart);
    await app.tap(TestIds.snackbarAction);
    await app.waitOut();
    await app.tap(TestIds.cartCheckout);
    await app.tap(TestIds.dialogConfirm);
    await app.waitOut();
    await app.tap(TestIds.navLab);
    await app.tap(TestIds.labOrders);
    expect(app.appiumNodes().keys, containsAll([TestIds.ordersList, TestIds.ordersRow(1)]));
    expect(app.appiumNodes().containsKey(TestIds.ordersEmpty), isFalse);
    await app.tap(TestIds.topBarBack);

    await app.tap(TestIds.navSettings);
    await app.tap(TestIds.settingsReset);
    await app.tap(TestIds.settingsResetConfirm);
    await app.waitOut();
    await app.tap(TestIds.settingsOrders);
    expect(app.appiumNodes().keys, containsAll([TestIds.ordersEmpty, TestIds.ordersEmptyAction]));
    semantics.dispose();
  });
}

// Golden screenshots: every screen, light and dark, at 360 × 780 logical pixels (720 × 1560 at 2×), drawn on the host
// with a real font (Roboto from the Flutter SDK). The goldens ARE the README's screenshots: they live in
// docs/screenshots/{light,dark}/ under the Android round's names, so a picture in the README can never drift from
// the test. Update them with:
//
//   flutter test --update-goldens --tags golden
//
// Text is drawn by the host's font engine, which differs between macOS and Linux, so the comparison runs on macOS
// only (locally, and in CI's macOS job), with a small tolerance for anti-aliasing.
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/ids.dart';
import 'package:mossgrove/src/ui/app.dart';

import 'support/harness.dart';

/// Passes when at most this share of the pixels differ (0.5 %): enough for anti-aliasing between macOS versions, far
/// too little for a changed text, colour or layout.
const tolerance = 0.005;

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

void main() {
  goldenFileComparator = _TolerantComparator(Uri.file('${Directory.current.path}/test/goldens_test.dart'));

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light ? 'light' : 'dark';
    testWidgets('every screen, $theme', (tester) async {
      final app = await TestApp.start(tester, brightness: brightness);

      Future<void> shot(String name) async {
        // no blinking cursor in a picture
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await expectLater(find.byType(MossgroveApp), matchesGoldenFile('../docs/screenshots/$theme/$name.png'));
      }

      await shot('01-sign-in');
      await app.tap(TestIds.signinSubmit);
      await shot('02-sign-in-error');
      await app.signIn();
      await shot('03-shop');
      await app.type(TestIds.shopSearch, 'lamp');
      await shot('04-shop-search');
      await app.tap(TestIds.shopSearchClear);
      await app.type(TestIds.shopSearch, 'velvet');
      await shot('05-shop-no-match');
      await app.tap(TestIds.shopEmptyAction);

      await app.tap(TestIds.shopItem(5));
      await app.tap(TestIds.itemQtyIncrease);
      await shot('06-item');
      await app.tap(TestIds.itemAddToCart);
      await shot('07-item-snackbar');
      await app.waitOut();
      await app.tap(TestIds.topBarBack);
      await app.tap(TestIds.shopItem(1));
      await app.tap(TestIds.itemAddToCart);
      await app.tap(TestIds.snackbarAction);
      await shot('08-cart');
      await app.tap(TestIds.cartCheckout);
      await shot('09-cart-dialog');
      await app.tap(TestIds.dialogConfirm);
      await shot('10-cart-empty');
      await app.waitOut();

      await app.tap(TestIds.navLab);
      await shot('11-lab');
      await app.tap(TestIds.labForm);
      await app.tap(TestIds.formSubmit);
      await tester.ensureVisible(app.byId(TestIds.formName));
      await shot('12-form-errors');
      await app.type(TestIds.formName, 'Sam Rivera');
      await app.type(TestIds.formEmail, 'sam@example.test');
      await app.type(TestIds.formAge, '34');
      await app.type(TestIds.formPassword, 'garden42x');
      await app.tap(TestIds.formCategory);
      await app.tap(TestIds.formCategoryOption('garden'));
      await app.tap(TestIds.formDate);
      await app.tapText('15');
      await app.tap(TestIds.formDateConfirm);
      await app.tap(TestIds.formNewsletter);
      await app.tap(TestIds.formTerms);
      await app.tap(TestIds.formSubmit);
      await tester.ensureVisible(app.byId(TestIds.formResult));
      await shot('13-form-done');
      await app.waitOut();
      await app.tap(TestIds.topBarBack);

      await app.tap(TestIds.labGestures);
      await app.tap(TestIds.gesturesTap);
      await shot('14-gestures');
      await app.tap(TestIds.topBarBack);

      await app.tap(TestIds.labWebview);
      await shot('15-webview');
      await app.tap(TestIds.topBarBack);

      await tester.tap(app.byId(TestIds.labSlow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await expectLater(find.byType(MossgroveApp), matchesGoldenFile('../docs/screenshots/$theme/16-slow-loading.png'));
      await app.waitOut(const Duration(seconds: 3));
      await shot('17-slow-done');
      await app.tap(TestIds.topBarBack);

      await app.tap(TestIds.labOrders);
      await shot('18-orders');
      await app.tap(TestIds.topBarBack);
      app.state.resetData();
      await app.tap(TestIds.labOrders);
      await shot('19-orders-empty');
      await app.tap(TestIds.topBarBack);
      app.state.failFirstLoad = true;
      await app.tap(TestIds.labOrders);
      await shot('20-orders-error');
      app.state.failFirstLoad = false;
      await app.tap(TestIds.topBarBack);

      await app.tap(TestIds.labGiftCards);
      // no ids here: the left-hand "Choose" is Fern
      final choose = find.text('Choose');
      final left = tester.getCenter(choose.at(0)).dx < tester.getCenter(choose.at(1)).dx ? 0 : 1;
      await tester.tap(choose.at(left));
      await shot('21-gift-cards');
      // the gift-cards screen has no ids, so leave it with the system Back
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await app.tap(TestIds.navSettings);
      await shot('22-settings');
      await app.tap(TestIds.settingsReset);
      await shot('23-settings-dialog');
      await app.tap(TestIds.settingsResetCancel);

      app.state.openDeepLink('999');
      await shot('24-deep-link-unknown');
    }, skip: !Platform.isMacOS);
  }
}

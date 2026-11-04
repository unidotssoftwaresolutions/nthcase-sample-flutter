// The deep link through Flutter's own deep linking: the engine sends the URI on the `flutter/navigation` channel (a
// cold start's initial route, or `pushRouteInformation` while running), and the app's Router reads it.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/ids.dart';

import 'support/harness.dart';

Future<void> openLink(WidgetTester tester, String link) async {
  final message = const JSONMethodCodec().encodeMethodCall(MethodCall('pushRouteInformation', {'location': link}));
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/navigation', message, (_) {});
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('from a cold start, sign-in comes first, then the item; Back lands on the Shop', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.binding.platformDispatcher.defaultRouteNameTestValue = 'nthcase-sample://item/7';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    final app = await TestApp.start(tester);
    expect(app.appiumNodes().containsKey(TestIds.signinScreen), isTrue);
    await app.signIn();
    expect(app.read(TestIds.itemName), 'Wall Clock');
    expect(app.read(TestIds.itemNumber), 'No. 007');
    // the item covers the Shop: Appium sees no shop_screen until Back (the first CI run's iOS test looked for it here)
    expect(app.appiumNodes().containsKey(TestIds.shopScreen), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Stoneware Mug'), findsOneWidget);
    expect(app.appiumNodes().containsKey(TestIds.shopScreen), isTrue);
    semantics.dispose();
  });

  testWidgets('while running, from Settings, the item opens over the Shop; Back lands on the Shop', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navSettings);
    expect(app.appiumNodes().containsKey(TestIds.settingsScreen), isTrue);
    await openLink(tester, 'nthcase-sample://item/7');
    expect(app.read(TestIds.itemName), 'Wall Clock');
    expect(app.read(TestIds.itemNumber), 'No. 007');
    // still signed in, and the item covers the Shop tab (iOS's test11DeepLinkWhileRunning checks the same on a device)
    expect(app.appiumNodes().containsKey(TestIds.signinScreen), isFalse);
    expect(app.appiumNodes().containsKey(TestIds.shopScreen), isFalse);
    await app.tap(TestIds.topBarBack);
    expect(app.appiumNodes().containsKey(TestIds.shopScreen), isTrue);
    expect(app.appiumNodes().containsKey(TestIds.settingsScreen), isFalse);
    semantics.dispose();
  });

  testWidgets('while running, an unknown id shows the not-found state', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    await openLink(tester, 'nthcase-sample://item/999');
    expect(app.read(TestIds.topBarTitle), 'Not found');
    expect(find.text('No drawer has the number "999"'), findsOneWidget);
    expect(find.text('Items are numbered 1 to 40.'), findsOneWidget);
    await app.tap(TestIds.itemNotFoundAction);
    expect(app.appiumNodes().containsKey(TestIds.shopScreen), isTrue);

    await openLink(tester, 'nthcase-sample://item/abc');
    expect(find.text('No drawer has the number "abc"'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('any other host or path is ignored', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await app.signIn();
    await app.tap(TestIds.navLab);
    for (final link in [
      'nthcase-sample://cart/7',
      'nthcase-sample://item/7/8',
      'https://example.test/item/7',
      '/item/7',
    ]) {
      await openLink(tester, link);
      expect(app.appiumNodes().containsKey(TestIds.labScreen), isTrue, reason: link);
      expect(app.state.stack, isEmpty, reason: link);
    }
    semantics.dispose();
  });
}

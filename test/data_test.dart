// Unit tests: the data, the rules and the conversions every screen relies on, checked against the shared sources
// (SPEC.md, art/, pubspec.yaml) rather than against copies of them.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/data/app_state.dart';
import 'package:mossgrove/src/data/cart.dart';
import 'package:mossgrove/src/data/catalog.dart';
import 'package:mossgrove/src/data/deep_link.dart';
import 'package:mossgrove/src/data/form_rules.dart';
import 'package:mossgrove/src/data/shake_detector.dart';
import 'package:mossgrove/src/ui/art_data.g.dart';
import 'package:mossgrove/src/ui/screens/gestures_screen.dart';
import 'package:mossgrove/src/ui/screens/settings_screen.dart';
import 'package:mossgrove/src/ui/svg_path.dart';

void main() {
  final spec = File('SPEC.md').readAsStringSync();

  group('catalogue', () {
    test('is SPEC.md §3, item for item', () {
      final rows = RegExp(
        r'^\| (\d{3}) \| ([^|]+) \| (\w+) \(`(\w+)`\) \| (\w+) \| \$(\d+)\.(\d\d) \| ([^|]+) \|$',
        multiLine: true,
      ).allMatches(spec).toList();
      expect(rows, hasLength(40));
      for (final (index, row) in rows.indexed) {
        final item = Catalog.items[index];
        expect(item.number, 'No. ${row.group(1)}');
        expect(item.name, row.group(2)!.trim());
        expect(item.category.label, row.group(3));
        expect(item.category.key, row.group(4));
        expect(item.glyph.name, row.group(5));
        expect(item.priceCents, int.parse(row.group(6)!) * 100 + int.parse(row.group(7)!));
        expect(item.description, row.group(8)!.trim());
      }
    });

    test('prices and numbers are written the same way everywhere', () {
      expect(formatPrice(1400), r'$14.00');
      expect(formatPrice(950), r'$9.50');
      expect(formatPrice(8900), r'$89.00');
      expect(itemNumber(7), 'No. 007');
      expect(itemNumber(40), 'No. 040');
    });

    test('search finds a name anywhere, ignoring case, or a number exactly', () {
      List<int> ids(String q) => Catalog.search(q).map((i) => i.id).toList();
      expect(ids('lamp'), [5, 15, 25, 35]);
      expect(ids('LAMP'), [5, 15, 25, 35]);
      expect(ids('7'), [7]);
      expect(ids('007'), [7]);
      expect(ids('No. 007'), [7]);
      expect(ids('  bowl '), [10, 20, 30, 40]);
      expect(ids(''), hasLength(40));
      expect(ids('   '), hasLength(40));
      expect(ids('velvet'), isEmpty);
      expect(ids('41'), isEmpty);
    });
  });

  group('cart and orders', () {
    test('one line per item, in the order first added, 1–9 each', () {
      final cart = Cart()
        ..add(5, 1)
        ..add(1, 2)
        ..add(5, 3);
      expect(cart.lines.map((l) => (l.itemId, l.quantity)), [(5, 4), (1, 2)]);
      cart.add(1, 20);
      expect(cart.quantityOf(1), 9);
      cart.setQuantity(1, 0);
      expect(cart.quantityOf(1), 1);
      expect(cart.totalCents, 4 * 4200 + 1400);
      expect(cart.itemCount, 5);
      cart.remove(5);
      expect(cart.lines.single.itemId, 1);
      expect(() => cart.add(41, 1), throwsArgumentError);
    });

    test('placing an order empties the cart, numbers from 1, newest first', () {
      final state = AppState()..signIn('tester@mossgrove.test');
      state.changeCart((c) => c.add(1, 2));
      final first = state.placeOrder();
      state.changeCart((c) => c.add(5, 1));
      final second = state.placeOrder();
      expect(first.number, 1);
      expect(second.number, 2);
      expect(state.orders.map((o) => o.number), [2, 1]);
      expect(first.totalCents, 2800);
      expect(first.itemCount, 2);
      expect(state.cart.isEmpty, isTrue);
      state.resetData();
      expect(state.orders, isEmpty);
      expect(state.signedIn, isTrue, reason: 'Empty the cart and orders keeps you signed in');
    });

    test('a cold start is signed out with nothing in it, and sign out clears it all', () {
      final state = AppState();
      expect(state.signedIn, isFalse);
      expect(state.cart.isEmpty, isTrue);
      expect(state.orders, isEmpty);
      expect(
        (state.slowLoading, state.failFirstLoad, state.orderUpdates, state.theme),
        (false, false, false, ThemeChoice.system),
      );
      state
        ..signIn(' Tester@Mossgrove.test ')
        ..changeCart((c) => c.add(3, 1))
        ..open(const BenchPlace(Bench.gestures));
      expect(state.signedInEmail, 'tester@mossgrove.test');
      state.signOut();
      expect((state.signedIn, state.cart.isEmpty, state.stack.isEmpty), (false, true, true));
    });

    test('the sign-in check: email ignores case and spaces, the password does not', () {
      expect(AppState.credentialsMatch(' TESTER@mossgrove.test ', 'Mossgrove123'), isTrue);
      expect(AppState.credentialsMatch('tester@mossgrove.test', 'mossgrove123'), isFalse);
      expect(AppState.credentialsMatch('tester@mossgrove.test', 'letmein1'), isFalse);
    });

    test('a deep link waits for sign-in, then opens over the Shop tab', () {
      final state = AppState()..openDeepLink('7');
      expect(state.pendingItemId, '7');
      state.signIn('tester@mossgrove.test');
      expect(state.pendingItemId, isNull);
      expect(state.tab, AppTab.shop);
      expect((state.stack.single.place as ItemPlace).rawId, '7');
      state.switchTab(AppTab.lab);
      state.openDeepLink('999');
      expect(state.tab, AppTab.shop);
      expect((state.stack.single.place as ItemPlace).rawId, '999');
    });
  });

  group('deep links', () {
    test('nthcase-sample://item/{id} and nothing else', () {
      String? id(String link) => DeepLinks.itemId(Uri.parse(link));
      expect(id('nthcase-sample://item/7'), '7');
      expect(id('nthcase-sample://item/999'), '999');
      expect(id('nthcase-sample://item/abc'), 'abc');
      expect(id('nthcase-sample://item/7/'), '7');
      expect(id('nthcase-sample://cart/7'), isNull);
      expect(id('nthcase-sample://item/7/8'), isNull);
      expect(id('nthcase-sample://item'), isNull);
      expect(id('https://item/7'), isNull);
      expect(id('/'), isNull);
      expect(DeepLinks.forItem(7), 'nthcase-sample://item/7');
    });
  });

  group('form rules', () {
    const valid = ClubForm(
      name: 'Sam Rivera',
      email: 'sam@example.test',
      age: '34',
      password: 'garden42x',
      category: Category.garden,
      deliveryDate: null,
      acceptedTerms: true,
    );

    test('an empty form has the seven errors, in the spec words', () {
      expect(FormRules.errors(const ClubForm()), {
        'name': 'Enter your name',
        'email': 'Enter a valid email address',
        'age': 'Enter an age from 18 to 120',
        'password': 'Use at least 8 characters, including a number',
        'category': 'Choose a favourite aisle',
        'date': 'Choose a delivery date',
        'terms': 'Accept the terms to continue',
      });
    });

    test('each rule', () {
      ClubForm with_({String? email, String? age, String? password}) => ClubForm(
        name: valid.name,
        email: email ?? valid.email,
        age: age ?? valid.age,
        password: password ?? valid.password,
        category: valid.category,
        deliveryDate: DateTime(2026, 11, 15),
        acceptedTerms: true,
      );
      expect(FormRules.errors(with_()), isEmpty);
      expect(FormRules.errors(with_(email: 'sam@example')).keys, ['email']);
      expect(FormRules.errors(with_(email: 'sam @example.test')).keys, ['email']);
      expect(FormRules.errors(with_(age: '17')).keys, ['age']);
      expect(FormRules.errors(with_(age: '121')).keys, ['age']);
      expect(FormRules.errors(with_(age: '120')), isEmpty);
      expect(FormRules.errors(with_(password: 'gardenxyz')).keys, ['password']);
      expect(FormRules.errors(with_(password: 'garden4')).keys, ['password']);
    });

    test('the delivery date reads "15 Nov 2026"', () {
      expect(formatDeliveryDate(DateTime(2026, 11, 15)), '15 Nov 2026');
      expect(formatDeliveryDate(DateTime(2027, 1, 3)), '3 Jan 2027');
      expect(formatMonth(DateTime(2026, 11)), 'November 2026');
    });
  });

  group('gestures', () {
    test('a shake is three jolts over 2.5 g within a second', () {
      var shakes = 0;
      final detector = ShakeDetector(() => shakes++);
      const hard = 3 * ShakeDetector.earthGravity;
      detector
        ..onReading(0, hard, 0, 0)
        ..onReading(0, hard, 0, 400);
      expect(shakes, 0);
      detector.onReading(0, 9.8, 0, 500); // a resting reading is not a jolt
      detector.onReading(0, hard, 0, 900);
      expect(shakes, 1);
      detector
        ..onReading(hard, 0, 0, 2000)
        ..onReading(hard, 0, 0, 2600)
        ..onReading(hard, 0, 0, 3100); // the first has left the window
      expect(shakes, 1);
      detector.onReading(0, 0, hard, 3300);
      expect(shakes, 2);
    });

    test('a swipe goes the way of its longest axis, from 48 dp', () {
      expect(swipeDirection(-100, 20, 48), 'left');
      expect(swipeDirection(100, -99, 48), 'right');
      expect(swipeDirection(10, -60, 48), 'up');
      expect(swipeDirection(-30, 60, 48), 'down');
      expect(swipeDirection(40, 30, 48), isNull);
      expect(zoomText(1), 'Zoom 1.0×');
      expect(rotationText(89.6), 'Rotation 90°');
    });
  });

  group('art', () {
    test('the generated path data is art/ exactly', () {
      for (final (dir, drawings, box, stroke) in [
        ('icons', iconDrawings, 24.0, 2.0),
        ('glyphs', glyphDrawings, 48.0, 2.5),
      ]) {
        final files = Directory('art/$dir').listSync().whereType<File>().where((f) => f.path.endsWith('.svg')).toList();
        expect(drawings.keys.toSet(), files.map((f) => f.uri.pathSegments.last.replaceAll('.svg', '')).toSet());
        for (final file in files) {
          final name = file.uri.pathSegments.last.replaceAll('.svg', '');
          final d = RegExp(r' d="([^"]+)"').firstMatch(file.readAsStringSync())!.group(1);
          expect(drawings[name]!.data, d, reason: file.path);
          expect((drawings[name]!.viewBox, drawings[name]!.stroke), (box, stroke));
        }
      }
      expect(iconDrawings, hasLength(17));
      expect(glyphDrawings, hasLength(10));
    });

    test('the path reader draws every drawing inside its box', () {
      for (final d in [...iconDrawings.values, ...glyphDrawings.values]) {
        final bounds = parseSvgPath(d.data).getBounds();
        expect(bounds.left >= 0 && bounds.top >= 0, isTrue, reason: d.data);
        expect(bounds.right <= d.viewBox && bounds.bottom <= d.viewBox, isTrue, reason: d.data);
        expect(bounds.width, greaterThan(0));
      }
      expect(parseSvgPath('M4 4h16v16H4z').getBounds(), const Rect.fromLTRB(4, 4, 20, 20));
      // relative moves, arcs and flags written with nothing between them
      expect(parseSvgPath('m2 2l4 0a2 2 0 0110 0z').getBounds().left, 2);
      expect(() => parseSvgPath('4 4'), throwsFormatException);
    });
  });

  group('the shared sources and versions', () {
    test('the version line matches pubspec.yaml and SPEC.md', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(RegExp(r'^version: (\S+)\+\d+$', multiLine: true).firstMatch(pubspec)!.group(1), appVersion);
      expect(spec, startsWith('# Mossgrove: the NthCase sample apps (spec $specVersion)'));
    });

    test('every fixed text in SPEC.md §6 is in the app, word for word', () {
      final section = spec.substring(spec.indexOf('## 6. Texts'), spec.indexOf('## 7. Test ids'));
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n')
          .replaceAll(r'\$', r'$')
          .replaceAll(r"\'", "'");
      // each row's second cell lists quoted texts, some with words between: "A", "B", the five slots, "C"
      final quoted = [
        for (final row in section.split('\n').where((l) => l.startsWith('| ') && !l.startsWith('| Where')))
          // a quoted text, then a comma, the cell's end, or words before the next text ("A1" to "Z26", "Lobby (Views)"
          // (Android)): the texts hold no double quote of their own
          for (final m in RegExp(r'"([^"]*)"').allMatches(row.split('|')[2].trim())) m.group(1)!,
      ];
      final texts = quoted.where((t) {
        // placeholders and shorthand ("Swiped left/right/up/down") are checked in the flows instead
        // the classic-toolkit Lobby's rows are Android's and iOS's only: Flutter builds the Lobby once
        if (t == 'Lobby (Views)' || t == 'Lobby (UIKit)') return false;
        return !t.contains('<') && !t.contains('/') && t.trim().length > 1;
      }).toSet();
      expect(texts.length, greaterThan(50));
      for (final text in texts) {
        expect(source, contains(text), reason: 'SPEC.md §6 says "$text"');
      }
    });
  });
}

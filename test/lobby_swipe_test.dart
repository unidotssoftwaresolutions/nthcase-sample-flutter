// The touch that started spec 1.1, shown without a device. On Android, NthCase's reach runs
// `new UiScrollable(new UiSelector().scrollable(true)).scrollIntoView(…)`, which swipes the first scrollable node in the
// tree vertically. Its gesture, read by the Android round from the bytecode of the UiAutomator2 server Appium installs
// (appium-uiautomator2-server v10.2.1): 55 steps, a 10 % dead zone at each end of the node's visible bounds, the finger
// down at the start, 54 moves each after a `SystemClock.sleep(5)`, and up at the end. On a scroller that never scrolls
// vertically `scrollIntoView` makes two such swipes: backward (finger down), then forward (finger up).
//
// Here those two swipes go through Flutter's own pointer pipeline with WidgetTester, at 5 ms a step (the floor in the
// code) and at 19 ms (what run 00ec77f5's phone took), across the Top 10 row with the pager off (then the first
// scrollable), across the pager (the first with it on) and across row 1 inside the page. The points are worked out in
// physical pixels from the node the platform receives, as UiAutomator2 works them out, then given to Flutter in logical
// pixels. Each run records which recognizers the gesture arena accepted and rejected (Flutter's own arena diagnostics),
// which scroller took the drag, and what the touch log says. This is evidence, not a pass/fail of the app: each
// expected outcome below is what the run showed, pinned so that a Flutter update that changes it is noticed.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/data/lobby.dart';
import 'package:mossgrove/src/ids.dart';

import 'support/harness.dart';
import 'support/lobby.dart';

const _steps = 55;
const _deadZone = 0.1;

/// The points of one vertical UiScrollable swipe inside [bounds] (physical pixels, integers as UiAutomator2 has them):
/// [forward] moves the finger up.
List<(int, int)> _swipePoints(Rect bounds, {required bool forward}) {
  final left = bounds.left.round(),
      top = bounds.top.round(),
      right = bounds.right.round(),
      bottom = bounds.bottom.round();
  final adjust = ((bottom - top) * _deadZone).toInt();
  final x = (left + right) ~/ 2;
  final (from, to) = forward ? (bottom - adjust, top + adjust) : (top + adjust, bottom - adjust);
  final step = (to - from) / _steps;
  return [(x, from), for (var i = 1; i < _steps; i++) (x, from + (step * i).toInt()), (x, to)];
}

/// The id of the scroller a [ScrollableState] belongs to: the nearest `Semantics(identifier:)` above it.
String _scrollerName(ScrollableState state) {
  var name = state.position.axis == Axis.vertical ? 'a vertical scroller' : 'a horizontal scroller';
  state.context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is Semantics && (widget.properties.identifier ?? '').isNotEmpty) {
      name = '${widget.properties.identifier} (${state.position.axis.name})';
      return false;
    }
    return true;
  });
  return name;
}

/// One run: the reach's two swipes across [target] (or across the first scrollable when null).
Future<List<String>> _run(
  WidgetTester tester,
  String name, {
  required int stepMs,
  String? target,
  bool pagerOff = false,
}) async {
  final semantics = tester.ensureSemantics();
  final app = await TestApp.start(tester);
  await openLobby(app);
  if (pagerOff) await app.tap(TestIds.lobbyPagerShown);
  final ratio = tester.view.devicePixelRatio;
  final first = firstScrollable(app);
  final node = target == null ? first : platformTree(tester).firstWhere((n) => n.scrollable && ownerId(n) == target);
  // read once, as the reach reads the node's bounds before it swipes
  final bounds = node.rect;
  final lines = <String>[
    'Lobby, ${pagerOff ? 'Show the pager off' : 'Show the pager on'}: swipe across ${ownerId(node)}, '
        'node [${node.rect.left.round()},${node.rect.top.round()}][${node.rect.right.round()},${node.rect.bottom.round()}] '
        'in physical pixels at ${ratio}x, $stepMs ms a step',
    'first scrollable in the tree: ${ownerId(first)} (${first.horizontal ? 'horizontal' : 'vertical'})',
    "Flutter's gesture constants: touch slop $kTouchSlop, pan slop $kPanSlop (logical pixels); long press "
        '${kLongPressTimeout.inMilliseconds} ms, double tap ${kDoubleTapTimeout.inMilliseconds} ms',
  ];

  final scrollers = tester.stateList<ScrollableState>(find.byType(Scrollable)).toList();
  final arena = <String>[];
  final previous = debugPrint;
  debugPrintGestureArenaDiagnostics = true;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) arena.add(message);
  };

  Future<void> swipe(bool forward, String label) async {
    final points = _swipePoints(bounds, forward: forward);
    Offset logical((int, int) p) => Offset(p.$1 / ratio, p.$2 / ratio);
    final start = logical(points.first);
    // the touchable under the finger at its start
    final under = [
      for (final id in [
        for (var n = 1; n <= Lobby.banners; n++) TestIds.lobbyBanner(n),
        for (var m = 1; m <= Lobby.topTiles; m++) TestIds.lobbyTopRowTile(m),
        for (var r = 1; r <= Lobby.rows; r++)
          for (var m = 1; m <= Lobby.tiles; m++) TestIds.lobbyRowTile(r, m),
      ])
        if (app.byId(id).hitTestable().evaluate().isNotEmpty && tester.getRect(app.byId(id).first).contains(start)) id,
    ];
    // the step at which the finger is first more than the touch slop from where it went down
    final slopStep = points.indexWhere((p) => (logical(p) - start).distance > kTouchSlop);
    arena.clear();
    final claimed = <ScrollableState>{};
    final before = {for (final s in scrollers.where((s) => s.mounted)) s: s.position.pixels};
    var elapsed = Duration.zero;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    await gesture.down(start, timeStamp: elapsed);
    for (final p in points.skip(1).take(points.length - 2)) {
      await tester.pump(Duration(milliseconds: stepMs));
      elapsed += Duration(milliseconds: stepMs);
      await gesture.moveTo(logical(p), timeStamp: elapsed);
      for (final s in scrollers.where((s) => s.mounted && s.position.activity is DragScrollActivity)) {
        claimed.add(s);
      }
    }
    await tester.pump(Duration(milliseconds: stepMs));
    elapsed += Duration(milliseconds: stepMs);
    await gesture.up(timeStamp: elapsed);
    // past the double-tap time, so a tap has been counted
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final decisions = arena
        .where((l) => RegExp('Accepting|Rejecting|winner|Eliminating', caseSensitive: false).hasMatch(l))
        .map(
          (l) => l.replaceAll(RegExp(r'^Gesture arena \d+\s+❙\s+'), '').replaceAll(RegExp(r'#[0-9a-f]{5}'), '').trim(),
        )
        .toSet()
        .toList();
    final end = points.last;
    lines
      ..add(
        '$label swipe ${forward ? 'forward (finger up)' : 'backward (finger down)'} from '
        '(${points.first.$1}, ${points.first.$2}) to (${end.$1}, ${end.$2}), ${elapsed.inMilliseconds} ms',
      )
      ..add('  touchable under the finger: ${under.isEmpty ? 'none' : under.join(', ')}')
      ..add(
        '  the finger passed the touch slop at move $slopStep, ${slopStep * stepMs} ms after it went down '
        '(the long-press deadline is ${kLongPressTimeout.inMilliseconds} ms)',
      )
      ..add('  the gesture arena: ${decisions.isEmpty ? 'no decision logged' : decisions.join('; ')}')
      ..add(
        '  scrollers that took the drag: ${claimed.isEmpty ? 'none' : [for (final c in claimed) '${_scrollerName(c)}, ${c.mounted && c.position.pixels != before[c] ? 'moved ${before[c]!.round()} → ${c.position.pixels.round()}' : 'did not move'}'].join('; ')}',
      );
    final open = everyIdentifier(tester);
    final sheet = open.contains(TestIds.lobbySheet);
    lines.add(
      '  touch log: ${sheet ? '(under the quick sheet)' : '${logText(app).replaceAll('\n', ' | ')} (${countText(app)})'}; '
      'quick sheet open: $sheet; detail shown: ${open.contains(TestIds.lobbyDetail)}; '
      'promo shown: ${open.contains(TestIds.lobbyPromo)}',
    );
  }

  try {
    // scrollIntoView on a scroller that never scrolls this way: scrollToBeginning's one backward swipe, then one forward
    await swipe(false, '1.');
    await tester.pump(const Duration(milliseconds: 263)); // the gap between run 00ec77f5's two touches
    await swipe(true, '2.');
  } finally {
    debugPrint = previous;
    debugPrintGestureArenaDiagnostics = false;
  }
  if (find.byType(BottomSheet).evaluate().isNotEmpty) {
    // the sheet's own log line is under it: close it with Back, which logs nothing
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    lines.add('after closing the quick sheet with Back: ${logText(app).replaceAll('\n', ' | ')} (${countText(app)})');
  }
  final dir = Directory('build/lobby/swipe')..createSync(recursive: true);
  File('${dir.path}/$name.txt').writeAsStringSync('${lines.join('\n')}\n');
  semantics.dispose();
  return lines;
}

bool _nothingTouched(List<String> lines) =>
    lines.where((l) => l.contains('touch log:')).every((l) => l.contains('${Lobby.nothingTouched} (Touches: 0)'));

void main() {
  testWidgets('the Top 10 row, pager off, 5 ms a step: the tile rejects the moving finger, nothing is touched', (
    tester,
  ) async {
    final lines = await _run(tester, 'top-row-pager-off-5ms', stepMs: 5, pagerOff: true);
    expect(lines[1], startsWith('first scrollable in the tree: lobby_top_row (horizontal)'));
    expect(lines.where((l) => l.contains('touchable under the finger: lobby_top_row_tile_2')).length, 2);
    expect(lines.where((l) => l.contains('Rejecting: LongPressGestureRecognizer')).length, 2);
    expect(lines.where((l) => l.contains('took the drag: lobby_top_row (horizontal), did not move')).length, 2);
    expect(_nothingTouched(lines), isTrue);
  });

  testWidgets('the Top 10 row, pager off, 19 ms a step: the same, the slop is passed before the long press', (
    tester,
  ) async {
    final lines = await _run(tester, 'top-row-pager-off-19ms', stepMs: 19, pagerOff: true);
    expect(lines[1], startsWith('first scrollable in the tree: lobby_top_row (horizontal)'));
    expect(lines.where((l) => l.contains('266 ms after it went down')).length, 2);
    expect(lines.where((l) => l.contains('Rejecting: LongPressGestureRecognizer')).length, 2);
    expect(lines.where((l) => l.contains('took the drag: lobby_top_row (horizontal), did not move')).length, 2);
    expect(_nothingTouched(lines), isTrue);
  });

  testWidgets('the Top 10 row, pager off, 40 ms a step (a probe): slow enough for a long press', (tester) async {
    final lines = await _run(tester, 'top-row-pager-off-40ms', stepMs: 40, pagerOff: true);
    expect(lines.any((l) => l.contains('quick sheet open: true')), isTrue);
    expect(lines.last, contains('Long-pressed: Pocket Notebook (top row, tile 2)'));
  });

  testWidgets('the pager, pager on, 5 ms a step: nothing is touched', (tester) async {
    final lines = await _run(tester, 'pager-5ms', stepMs: 5);
    expect(lines[1], startsWith('first scrollable in the tree: lobby_pager (horizontal)'));
    expect(lines.where((l) => l.contains('touchable under the finger: lobby_banner_1')).length, 2);
    expect(_nothingTouched(lines), isTrue);
  });

  testWidgets('the pager, pager on, 19 ms a step: nothing is touched', (tester) async {
    final lines = await _run(tester, 'pager-19ms', stepMs: 19);
    expect(lines[1], startsWith('first scrollable in the tree: lobby_pager (horizontal)'));
    expect(lines.where((l) => l.contains('touchable under the finger: lobby_banner_1')).length, 2);
    expect(_nothingTouched(lines), isTrue);
  });

  testWidgets('row 1 inside the page, 5 ms a step: the page takes the drag, nothing is touched', (tester) async {
    final lines = await _run(tester, 'row1-5ms', stepMs: 5, target: TestIds.lobbyRow(1));
    expect(lines.any((l) => l.contains('Accepting: VerticalDragGestureRecognizer')), isTrue);
    expect(lines.any((l) => l.contains('took the drag: lobby_page (vertical)')), isTrue);
    expect(_nothingTouched(lines), isTrue);
  });

  testWidgets('row 1 inside the page, 19 ms a step: the page takes the drag, nothing is touched', (tester) async {
    final lines = await _run(tester, 'row1-19ms', stepMs: 19, target: TestIds.lobbyRow(1));
    expect(lines.any((l) => l.contains('Accepting: VerticalDragGestureRecognizer')), isTrue);
    expect(lines.any((l) => l.contains('took the drag: lobby_page (vertical)')), isTrue);
    expect(_nothingTouched(lines), isTrue);
  });
}

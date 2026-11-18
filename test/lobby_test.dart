// The Lobby (SPEC.md §5, 1.1): the order of its scrollers in the tree the platform receives, the pager and Saved
// absent when they must be, the touch log, and scrolls that touch nothing. The tree is read as the engine sends it to
// Android's AccessibilityNodeInfo tree and to iOS's accessibility elements: depth first, children in traversal order,
// hidden nodes left out (support/harness.dart, platformTree). Android's rule for `scrollable="true"` is applied to
// each node: it has a scroll action (the engine's BaseRoleConfigurator).
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/data/lobby.dart';
import 'package:mossgrove/src/ids.dart';

import 'support/harness.dart';
import 'support/lobby.dart';

const _pagerIds = [
  TestIds.lobbyPager,
  TestIds.lobbyPagerPosition,
  TestIds.lobbyPagerAuto,
  'lobby_banner_1',
  'lobby_banner_2',
  'lobby_banner_3',
  'lobby_banner_4',
  'lobby_banner_5',
];

/// Writes what a test saw to build/lobby/, for the report and for anyone who wants to look.
void record(String name, List<String> lines) {
  final dir = Directory('build/lobby')..createSync(recursive: true);
  File('${dir.path}/$name.txt').writeAsStringSync('${lines.join('\n')}\n');
}

/// Flutter's own tap on a GestureDetector that also takes a double tap is decided once the double-tap time has
/// passed with no second tap: wait it out before reading the log.
Future<void> tapAndWait(TestApp app, String id) async {
  final target = app.byId(id);
  if (target.hitTestable().evaluate().isEmpty) await reveal(app, id);
  await app.tester.tap(target);
  await app.tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
  await app.tester.pumpAndSettle();
}

Future<void> longPress(TestApp app, String id) async {
  await reveal(app, id);
  await app.tester.longPress(app.byId(id));
  await app.tester.pumpAndSettle();
}

void main() {
  testWidgets('with the pager on, its scroller is the first scrollable, then the Top 10 row, then the page', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await openLobby(app);
    final tree = platformTree(tester);
    record('tree-pager-on', [for (final n in tree) n.toString()]);
    final owners = scrollableOwners(app);
    record('scrollables-pager-on', [
      for (final n in tree.where((n) => n.scrollable))
        '${ownerId(n)} ${n.horizontal ? 'horizontal' : 'vertical'} ${n.rect}',
    ]);
    expect(owners.take(5), [
      TestIds.lobbyPager,
      TestIds.lobbyTopRow,
      TestIds.lobbyPage,
      TestIds.lobbyChips,
      TestIds.lobbyRow(1),
    ]);
    // the scroller's node sits inside the id's node, on the same bounds: a swipe on either is the same swipe
    final first = firstScrollable(app);
    expect(first.horizontal, isTrue);
    expect(first.rect, platformNode(app, TestIds.lobbyPager)!.rect);
    // nothing above the pager scrolls: the top bar, the log, the delay choice and the switch come first in the tree
    final index = tree.indexWhere((n) => n.node.id == first.node.id);
    final before = tree.take(index).map((n) => n.id).where((id) => id.isNotEmpty).toList();
    expect(
      before,
      containsAll([TestIds.lobbyTouchLog, TestIds.lobbySavedDelay, TestIds.lobbyPagerShown, TestIds.lobbyPager]),
    );
    expect(tree.take(index).where((n) => n.scrollable), isEmpty);
    semantics.dispose();
  });

  testWidgets('with Show the pager off, the pager is not in the tree and the Top 10 row is the first scrollable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await openLobby(app);
    // move the pager to banner 3 first, so "back on the banner it showed" can be checked
    await tester.drag(app.byId(TestIds.lobbyPager), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.drag(app.byId(TestIds.lobbyPager), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(app.read(TestIds.lobbyPagerPosition), 'Banner 3 of 5');

    await app.tap(TestIds.lobbyPagerShown);
    expect(app.appiumNodes()[TestIds.lobbyPagerShown]!.flagsCollection.isToggled.toBoolOrNull(), isFalse);
    final tree = platformTree(tester);
    record('tree-pager-off', [for (final n in tree) n.toString()]);
    record('scrollables-pager-off', [
      for (final n in tree.where((n) => n.scrollable))
        '${ownerId(n)} ${n.horizontal ? 'horizontal' : 'vertical'} ${n.rect}',
    ]);
    expect(ownerId(firstScrollable(app)), TestIds.lobbyTopRow);
    expect(firstScrollable(app).horizontal, isTrue);
    expect(scrollableOwners(app).take(3), [TestIds.lobbyTopRow, TestIds.lobbyPage, TestIds.lobbyChips]);
    // absent: not in the tree the platform gets, not in the framework's whole tree (hidden nodes too), not built
    final all = everyIdentifier(tester);
    for (final id in _pagerIds) {
      expect(all, isNot(contains(id)), reason: '$id is gone from the semantics tree');
      expect(app.byId(id), findsNothing, reason: '$id is not built');
    }
    expect(find.byType(PageView), findsNothing);

    // the choice is kept when the Lobby is left and opened again
    await app.tap(TestIds.topBarBack);
    await app.tap(TestIds.labLobby);
    expect(ownerId(firstScrollable(app)), TestIds.lobbyTopRow);
    expect(everyIdentifier(tester), isNot(contains(TestIds.lobbyPager)));

    // on again: the first order, and the pager on the banner it showed in this visit (a new visit starts at 1)
    await app.tap(TestIds.lobbyPagerShown);
    expect(scrollableOwners(app).take(3), [TestIds.lobbyPager, TestIds.lobbyTopRow, TestIds.lobbyPage]);
    expect(app.read(TestIds.lobbyPagerPosition), 'Banner 1 of 5');
    await tester.drag(app.byId(TestIds.lobbyPager), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await app.tap(TestIds.lobbyPagerShown);
    await app.tap(TestIds.lobbyPagerShown);
    expect(app.read(TestIds.lobbyPagerPosition), 'Banner 2 of 5');
    semantics.dispose();
  });

  // CI's first 1.1.0 run: XCUITest listed the Top 10 row as the first ScrollView and the pager not at all. iOS makes a
  // scroll view only for a node with hasImplicitScrolling, and PageView sets that flag only with
  // allowImplicitScrolling on. The Lobby's pager turns it on; this checks the flag, the order iOS gets, and that a
  // PageView left at its default is not a scroll view to iOS (so the test would catch the flag being dropped).
  testWidgets('on iOS the pager is a scroll view, the first one, then the Top 10 row, then the page', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await openLobby(app);
    record('ios-scroll-views-pager-on', [
      for (final n in iosTree(tester).where((n) => n.iosScrollView))
        '${ownerId(n)} ${n.horizontal ? 'horizontal' : 'vertical'} ${n.rect}',
    ]);
    expect(iosScrollViewOwners(app).take(3), [TestIds.lobbyPager, TestIds.lobbyTopRow, TestIds.lobbyPage]);
    final pager = iosTree(tester).firstWhere((n) => n.iosScrollView);
    expect(pager.horizontal, isTrue);
    expect(pager.rect, platformNode(app, TestIds.lobbyPager)!.rect);
    // every node Android calls scrollable before the page is a scroll view on iOS too, in the same order
    final androidOrder = scrollableOwners(app).takeWhile((id) => id != TestIds.lobbyPage).toList();
    expect(iosScrollViewOwners(app).takeWhile((id) => id != TestIds.lobbyPage).toList(), androidOrder);

    await app.tap(TestIds.lobbyPagerShown);
    record('ios-scroll-views-pager-off', [
      for (final n in iosTree(tester).where((n) => n.iosScrollView))
        '${ownerId(n)} ${n.horizontal ? 'horizontal' : 'vertical'} ${n.rect}',
    ]);
    expect(iosScrollViewOwners(app).take(2), [TestIds.lobbyTopRow, TestIds.lobbyPage]);
    semantics.dispose();
  });

  testWidgets('a PageView at its default has scroll actions but no hasImplicitScrolling: not a scroll view on iOS', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    Future<SemanticsData> pagerNode({required bool implicit}) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PageView(
            key: UniqueKey(),
            allowImplicitScrolling: implicit,
            children: const [SizedBox.expand(), SizedBox.expand()],
          ),
        ),
      );
      return iosTree(tester).firstWhere((n) => n.scrollable).data;
    }

    final plain = await pagerNode(implicit: false);
    expect(plain.hasAction(SemanticsAction.scrollLeft), isTrue);
    expect(plain.flagsCollection.hasImplicitScrolling, isFalse);
    final implicit = await pagerNode(implicit: true);
    expect(implicit.hasAction(SemanticsAction.scrollLeft), isTrue);
    expect(implicit.flagsCollection.hasImplicitScrolling, isTrue);
    semantics.dispose();
  });

  testWidgets('Saved is absent from the tree until its delay has passed, and a choice starts the count again', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await openLobby(app);
    // a cold start is 0 s: Saved is there at once
    expect(app.appiumNodes().keys, contains(TestIds.lobbyBarSaved));
    expect(app.read(TestIds.lobbySavedDelayChoice(0)), contains('0 s'));
    expect(app.appiumNodes()[TestIds.lobbySavedDelayChoice(0)]!.flagsCollection.isSelected.toBoolOrNull(), isTrue);

    List<String> barItems() => TestIds.lobbyBarItems.where((id) => everyIdentifier(tester).contains(id)).toList();

    // the count starts at the choice: tap, and measure from there
    await tester.tap(app.byId(TestIds.lobbySavedDelayChoice(12)));
    await tester.pump();
    expect(everyIdentifier(tester), isNot(contains(TestIds.lobbyBarSaved)));
    expect(app.byId(TestIds.lobbyBarSaved), findsNothing);
    expect(find.text('Saved'), findsNothing);
    expect(barItems(), [TestIds.lobbyBarHome, TestIds.lobbyBarLive, TestIds.lobbyBarOffers]);
    await tester.pump(const Duration(milliseconds: 11800));
    expect(everyIdentifier(tester), isNot(contains(TestIds.lobbyBarSaved)), reason: 'still absent at 11.8 s');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(app.appiumNodes().keys, contains(TestIds.lobbyBarSaved), reason: 'there at 12.2 s');
    expect(barItems(), TestIds.lobbyBarItems);

    // choosing again starts the count again: 8 s in, choose 12 s again, and Saved is still absent 11.8 s later
    await tester.tap(app.byId(TestIds.lobbySavedDelayChoice(12)));
    await tester.pump(const Duration(seconds: 8));
    await tester.tap(app.byId(TestIds.lobbySavedDelayChoice(12)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 11800));
    expect(everyIdentifier(tester), isNot(contains(TestIds.lobbyBarSaved)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(everyIdentifier(tester), contains(TestIds.lobbyBarSaved));

    // the choice is kept until the app closes, and the count starts again when the Lobby opens
    await app.tap(TestIds.topBarBack);
    await app.tap(TestIds.labLobby);
    expect(app.appiumNodes()[TestIds.lobbySavedDelayChoice(12)]!.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    expect(everyIdentifier(tester), isNot(contains(TestIds.lobbyBarSaved)));
    await tester.pump(const Duration(milliseconds: 12200));
    await tester.pumpAndSettle();
    // a tap on Saved is logged and shows its panel
    await tapAndWait(app, TestIds.lobbyBarSaved);
    expect(logText(app), 'Tapped: Saved (bar)');
    expect(app.read(TestIds.lobbySavedScreen), contains(Lobby.savedEmpty));
    expect(everyIdentifier(tester), isNot(contains(TestIds.lobbyPage)));
    await tapAndWait(app, TestIds.lobbyBarHome);
    expect(app.appiumNodes().keys, contains(TestIds.lobbyPage));
    semantics.dispose();
  });

  testWidgets('every touch is logged: tap, long press, double tap, the sheet, the bar; Reset clears', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await openLobby(app);
    expect(logText(app), Lobby.nothingTouched);
    expect(countText(app), 'Touches: 0');

    // a tile: the detail, then back, with the row where it was
    await tester.drag(app.byId(TestIds.lobbyRow(1)), const Offset(-150, 0));
    await tester.pumpAndSettle();
    final rowPosition = app.read(TestIds.lobbyRowPosition(1));
    expect(rowPosition, isNot('Row 1: tiles 1–3 of 20'));
    await tapAndWait(app, TestIds.lobbyRowTile(1, 3));
    expect(logText(app), 'Tapped: Desk Fern (row 1, tile 3)');
    expect(app.read(TestIds.lobbyDetail), allOf(contains('Desk Fern'), contains('No. 003'), contains('Row 1, tile 3')));
    expect(
      everyIdentifier(tester),
      isNot(contains(TestIds.lobbyTopRow)),
      reason: 'the detail takes the place of the scrollers',
    );
    await app.tap(TestIds.lobbyDetailBack);
    expect(app.read(TestIds.lobbyRowPosition(1)), rowPosition);

    // a Top 10 tile, as the spec's example: "Top 10, tile 2"
    await tapAndWait(app, TestIds.lobbyTopRowTile(2));
    expect(logText(app).split('\n').first, 'Tapped: Pocket Notebook (top row, tile 2)');
    expect(app.read(TestIds.lobbyDetail), contains('Top 10, tile 2'));
    // system Back closes the detail, not the Lobby
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(app.appiumNodes().keys, contains(TestIds.lobbyTopRow));

    // a long press opens the quick sheet; while it is open the tree holds the sheet, not the Lobby under it
    await longPress(app, TestIds.lobbyTopRowTile(2));
    final nodes = app.appiumNodes();
    expect(nodes.keys, containsAll([TestIds.lobbySheet, TestIds.lobbySheetTitle, ...TestIds.lobbySheetButtons]));
    expect(nodes.keys, isNot(contains(TestIds.lobbyTouchLog)));
    expect(app.read(TestIds.lobbySheetTitle), 'Pocket Notebook');
    await app.tap(TestIds.lobbySheetSaved);
    expect(app.byId(TestIds.lobbySheet), findsNothing);
    expect(
      logText(app),
      startsWith('Tapped: Saved (quick sheet, Pocket Notebook)\nLong-pressed: Pocket Notebook (top row, tile 2)'),
    );

    // a banner's long press, then the sheet's Open opens its promo
    await longPress(app, TestIds.lobbyBanner(1));
    await app.tap(TestIds.lobbySheetOpen);
    expect(app.read(TestIds.lobbyPromo), allOf(contains('New in the Kitchen aisle'), contains('Banner 1 of 5')));
    await app.tap(TestIds.lobbyPromoBack);

    // a double tap is one line
    await reveal(app, TestIds.lobbyBoardCell(1, 1));
    await tester.tap(app.byId(TestIds.lobbyBoardCell(1, 1)));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(app.byId(TestIds.lobbyBoardCell(1, 1)));
    await tester.pumpAndSettle();
    expect(logText(app).split('\n').first, 'Double-tapped: A1 (board)');
    expect(countText(app), 'Touches: 7');

    // a chip is selected by a tap; the bar's items log
    await tapAndWait(app, TestIds.lobbyChip(3));
    expect(app.appiumNodes()[TestIds.lobbyChip(3)]!.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    await tapAndWait(app, TestIds.lobbyBarLive);
    expect(logText(app), 'Tapped: Live (bar)\nTapped: Desk (chip 3)\nDouble-tapped: A1 (board)');
    expect(countText(app), 'Touches: 9');

    await app.tap(TestIds.lobbyTouchReset);
    expect(logText(app), Lobby.nothingTouched);
    expect(countText(app), 'Touches: 0');
    semantics.dispose();
  });

  testWidgets('scrolling every scroller by hand or by accessibility touches nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await openLobby(app);
    Future<void> fling(String id, Offset by) async {
      await reveal(app, id);
      await tester.drag(app.byId(id), by);
      await tester.pumpAndSettle();
    }

    await fling(TestIds.lobbyPager, const Offset(-400, 0));
    expect(app.read(TestIds.lobbyPagerPosition), 'Banner 2 of 5');
    await fling(TestIds.lobbyTopRow, const Offset(-300, 0));
    expect(app.read(TestIds.lobbyTopRowPosition), isNot('Top 10: tiles 1–3 of 10'));
    await fling(TestIds.lobbyChips, const Offset(-300, 0));
    for (var row = 1; row <= Lobby.rows; row++) {
      await fling(TestIds.lobbyRow(row), const Offset(-300, 0));
    }
    await fling(TestIds.lobbyInnerList, const Offset(0, -300));
    await fling(TestIds.lobbyBoard, const Offset(-150, 0));
    expect(
      await app.see(TestIds.lobbyBoardPosition),
      'Board: top-left D1',
      reason: 'a horizontal drag moves the board',
    );
    await fling(TestIds.lobbyBoard, const Offset(0, -150));
    expect(
      await app.see(TestIds.lobbyBoardPosition),
      'Board: top-left D4',
      reason: 'a vertical drag moves the board, not the page',
    );
    await reveal(app, TestIds.lobbyFooter);
    expect(app.read(TestIds.lobbyFooter), contains(Lobby.footer));
    expect(logText(app), Lobby.nothingTouched);
    expect(countText(app), 'Touches: 0');

    // the board's accessibility scroll: its two scrollers each take one axis
    final board = platformTree(tester).where((n) => n.scrollable && ownerId(n) == TestIds.lobbyBoard).toList();
    record('board-nodes', [for (final n in board) n.toString()]);
    expect(board.length, 2, reason: "TwoDimensionalScrollable is a vertical Scrollable holding a horizontal one");
    expect(board.first.horizontal, isFalse);
    expect(board.last.horizontal, isTrue);
    expect(board.last.node.ancestors.contains(board.first.node), isTrue, reason: 'the horizontal one is inside');
    semantics.dispose();
  });

  testWidgets('the board reaches M18 both ways, by scroll actions on its two nodes', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await openLobby(app);
    await reveal(app, TestIds.lobbyBoard);
    final scrollables = tester.stateList<ScrollableState>(
      find.descendant(of: app.byId(TestIds.lobbyBoard), matching: find.byWidgetPredicate((w) => w is Scrollable)),
    );
    final vertical = scrollables.firstWhere((s) => s.position.axis == Axis.vertical);
    final horizontal = scrollables.firstWhere((s) => s.position.axis == Axis.horizontal);
    vertical.position.jumpTo(17 * 56);
    horizontal.position.jumpTo(12 * 56);
    await tester.pumpAndSettle();
    expect(await app.see(TestIds.lobbyBoardPosition), 'Board: top-left M18');
    await tapAndWait(app, TestIds.lobbyBoardCell(13, 18));
    expect(logText(app), 'Tapped: M18 (board)');
    semantics.dispose();
  });

  testWidgets('a node taller than the page keeps its children hidden while they scroll on screen (Flutter 3.47.9)', (
    tester,
  ) async {
    // rendering/object.dart, _RenderObjectSemantics._updateGeometry: when a node's clipped size and its own
    // visibility are unchanged, its children's geometry is not recomputed. The grid (12 cells, about 390 high) is taller
    // than the page (180 on this phone), so while the page scrolls across it, its clipped size stays the page's
    // height and its cells keep the hidden flag they had. The engine sends this tree as it is: on Android a hidden
    // node is left out of the AccessibilityNodeInfo tree (AccessibilityBridge.createAccessibilityNodeInfo).
    final semantics = tester.ensureSemantics();
    final app = await TestApp.start(tester);
    await openLobby(app);
    // down the page a cell at a time, by drags, as a swipe would
    for (final n in [1, 3, 5, 7]) {
      await reveal(app, TestIds.lobbyGridCell(n));
    }
    final page = tester.getRect(app.byId(TestIds.lobbyPage));
    final cell = tester.getRect(app.byId(TestIds.lobbyGridCell(7)));
    expect(page.contains(cell.topLeft) && page.contains(cell.bottomRight), isTrue, reason: 'cell 7 is on screen');
    final nodes = app.appiumNodes();
    record('stale-grid', [
      'after revealing cells 1, 3, 5 and 7 by drags: page $page, grid cell 7 $cell, cells in the tree the platform gets: '
          '${[for (var n = 1; n <= 12; n++)
            if (nodes.containsKey(TestIds.lobbyGridCell(n))) n]}',
    ]);
    expect(nodes.keys, isNot(contains(TestIds.lobbyGridCell(9))), reason: 'left out as hidden although on screen');
    expect(
      everyIdentifier(tester),
      contains(TestIds.lobbyGridCell(9)),
      reason: 'in the framework tree, flagged hidden',
    );
    // reached from below, while the grid's bottom comes in, it is there
    await reveal(app, TestIds.lobbyFooter);
    await reveal(app, TestIds.lobbyGridCell(9));
    expect(app.appiumNodes().keys, contains(TestIds.lobbyGridCell(9)));
    semantics.dispose();
  });
}

extension on SemanticsNode {
  Iterable<SemanticsNode> get ancestors sync* {
    var n = parent;
    while (n != null) {
      yield n;
      n = n.parent;
    }
  }
}

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/ids.dart';

import 'harness.dart';

/// Signs in and opens the Lobby from the Lab, as a scenario does.
Future<void> openLobby(TestApp app) async {
  await app.signIn();
  await app.tap(TestIds.navLab);
  await app.tap(TestIds.labLobby);
}

/// The id a node answers to: its own, or that of the nearest node above it with one. A Flutter scroller's own node
/// carries no id (`Semantics(identifier:)` always makes a node of its own, so the id sits on a node around it, with
/// the same bounds).
String ownerId(PlatformNode n) {
  SemanticsNode? node = n.node;
  while (node != null) {
    final id = node.getSemanticsData().identifier;
    if (id.isNotEmpty) return id;
    node = node.parent;
  }
  return '';
}

/// The scrollable nodes the platform receives, in the order UiAutomator2 meets them, each named by its owner id.
List<String> scrollableOwners(TestApp app) => [
  for (final n in platformTree(app.tester))
    if (n.scrollable) ownerId(n),
];

PlatformNode firstScrollable(TestApp app) => platformTree(app.tester).firstWhere((n) => n.scrollable);

/// The node with this id in the platform's tree, or null.
PlatformNode? platformNode(TestApp app, String id) {
  for (final n in platformTree(app.tester)) {
    if (n.id == id) return n;
  }
  return null;
}

/// Every identifier in the framework's whole semantics tree, hidden nodes included: what "absent" is checked against.
Set<String> everyIdentifier(WidgetTester tester) {
  final ids = <String>{};
  void walk(SemanticsNode node) {
    final id = node.getSemanticsData().identifier;
    if (id.isNotEmpty) ids.add(id);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) walk(root);
  }
  return ids;
}

/// What the touch log reads, as Appium reads its node.
String logText(TestApp app) => app.read(TestIds.lobbyTouchLog);

String countText(TestApp app) => app.read(TestIds.lobbyTouchCount);

/// Brings the element with this id into the middle of the page by dragging the page, as a swipe would; elements outside
/// the page (the log, the pager, the Top 10 row, the bar) are already on screen. The drags start at the page's left
/// edge, outside the inner list and the board, which would take them themselves.
///
/// Not `Scrollable.ensureVisible`: that jumps, and after a jump the page's nested nodes (a grid cell inside the grid,
/// in a list item) keep the hidden flag of their last place until something marks their semantics again; a drag does,
/// because a drag switches the scroller's IgnorePointer. The tree then misses nodes that are on screen.
Future<void> reveal(TestApp app, String id) async {
  final tester = app.tester;
  final target = app.byId(id);
  final pageFinder = app.byId(TestIds.lobbyPage);
  final page = tester.getRect(pageFinder);
  final list = tester.state<ScrollableState>(find.descendant(of: pageFinder, matching: find.byType(Scrollable)).first);
  bool inPage() => find.descendant(of: pageFinder, matching: target).evaluate().isNotEmpty;
  if (target.evaluate().isNotEmpty && !inPage()) return;
  Future<void> drag(double dy) async {
    await tester.dragFrom(Offset(page.left + 6, page.center.dy), Offset(0, dy));
    await tester.pumpAndSettle();
  }

  // not built: down the page until it is, then up
  var down = true;
  for (var i = 0; i < 60 && target.evaluate().isEmpty; i++) {
    final before = list.position.pixels;
    await drag(down ? -150 : 150);
    if (list.position.pixels == before) down = !down;
  }
  for (var i = 0; i < 20; i++) {
    final r = tester.getRect(target.first);
    if (r.top >= page.top && r.bottom <= page.bottom) break;
    final dy = r.center.dy - page.center.dy;
    if (dy.abs() < 4) break;
    final before = list.position.pixels;
    await drag(-dy.clamp(-150.0, 150.0));
    if (list.position.pixels == before) break;
  }
}

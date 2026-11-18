import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/data/app_state.dart';
import 'package:mossgrove/src/ids.dart';
import 'package:mossgrove/src/platform/device.dart';
import 'package:mossgrove/src/ui/app.dart';

/// The phone the screenshots and the tests use: 360 × 780 logical pixels (the Android round's size), at 2×.
const phone = Size(360, 780);

/// Today, fixed, so the date picker opens on the same month on every run.
final today = DateTime(2026, 11, 3);

bool _fontsLoaded = false;

/// Loads a real face for the tests: Roboto from the Flutter SDK's material fonts, so text is drawn as text and not as
/// the test font's boxes. The monospace face is the host's Menlo when there is one (macOS), else Roboto again.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  final fonts = _materialFonts();
  final roboto = FontLoader('Roboto');
  for (final weight in [
    'Thin',
    'Light',
    'Regular',
    'Medium',
    'Bold',
    'Black',
    'Italic',
    'MediumItalic',
    'BoldItalic',
  ]) {
    final file = File('${fonts.path}/Roboto-$weight.ttf');
    roboto.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await roboto.load();
  final mono = FontLoader('monospace');
  final menlo = File('/System/Library/Fonts/Menlo.ttc');
  final face = menlo.existsSync() ? menlo : File('${fonts.path}/Roboto-Regular.ttf');
  mono.addFont(Future.value(ByteData.sublistView(face.readAsBytesSync())));
  await mono.load();
  _fontsLoaded = true;
}

/// `<flutter>/bin/cache/artifacts/material_fonts`, found from the test runner's own path.
Directory _materialFonts() {
  final candidates = <Directory>[];
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) candidates.add(Directory('$root/bin/cache/artifacts/material_fonts'));
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    candidates.add(Directory('${dir.path}/material_fonts'));
    candidates.add(Directory('${dir.path}/artifacts/material_fonts'));
    dir = dir.parent;
  }
  return candidates.firstWhere(
    (d) => File('${d.path}/Roboto-Regular.ttf').existsSync(),
    orElse: () => throw StateError('Roboto not found under the Flutter SDK (bin/cache/artifacts/material_fonts)'),
  );
}

/// A stand-in for the care guide's web view: host tests have no web engine. It reports the page loaded on the next
/// frame, as the real one does when the page finishes.
Widget fakeCareGuide(BuildContext context, VoidCallback onLoaded) {
  WidgetsBinding.instance.addPostFrameCallback((_) => onLoaded());
  return ColoredBox(color: Theme.of(context).colorScheme.surface, child: const SizedBox.expand());
}

/// The app on a fixed phone, from a cold start: signed out, empty cart, Settings at their defaults.
class TestApp {
  TestApp(this.tester, this.state, this.device);

  final WidgetTester tester;
  final AppState state;
  final FakeDevice device;

  static Future<TestApp> start(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    FakeDevice? device,
    Size size = phone,
  }) async {
    await loadFonts();
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final state = AppState(clock: () => today);
    final phoneDevice = device ?? FakeDevice();
    await tester.pumpWidget(MossgroveApp(state: state, device: phoneDevice, careGuide: fakeCareGuide));
    await tester.pumpAndSettle();
    return TestApp(tester, state, phoneDevice);
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  /// Taps the element with this id, scrolling it on screen first only when it is not, as Appium would.
  Future<void> tap(String id) async {
    if (byId(id).hitTestable().evaluate().isEmpty) {
      await tester.ensureVisible(byId(id));
      await tester.pumpAndSettle();
    }
    await tester.tap(byId(id));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  /// Types into the text field with this id, replacing what is there.
  Future<void> type(String id, String text) async {
    final field = find.descendant(of: byId(id), matching: find.byType(EditableText));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  /// Scrolls the element with this id on screen, as Appium scrolls before it reads, then reads it.
  Future<String> see(String id) async {
    await tester.ensureVisible(byId(id));
    await tester.pumpAndSettle();
    return read(id);
  }

  /// What Appium reads from the node with this id: a text field's value, or another node's label (with its value).
  String read(String id) {
    final data = appiumNodes()[id];
    if (data == null) throw TestFailure('No node with the id $id in the semantics tree');
    if (data.flagsCollection.isTextField) return data.value;
    return [data.value, data.label].where((s) => s.isNotEmpty).join(', ');
  }

  Future<void> signIn() async {
    await type(TestIds.signinEmail, AppState.testEmail);
    await type(TestIds.signinPassword, AppState.testPassword);
    await tap(TestIds.signinSubmit);
  }

  /// Lets every timer run out: a snackbar's 10 s, a slow load's 3 s.
  Future<void> waitOut([Duration duration = const Duration(seconds: 11)]) async {
    await tester.pump(duration);
    await tester.pumpAndSettle();
  }

  /// The nodes the engine sends to the platform, by id, as Appium reads them: a node that merges its descendants is
  /// sent as one node with their data, and its children are not sent at all; hidden nodes are not sent either.
  Map<String, SemanticsData> appiumNodes() => semanticsById(tester);
}

Map<String, SemanticsData> semanticsById(WidgetTester tester) {
  final nodes = <String, SemanticsData>{};
  final duplicates = <String>[];
  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isHidden) return;
    if (data.identifier.isNotEmpty) {
      if (nodes.containsKey(data.identifier)) duplicates.add(data.identifier);
      nodes[data.identifier] = data;
    }
    if (node.mergeAllDescendantsIntoThisNode) return;
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) walk(root);
  }
  if (duplicates.isNotEmpty) throw TestFailure('Ids on more than one node: $duplicates');
  return nodes;
}

/// Every identifier in the tree the engine sends, in traversal order.
List<String> semanticsIds(WidgetTester tester) => semanticsById(tester).keys.toList();

extension SemanticsDataChecks on SemanticsData {
  bool get tappable => hasAction(SemanticsAction.tap);
}

/// One node as the engine sends it to the platform, in the order Android's bridge adds children to the
/// AccessibilityNodeInfo tree (and iOS's to its accessibility elements): depth first, children in traversal order,
/// hidden children left out, and a node that merges its descendants sent alone.
class PlatformNode {
  PlatformNode(this.node, this.data, this.depth);

  final SemanticsNode node;
  final SemanticsData data;
  final int depth;

  String get id => data.identifier;

  /// Android's rule (`BaseRoleConfigurator`): a node is `scrollable="true"` when it has any of the four scroll actions.
  bool get scrollable =>
      data.hasAction(SemanticsAction.scrollLeft) ||
      data.hasAction(SemanticsAction.scrollRight) ||
      data.hasAction(SemanticsAction.scrollUp) ||
      data.hasAction(SemanticsAction.scrollDown);

  bool get horizontal => data.hasAction(SemanticsAction.scrollLeft) || data.hasAction(SemanticsAction.scrollRight);

  /// The node's bounds on the screen in physical pixels (the tests' phone is 2×), as the platform receives them.
  Rect get rect {
    var r = node.rect;
    SemanticsNode? n = node;
    while (n != null) {
      final t = n.transform;
      if (t != null) r = MatrixUtils.transformRect(t, r);
      n = n.parent;
    }
    return r;
  }

  @override
  String toString() =>
      '${'  ' * depth}#${node.id}${id.isEmpty ? '' : ' id=$id'}${scrollable ? (horizontal ? ' SCROLLS-H' : ' SCROLLS-V') : ''} '
      '[${rect.left.round()},${rect.top.round()}][${rect.right.round()},${rect.bottom.round()}]'
      '${data.label.isEmpty ? '' : ' "${data.label.replaceAll('\n', ' / ')}"'}';
}

/// Every node the platform receives, in the order UiAutomator2 walks them (`new UiSelector().scrollable(true)` takes
/// the first scrollable one in this order).
List<PlatformNode> platformTree(WidgetTester tester) {
  final out = <PlatformNode>[];
  void walk(SemanticsNode node, int depth) {
    final data = node.getSemanticsData();
    out.add(PlatformNode(node, data, depth));
    if (node.mergeAllDescendantsIntoThisNode) return;
    for (final child in node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
      if (child.getSemanticsData().flagsCollection.isHidden) continue;
      walk(child, depth + 1);
    }
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) walk(root, 0);
  }
  return out;
}

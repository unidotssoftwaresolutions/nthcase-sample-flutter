import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'src/data/app_state.dart';
import 'src/platform/device.dart';
import 'src/ui/app.dart';

/// Mossgrove, a fictional shop for testing with NthCase. Every cold start is signed out with an empty cart: the state
/// lives in memory only.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter builds its semantics tree (the ids, labels and actions Appium reads) only once something asks for it:
  // TalkBack or UiAutomator on Android, VoiceOver or an XCUITest query on iOS. A tool's first look can then find an
  // empty screen. Keeping the tree on from the first frame removes that race; it is held for the app's life.
  SemanticsBinding.instance.ensureSemantics();
  runApp(MossgroveApp(state: AppState(), device: PlatformDevice()));
}

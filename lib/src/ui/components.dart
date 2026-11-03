import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/catalog.dart';
import '../ids.dart';
import '../platform/device.dart';
import 'art.dart';
import 'screens/webview_screen.dart';
import 'theme.dart';

/// A test id on a node of its own (SPEC.md §7). The engine sends `identifier` to Android as the node's `resource-id`
/// and to iOS as its `accessibilityIdentifier`, which is what Appium reads. Setting it always starts a new semantics
/// node, and the texts inside (which have no node of their own) are read as that node's label.
///
/// A [region] (a screen, a list, a dialog) keeps every child its own node instead, as Compose's testTag on a column
/// does, so its texts are not run together into one label.
class Id extends StatelessWidget {
  const Id(this.id, {super.key, required this.child, this.region = false});

  final String id;
  final Widget child;
  final bool region;

  @override
  Widget build(BuildContext context) => Semantics(identifier: id, explicitChildNodes: region, child: child);
}

/// A test id on a control's own node. Buttons, sliders and switches make a semantics node of their own, so an [Id]
/// around one would be a parent node with the control inside it. Here the id and the control are merged into one
/// node: the id, the control's role, its label, its state and its actions, as Compose's testTag on a Button is.
class IdControl extends StatelessWidget {
  const IdControl(this.id, {super.key, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(identifier: id, child: child),
  );
}

/// [Id] when [id] is given; the bare child when not. The gift-cards screen reuses components with no ids at all.
Widget maybeId(String? id, Widget child, {bool region = false}) =>
    id == null ? child : Id(id, region: region, child: child);

Widget maybeIdControl(String? id, Widget child) => id == null ? child : IdControl(id, child: child);

/// The app's state and the phone, for every screen below the app.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required this.device,
    required this.snack,
    required this.careGuide,
    required super.child,
  }) : super(notifier: state);

  final Device device;
  final Snack snack;

  /// The care guide's web view; a stand-in in the host tests.
  final CareGuideBuilder careGuide;

  /// The state, rebuilding the caller when it changes.
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// The scope, without rebuilding the caller: for callbacks.
  static AppScope read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!;
}

/// Shows a snackbar from anywhere: a message, and an optional action. It stays 10 s (SPEC.md §5), so a test step after
/// the action still finds it, and it carries the ids snackbar, snackbar_text and snackbar_action.
class Snack {
  Snack(this.messenger);

  final GlobalKey<ScaffoldMessengerState> messenger;

  static const duration = Duration(seconds: 10);

  void show(String message, {String? action, VoidCallback? onAction}) {
    final state = messenger.currentState;
    if (state == null) return;
    state.hideCurrentSnackBar();
    state.showSnackBar(
      SnackBar(
        duration: duration,
        // the action is part of the content, so it can carry its own id
        content: Id(
          TestIds.snackbar,
          region: true,
          child: Row(
            children: [
              Expanded(child: Id(TestIds.snackbarText, child: Text(message))),
              if (action != null)
                Builder(
                  builder: (context) => IdControl(
                    TestIds.snackbarAction,
                    child: TextButton(
                      onPressed: () {
                        state.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
                        onAction?.call();
                      },
                      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.inversePrimary),
                      child: Text(action),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top app bar: the screen's title, and Back on screens below a tab.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar(this.title, {super.key, this.onBack, this.tagged = true});

  final String title;
  final VoidCallback? onBack;

  /// False on the gift-cards screen, which has no ids at all.
  final bool tagged;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: onBack == null ? 16 : 0,
      title: maybeId(tagged ? TestIds.topBarTitle : null, Semantics(header: true, child: Text(title))),
      leading: onBack == null
          ? null
          : maybeIdControl(
              tagged ? TestIds.topBarBack : null,
              IconButton(
                onPressed: onBack,
                icon: ArtIcon(Art.back, label: 'Back'),
              ),
            ),
    );
  }
}

/// "No. 007" in brass monospace: the item's mark on every screen.
class ItemNumber extends StatelessWidget {
  const ItemNumber(this.item, {super.key, this.id});

  final Item item;
  final String? id;

  @override
  Widget build(BuildContext context) =>
      maybeId(id, Text(item.number, style: itemNumberStyle.copyWith(color: Theme.of(context).colorScheme.tertiary)));
}

/// The item's drawing on its aisle's tint.
class GlyphTile extends StatelessWidget {
  const GlyphTile(this.item, {super.key, required this.size, this.label});

  final Item item;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tint = Mossgrove.of(context).aisle(item.category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint.tile, borderRadius: radiusTile),
      alignment: Alignment.center,
      child: ArtIcon(Art.glyph(item.glyph), size: size * 0.62, color: tint.ink, label: label),
    );
  }
}

/// The label holder of a drawer front: a thin frame around the name and the number.
class LabelHolder extends StatelessWidget {
  const LabelHolder(this.item, {super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: radiusLabel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.name, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
          ItemNumber(item),
        ],
      ),
    );
  }
}

/// A − value + stepper. The value's id and the buttons' ids come from the caller.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decreaseId,
    required this.valueId,
    required this.increaseId,
    required this.subject,
    this.min = 1,
    this.max = 9,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String decreaseId;
  final String valueId;
  final String increaseId;
  final String subject;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(Art.minus, 'Decrease $subject', decreaseId, value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 40,
          // the value alone, so a check on its id reads exactly "2"; the buttons name what it counts
          child: Id(
            valueId,
            child: Text(value.toString(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        _StepButton(Art.plus, 'Increase $subject', increaseId, value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton(this.icon, this.label, this.id, this.onPressed);

  final ArtDrawing icon;
  final String label;
  final String id;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // disabled loses its ring as well as its colour, so the state is a shape too
    return IdControl(
      id,
      child: IconButton(
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        style: IconButton.styleFrom(
          side: onPressed == null ? BorderSide.none : BorderSide(color: scheme.outline),
          shape: const CircleBorder(),
        ),
        icon: ArtIcon(
          icon,
          label: label,
          color: onPressed == null ? scheme.onSurface.withValues(alpha: 0.38) : scheme.onSurface,
        ),
      ),
    );
  }
}

/// A centred message with an icon, a title, a line of help and one action: the shape of every empty and error state.
/// The message is one node (its id reads the title and the help); the action button keeps its own id.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.id,
    this.actionId,
    this.isError = false,
  });

  final ArtDrawing icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? id;
  final String? actionId;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            maybeId(
              id,
              Column(
                children: [
                  ArtIcon(icon, size: 40, color: isError ? scheme.error : scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              maybeIdControl(
                actionId,
                isError
                    ? FilledButton(onPressed: onAction, child: Text(actionLabel!))
                    : OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A spinner with a line under it, for the slow loads.
class Loading extends StatelessWidget {
  const Loading(this.text, {super.key, required this.id});

  final String text;
  final String id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Id(
        id,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

enum LoadStatus { loading, failed, ready }

/// How long a slow load takes: the same 3 s on every framework (SPEC.md §3).
const slowLoad = Duration(seconds: 3);

/// The local stand-in for a network load (there is no network). It runs when its screen opens. It waits [slowLoad]
/// when [alwaysSlow] or Settings › Slow loading is on, and fails its first attempt when Settings › Fail the first load
/// is on; [retry] then succeeds. With both off it is ready at once, so normal runs never see a spinner.
class Load extends ChangeNotifier {
  Load(this.state, {this.alwaysSlow = false}) {
    _start();
  }

  final AppState state;
  final bool alwaysSlow;
  int _attempt = 0;
  Timer? _timer;
  late LoadStatus status;

  void _start() {
    final fail = state.failFirstLoad && _attempt == 0;
    if (alwaysSlow || state.slowLoading) {
      status = LoadStatus.loading;
      _timer = Timer(slowLoad, () {
        status = fail ? LoadStatus.failed : LoadStatus.ready;
        notifyListeners();
      });
    } else {
      status = fail ? LoadStatus.failed : LoadStatus.ready;
    }
  }

  void retry() {
    _timer?.cancel();
    _attempt++;
    _start();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// The tab or screen padding every screen keeps: 16 at the sides (SPEC.md §10).
const screenPadding = EdgeInsets.symmetric(horizontal: 16);

/// A pause that ends when the time is up, for the refresh and other waits a screen shows.
Future<void> wait(Duration duration) => Future<void>.delayed(duration);

/// Shorthand for the scope's phone.
Device deviceOf(BuildContext context) => AppScope.read(context).device;

enum ToggleKind { switcher, checkbox, radio }

/// A whole-row toggle: the label and the control are one 48 dp target and one node, which carries the id, the label,
/// the on/off (or ticked, or selected) state and the tap. The control itself is drawn but says nothing, so screen
/// readers and Appium meet one element, as Compose's toggleable row does.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.kind,
    this.id,
    this.leading = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final ToggleKind kind;
  final String? id;

  /// Radio buttons sit before their label, as on Android; switches and checkboxes after it.
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    final control = ExcludeSemantics(
      child: switch (kind) {
        ToggleKind.switcher => Switch(value: value, onChanged: onChanged),
        ToggleKind.checkbox => Checkbox(value: value, onChanged: enabled ? (v) => onChanged!(v ?? false) : null),
        ToggleKind.radio => Radio<bool>(value: true, enabled: enabled),
      },
    );
    Widget row = InkWell(
      onTap: enabled ? () => onChanged!(kind == ToggleKind.radio ? true : !value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            if (leading) ...[control, const SizedBox(width: 8)],
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            if (!leading) control,
          ],
        ),
      ),
    );
    if (kind == ToggleKind.radio) {
      // the drawn radio reads its selection from a group of its own: selected when value is true
      row = RadioGroup<bool>(groupValue: value, onChanged: (_) {}, child: row);
    }
    return Semantics(
      identifier: id,
      toggled: kind == ToggleKind.switcher ? value : null,
      checked: kind == ToggleKind.switcher ? null : value,
      inMutuallyExclusiveGroup: kind == ToggleKind.radio ? true : null,
      enabled: enabled,
      child: row,
    );
  }
}

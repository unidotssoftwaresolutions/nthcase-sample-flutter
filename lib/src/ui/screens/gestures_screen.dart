import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../data/shake_detector.dart';
import '../../ids.dart';
import '../../platform/device.dart';
import '../components.dart';
import '../theme.dart';

/// The status words of the gestures screen. They are the spec's oracle: the same words on every framework.
abstract final class GestureWords {
  static const ready = 'Ready';
  static const tapped = 'Tapped';
  static const doubleTapped = 'Double-tapped';
  static const longPressed = 'Long-pressed';
  static String swiped(String direction) => 'Swiped $direction';
  static const dropped = 'Dropped on the drawer';
  static const dropMissed = 'Dropped outside the drawer';
  static const pinchedOut = 'Pinched out';
  static const pinchedIn = 'Pinched in';
  static const rotatedClockwise = 'Rotated clockwise';
  static const rotatedCounterClockwise = 'Rotated counter-clockwise';
  static const scrolledTo = 'Found the bottom drawer';
  static const shaken = 'Shaken';
}

/// A swipe's direction from its total travel: the longest axis wins. Null when it travelled less than [min].
String? swipeDirection(double dx, double dy, double min) {
  if (math.max(dx.abs(), dy.abs()) < min) return null;
  if (dx.abs() >= dy.abs()) return dx > 0 ? 'right' : 'left';
  return dy > 0 ? 'down' : 'up';
}

/// "Zoom 1.0×" and "Rotation 0°", as the pads show them.
String zoomText(double zoom) => 'Zoom ${zoom.toStringAsFixed(1)}×';

String rotationText(double degrees) => 'Rotation ${degrees.round()}°';

class GesturesScreen extends StatefulWidget {
  const GesturesScreen({super.key});

  @override
  State<GesturesScreen> createState() => _GesturesScreenState();
}

class _GesturesScreenState extends State<GesturesScreen> {
  String _status = GestureWords.ready;
  int _taps = 0;
  double _zoom = 1;
  double _rotation = 0;
  bool _dropped = false;
  StreamSubscription<Motion>? _motion;
  late final ShakeDetector _shake = ShakeDetector(() => _say(GestureWords.shaken));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // the accelerometer is on only while this screen listens
    _motion ??= deviceOf(context).motion().listen((motion) {
      switch (motion) {
        case Reading(:final x, :final y, :final z, :final timestampMs):
          _shake.onReading(x, y, z, timestampMs);
        case Shaken():
          _say(GestureWords.shaken);
      }
    });
  }

  @override
  void dispose() {
    _motion?.cancel();
    super.dispose();
  }

  void _say(String status) {
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context).notifier!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    return Id(
      TestIds.gesturesScreen,
      region: true,
      child: Scaffold(
        appBar: TopBar('Gestures', onBack: state.back),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pinned above the scrolling benches, so the status is on screen after any gesture.
            Material(
              color: scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Id(
                        TestIds.gesturesStatus,
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _status,
                            style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSecondaryContainer),
                          ),
                        ),
                      ),
                    ),
                    Id(
                      TestIds.gesturesOrientation,
                      child: Text(
                        landscape ? 'Landscape' : 'Portrait',
                        style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Id(
                TestIds.gesturesScroll,
                region: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Pad(
                              id: TestIds.gesturesTap,
                              title: 'Tap',
                              hint: 'Taps: $_taps',
                              hintId: TestIds.gesturesTapCount,
                              onTap: () => setState(() {
                                _taps++;
                                _status = GestureWords.tapped;
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Pad(
                              id: TestIds.gesturesDoubleTap,
                              title: 'Double tap',
                              hint: 'Twice, quickly',
                              onDoubleTap: () => _say(GestureWords.doubleTapped),
                              action: 'Double tap',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Pad(
                              id: TestIds.gesturesLongPress,
                              title: 'Long press',
                              hint: 'Hold for a moment',
                              onLongPress: () => _say(GestureWords.longPressed),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SwipePad(onSwipe: (direction) => _say(GestureWords.swiped(direction))),
                      const SizedBox(height: 16),
                      Text('Drag the label onto the drawer', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _DragAndDrop(
                        dropped: _dropped,
                        onDrop: (hit) => setState(() {
                          if (hit) _dropped = true;
                          _status = hit ? GestureWords.dropped : GestureWords.dropMissed;
                        }),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _TwoFingerPad(
                              id: TestIds.gesturesPinch,
                              title: 'Pinch',
                              value: zoomText(_zoom),
                              valueId: TestIds.gesturesZoomValue,
                              scale: _zoom,
                              onEnd: (zoom, _) {
                                if (zoom > 1.05 || zoom < 0.95) {
                                  setState(() {
                                    _zoom = (_zoom * zoom).clamp(0.5, 3.0);
                                    _status = zoom > 1 ? GestureWords.pinchedOut : GestureWords.pinchedIn;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TwoFingerPad(
                              id: TestIds.gesturesRotate,
                              title: 'Rotate',
                              value: rotationText(_rotation),
                              valueId: TestIds.gesturesRotationValue,
                              rotation: _rotation,
                              onEnd: (_, degrees) {
                                if (degrees.abs() > 10) {
                                  setState(() {
                                    _rotation = (_rotation + degrees) % 360;
                                    _status = degrees > 0
                                        ? GestureWords.rotatedClockwise
                                        : GestureWords.rotatedCounterClockwise;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scroll to the bottom drawer. It is below the shelves.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      for (var shelf = 1; shelf <= 12; shelf++) ...[
                        const SizedBox(height: 16),
                        Container(
                          height: 56,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: radiusDrawer),
                          child: Text('Shelf $shelf', style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: IdControl(
                          TestIds.gesturesScrollTarget,
                          child: FilledButton(
                            onPressed: () => _say(GestureWords.scrolledTo),
                            child: const Text('Open the bottom drawer'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _padDecoration(ColorScheme scheme) => BoxDecoration(
  color: scheme.surfaceContainerLow,
  borderRadius: radiusDrawer,
  border: Border.all(color: scheme.outlineVariant),
);

/// A tap, double-tap or long-press pad. The gesture is also an accessibility action, so a screen-reader user can do it.
class _Pad extends StatelessWidget {
  const _Pad({
    required this.id,
    required this.title,
    required this.hint,
    this.hintId,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.action,
  });

  final String id;
  final String title;
  final String hint;
  final String? hintId;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final String? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hintText = Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant));
    return Id(
      id,
      child: Semantics(
        customSemanticsActions: action == null ? null : {CustomSemanticsAction(label: action!): onDoubleTap!},
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radiusDrawer,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            child: Ink(
              height: 104,
              padding: const EdgeInsets.all(12),
              decoration: _padDecoration(scheme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  // its own node, so the count keeps its id inside the tappable pad
                  if (hintId != null) Id(hintId!, child: hintText) else hintText,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pan that wins at once, so a swipe on the pad is the pad's and never scrolls the page.
class _EagerPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _SwipePad extends StatefulWidget {
  const _SwipePad({required this.onSwipe});

  final ValueChanged<String> onSwipe;

  @override
  State<_SwipePad> createState() => _SwipePadState();
}

class _SwipePadState extends State<_SwipePad> {
  Offset _travel = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Id(
      TestIds.gesturesSwipe,
      child: Semantics(
        label: 'Swipe pad',
        customSemanticsActions: {
          for (final d in ['left', 'right', 'up', 'down'])
            CustomSemanticsAction(label: 'Swipe $d'): () => widget.onSwipe(d),
        },
        child: RawGestureDetector(
          gestures: {
            _EagerPan: GestureRecognizerFactoryWithHandlers<_EagerPan>(
              _EagerPan.new,
              (pan) => pan
                ..onStart = ((_) => _travel = Offset.zero)
                ..onUpdate = ((details) => _travel += details.delta)
                ..onEnd = ((_) {
                  // 48 dp, the spec's least swipe
                  final direction = swipeDirection(_travel.dx, _travel.dy, 48);
                  if (direction != null) widget.onSwipe(direction);
                }),
            ),
          },
          child: Container(
            height: 140,
            decoration: _padDecoration(scheme),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Swipe', style: theme.textTheme.titleSmall),
                  Text(
                    'Left, right, up or down',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragAndDrop extends StatelessWidget {
  const _DragAndDrop({required this.dropped, required this.onDrop});

  final bool dropped;
  final ValueChanged<bool> onDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = Container(
      width: 120,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: radiusLabel,
        border: Border.all(color: scheme.tertiary),
      ),
      child: Text('No. 007', style: itemNumberStyle.copyWith(color: scheme.onTertiaryContainer)),
    );
    return Row(
      children: [
        Id(
          TestIds.gesturesDragSource,
          child: Semantics(
            label: 'Label No. 007',
            customSemanticsActions: {CustomSemanticsAction(label: 'Drop on the drawer'): () => onDrop(true)},
            child: Draggable<String>(
              data: 'No. 007',
              feedback: Material(color: Colors.transparent, child: label),
              childWhenDragging: Opacity(opacity: 0.4, child: label),
              onDragEnd: (details) => onDrop(details.wasAccepted),
              child: ExcludeSemantics(child: label),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Id(
            TestIds.gesturesDropTarget,
            child: DragTarget<String>(
              onAcceptWithDetails: (_) {},
              builder: (context, candidates, _) => Semantics(
                label: dropped ? 'Drawer, labelled' : 'Drawer, no label',
                child: ExcludeSemantics(
                  child: Container(
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dropped || candidates.isNotEmpty ? scheme.primaryContainer : scheme.surfaceContainerLow,
                      borderRadius: radiusDrawer,
                      border: Border.all(color: scheme.outline, width: 2),
                    ),
                    child: Text(dropped ? 'Labelled' : 'Drawer'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Claims the pointers once a second finger is down, so a pinch or a turn is the pad's and does not scroll the page.
/// One finger is left to the page.
class _TwoFingerClaim extends OneSequenceGestureRecognizer {
  final Set<int> _down = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _down.add(event.pointer);
    if (_down.length >= 2) resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _down.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) => _down.clear();

  @override
  String get debugDescription => 'two-finger claim';
}

/// A pad that reads a two-finger gesture from first touch to last lift, then reports its total zoom and rotation
/// (degrees, clockwise positive) once.
class _TwoFingerPad extends StatefulWidget {
  const _TwoFingerPad({
    required this.id,
    required this.title,
    required this.value,
    required this.valueId,
    required this.onEnd,
    this.scale = 1,
    this.rotation = 0,
  });

  final String id;
  final String title;
  final String value;
  final String valueId;
  final void Function(double zoom, double degrees) onEnd;
  final double scale;
  final double rotation;

  @override
  State<_TwoFingerPad> createState() => _TwoFingerPadState();
}

class _TwoFingerPadState extends State<_TwoFingerPad> {
  final Map<int, Offset> _pointers = {};
  double _zoom = 1;
  double _degrees = 0;

  void _down(PointerDownEvent event) {
    if (_pointers.isEmpty) {
      _zoom = 1;
      _degrees = 0;
    }
    _pointers[event.pointer] = event.position;
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    if (_pointers.length >= 2) {
      final ids = _pointers.keys.take(2).toList();
      final before = [_pointers[ids[0]]!, _pointers[ids[1]]!];
      _pointers[event.pointer] = event.position;
      final after = [_pointers[ids[0]]!, _pointers[ids[1]]!];
      final spanBefore = (before[1] - before[0]).distance;
      final spanAfter = (after[1] - after[0]).distance;
      if (spanBefore > 0) _zoom *= spanAfter / spanBefore;
      var turn = (after[1] - after[0]).direction - (before[1] - before[0]).direction;
      if (turn > math.pi) turn -= 2 * math.pi;
      if (turn < -math.pi) turn += 2 * math.pi;
      // screen y points down, so a positive angle is clockwise
      _degrees += turn * 180 / math.pi;
    } else {
      _pointers[event.pointer] = event.position;
    }
  }

  void _up(PointerEvent event) {
    if (_pointers.remove(event.pointer) == null) return;
    if (_pointers.isEmpty) widget.onEnd(_zoom, _degrees);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Id(
      widget.id,
      child: Semantics(
        label: '${widget.title} pad',
        child: RawGestureDetector(
          gestures: {
            _TwoFingerClaim: GestureRecognizerFactoryWithHandlers<_TwoFingerClaim>(_TwoFingerClaim.new, (_) {}),
          },
          child: Listener(
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: Container(
              height: 160,
              padding: const EdgeInsets.all(12),
              decoration: _padDecoration(scheme),
              child: Stack(
                children: [
                  ExcludeSemantics(child: Text(widget.title, style: theme.textTheme.titleSmall)),
                  Center(
                    child: Transform.rotate(
                      angle: widget.rotation * math.pi / 180,
                      child: Transform.scale(
                        scale: widget.scale,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: scheme.primary, borderRadius: radiusLabel),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Id(widget.valueId, child: Text(widget.value, style: theme.textTheme.bodySmall)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:collection';
import 'dart:math' as math;

/// A shake is three jolts above 2.5 g within one second (SPEC.md §5, Gestures). Pure, so tests can feed it readings;
/// on Android the gestures screen feeds it the accelerometer through a platform channel.
class ShakeDetector {
  ShakeDetector(this.onShake);

  static const earthGravity = 9.80665;
  static const thresholdG = 2.5;
  static const windowMs = 1000;
  static const jolts = 3;

  final void Function() onShake;
  final Queue<int> _jolts = Queue();

  /// One accelerometer reading in m/s², with its time in milliseconds.
  void onReading(double x, double y, double z, int timestampMs) {
    final g = math.sqrt(x * x + y * y + z * z) / earthGravity;
    if (g < thresholdG) return;
    _jolts.addLast(timestampMs);
    while (_jolts.isNotEmpty && timestampMs - _jolts.first > windowMs) {
      _jolts.removeFirst();
    }
    if (_jolts.length >= jolts) {
      _jolts.clear();
      onShake();
    }
  }
}

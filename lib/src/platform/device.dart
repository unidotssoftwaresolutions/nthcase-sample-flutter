import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Something the phone itself does, from the motion channel: an accelerometer reading (Android) or a finished shake
/// (iOS, where UIKit recognises the shake and calls `motionEnded`).
sealed class Motion {
  const Motion();
}

final class Reading extends Motion {
  const Reading(this.x, this.y, this.z, this.timestampMs);

  final double x;
  final double y;
  final double z;
  final int timestampMs;
}

final class Shaken extends Motion {
  const Shaken();
}

/// What the app asks of the phone. Mossgrove's packages may only be Flutter's own, so the notification permission,
/// local notifications and the accelerometer go through platform channels of the app's own (MainActivity.kt on
/// Android, DevicePlugin.swift on iOS), not third-party plugins. Tests use [FakeDevice].
abstract class Device {
  /// Whether the app may post notifications now. Android 12 and older allow it without asking.
  Future<bool> notificationsAllowed();

  /// Shows the system's notification permission prompt when the system still asks; true when allowed afterwards.
  Future<bool> requestNotifications();

  /// Posts a local notification. Nothing is pushed from a server, and nothing is posted when not allowed.
  Future<void> postNotification(String title, String body);

  /// Readings and shakes while someone listens; the sensor is off otherwise.
  Stream<Motion> motion();
}

class PlatformDevice implements Device {
  static const _notifications = MethodChannel('com.nthcase.sample/notifications');
  static const _motion = EventChannel('com.nthcase.sample/motion');

  @override
  Future<bool> notificationsAllowed() async => await _notifications.invokeMethod<bool>('allowed') ?? false;

  @override
  Future<bool> requestNotifications() async => await _notifications.invokeMethod<bool>('request') ?? false;

  @override
  Future<void> postNotification(String title, String body) =>
      _notifications.invokeMethod<void>('post', {'title': title, 'body': body});

  @override
  Stream<Motion> motion() => _motion.receiveBroadcastStream().map((event) {
    final values = (event as List<Object?>).cast<num>();
    if (values.isEmpty) return const Shaken();
    return Reading(values[0].toDouble(), values[1].toDouble(), values[2].toDouble(), values[3].toInt());
  });
}

/// The phone, for tests: [allowed] says whether notifications are allowed, [grantOnRequest] what the prompt answers,
/// and [motionController] plays readings and shakes.
class FakeDevice implements Device {
  FakeDevice({this.allowed = false, this.grantOnRequest = true});

  bool allowed;
  bool grantOnRequest;
  int prompts = 0;
  final List<(String, String)> posted = [];
  final StreamController<Motion> motionController = StreamController.broadcast();

  @override
  Future<bool> notificationsAllowed() => SynchronousFuture(allowed);

  @override
  Future<bool> requestNotifications() {
    prompts++;
    allowed = allowed || grantOnRequest;
    return SynchronousFuture(allowed);
  }

  @override
  Future<void> postNotification(String title, String body) {
    if (allowed) posted.add((title, body));
    return SynchronousFuture(null);
  }

  @override
  Stream<Motion> motion() => motionController.stream;
}

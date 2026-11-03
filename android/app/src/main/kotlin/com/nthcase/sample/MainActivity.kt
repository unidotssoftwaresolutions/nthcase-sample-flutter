package com.nthcase.sample

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The one activity. Flutter draws every screen; this class answers the app's two platform channels, because Mossgrove
 * takes no third-party plugins (SPEC.md §12):
 * - `com.nthcase.sample/notifications`: the POST_NOTIFICATIONS permission (Android 13+), asked through this Activity,
 *   and local notifications. Nothing is pushed from a server.
 * - `com.nthcase.sample/motion`: accelerometer readings from SensorManager while the gestures screen listens. The Dart
 *   side decides what a shake is.
 */
class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null
    private var accelerometer: SensorEventListener? = null
    private var nextNotificationId = 1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "com.nthcase.sample/notifications").setMethodCallHandler { call, result ->
            when (call.method) {
                "allowed" -> result.success(notificationsAllowed())
                "request" -> requestNotifications(result)
                "post" -> {
                    post(call.argument<String>("title").orEmpty(), call.argument<String>("body").orEmpty())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "com.nthcase.sample/motion").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val sensors = getSystemService(SensorManager::class.java) ?: return
                val sensor = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
                val listener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        // x, y, z in m/s², then the time in milliseconds
                        events.success(
                            listOf(
                                event.values[0].toDouble(),
                                event.values[1].toDouble(),
                                event.values[2].toDouble(),
                                event.timestamp / 1_000_000,
                            ),
                        )
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
                }
                sensors.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_GAME)
                accelerometer = listener
            }

            override fun onCancel(arguments: Any?) = stopAccelerometer()
        })
    }

    override fun onDestroy() {
        stopAccelerometer()
        super.onDestroy()
    }

    private fun stopAccelerometer() {
        accelerometer?.let { getSystemService(SensorManager::class.java)?.unregisterListener(it) }
        accelerometer = null
    }

    /** Android 12 and older allow notifications without asking. */
    private fun notificationsAllowed(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    /** The app's one system permission prompt. Once refused for good, the system answers at once, without a prompt. */
    private fun requestNotifications(result: MethodChannel.Result) {
        if (notificationsAllowed()) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATIONS_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATIONS_REQUEST) return
        pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
    }

    private fun post(title: String, body: String) {
        if (!notificationsAllowed()) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(NotificationChannel(CHANNEL, "Order updates", NotificationManager.IMPORTANCE_DEFAULT))
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_mossgrove)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .build()
        manager.notify(nextNotificationId++, notification)
    }

    private companion object {
        const val CHANNEL = "orders"
        const val NOTIFICATIONS_REQUEST = 7
    }
}

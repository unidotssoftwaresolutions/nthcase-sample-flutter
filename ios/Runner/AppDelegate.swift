import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // shows "Order 1 placed" and the test notification while the app is open, too
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MossgroveDevice") {
      DeviceChannels.shared.register(with: registrar.messenger())
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list])
  }
}

/// The app's two platform channels. Mossgrove takes no third-party plugins (SPEC.md §12), so these are its own:
/// - `com.nthcase.sample/notifications`: UNUserNotificationCenter authorization (the app's one system prompt) and
///   local notifications. Nothing is pushed from a server.
/// - `com.nthcase.sample/motion`: a finished shake, which UIKit recognises and reports to `motionEnded`.
final class DeviceChannels: NSObject, FlutterStreamHandler {
  static let shared = DeviceChannels()

  private var motionSink: FlutterEventSink?

  func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "com.nthcase.sample/notifications", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "allowed": self?.allowed { result($0) }
        case "request": self?.request { result($0) }
        case "post":
          let args = call.arguments as? [String: Any]
          self?.post(title: args?["title"] as? String ?? "", body: args?["body"] as? String ?? "")
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: "com.nthcase.sample/motion", binaryMessenger: messenger).setStreamHandler(self)
  }

  private func allowed(_ done: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let ok = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
      DispatchQueue.main.async { done(ok) }
    }
  }

  /// Asks only while the system still asks; once refused, the answer comes at once, without a prompt.
  private func request(_ done: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      DispatchQueue.main.async { done(granted) }
    }
  }

  private func post(title: String, body: String) {
    allowed { ok in
      guard ok else { return }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
      UNUserNotificationCenter.current().add(request)
    }
  }

  /// A shake, from MainViewController.motionEnded: sent as an empty list.
  func shaken() {
    motionSink?([])
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    motionSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motionSink = nil
    return nil
  }
}

/// The storyboard's root view controller. It stays first responder so UIKit's shake reaches `motionEnded`.
final class MainViewController: FlutterViewController {
  override var canBecomeFirstResponder: Bool { true }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    becomeFirstResponder()
  }

  override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake { DeviceChannels.shared.shaken() }
    super.motionEnded(motion, with: event)
  }
}

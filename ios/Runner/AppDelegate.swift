import Flutter
import ReplayKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var broadcastPicker: RPSystemBroadcastPickerView?
  private var isChannelRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      setupMeetingServiceChannel(messenger: messenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MeetingServicePlugin") {
      setupMeetingServiceChannel(messenger: registrar.messenger())
    }
  }

  private func setupMeetingServiceChannel(messenger: FlutterBinaryMessenger) {
    guard !isChannelRegistered else { return }
    isChannelRegistered = true

    let channel = FlutterMethodChannel(name: "com.cloudnews.app/meeting_service", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "showScreenSharePicker":
        self.showScreenSharePicker(result: result)
      case "startService", "updateService", "stopService":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Displays the iOS system ReplayKit broadcast picker dialog so the user can
  /// launch the Broadcast Upload Extension and begin system screen capture.
  private func showScreenSharePicker(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(false)
        return
      }

      let extensionId = Self.broadcastExtensionBundleId() ?? "com.cloudnews.app.ios.BroadcastExtension"

      let picker: RPSystemBroadcastPickerView
      if let existing = self.broadcastPicker {
        picker = existing
      } else {
        let newPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        newPicker.showsMicrophoneButton = false
        newPicker.isHidden = true
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? self.window {
          window.addSubview(newPicker)
        }
        self.broadcastPicker = newPicker
        picker = newPicker
      }

      picker.preferredExtension = extensionId

      if let button = self.findButton(in: picker) {
        button.sendActions(for: .allTouchEvents)
        button.sendActions(for: .touchUpInside)
        result(true)
      } else {
        result(false)
      }
    }
  }

  private func findButton(in view: UIView) -> UIButton? {
    if let button = view as? UIButton {
      return button
    }
    for subview in view.subviews {
      if let found = findButton(in: subview) {
        return found
      }
    }
    return nil
  }

  /// Dynamically locate the embedded broadcast upload extension bundle identifier
  private static func broadcastExtensionBundleId() -> String? {
    guard let pluginsURL = Bundle.main.builtInPlugInsURL,
          let items = try? FileManager.default.contentsOfDirectory(at: pluginsURL, includingPropertiesForKeys: nil)
    else {
      return nil
    }

    for url in items where url.pathExtension == "appex" {
      guard let bundle = Bundle(url: url),
            let info = bundle.infoDictionary?["NSExtension"] as? [String: Any],
            info["NSExtensionPointIdentifier"] as? String == "com.apple.broadcast-services-upload"
      else {
        continue
      }
      return bundle.bundleIdentifier
    }
    return nil
  }
}

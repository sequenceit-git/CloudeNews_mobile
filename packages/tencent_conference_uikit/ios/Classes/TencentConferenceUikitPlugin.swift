import Flutter
import ReplayKit
import UIKit

public class TencentConferenceUikitPlugin: NSObject, FlutterPlugin {
  private var broadcastPicker: RPSystemBroadcastPickerView?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "tencent_conference_uikit", binaryMessenger: registrar.messenger())
    let instance = TencentConferenceUikitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "enableWakeLock":
      enableWakeLock(call, result)
    case "showScreenSharePicker":
      showScreenSharePicker(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func enableWakeLock(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let enable = arguments["enable"] as? Bool
    else {
      result(nil)
      return
    }

    DispatchQueue.main.async {
      UIApplication.shared.isIdleTimerDisabled = enable
      result(nil)
    }
  }

  /// Returns false when the app has no embedded broadcast upload extension.
  private func showScreenSharePicker(_ result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let extensionId = Self.broadcastExtensionBundleId() else {
        result(false)
        return
      }

      let picker = self.broadcastPicker ?? RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
      picker.preferredExtension = extensionId
      picker.showsMicrophoneButton = false
      self.broadcastPicker = picker

      let button = picker.subviews.compactMap { $0 as? UIButton }.first
      button?.sendActions(for: .allTouchEvents)
      result(button != nil)
    }
  }

  /// Sideloading tools may rewrite bundle IDs, so read the embedded appex
  /// instead of hard-coding "<app id>.BroadcastExtension".
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

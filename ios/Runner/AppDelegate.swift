import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TgCineNative")!
    let channel = FlutterMethodChannel(name: "io.tgcine/native", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "tdlibPath":
        guard let frameworks = Bundle.main.privateFrameworksPath else {
          result(FlutterError(code: "NATIVE_UNAVAILABLE", message: "TDLib is not bundled", details: nil))
          return
        }
        let path = frameworks + "/tdjson.framework/tdjson"
        result(FileManager.default.fileExists(atPath: path) ? path : nil)
      case "excludeFromBackup":
        guard let path = call.arguments as? String,
              let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
          result(FlutterError(code: "INVALID_PATH", message: "Invalid session path", details: nil))
          return
        }
        var url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.path.hasPrefix(support.standardizedFileURL.path + "/") else {
          result(FlutterError(code: "INVALID_PATH", message: "Session must be inside application support", details: nil))
          return
        }
        do {
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try url.setResourceValues(values)
          result(nil)
        } catch {
          result(FlutterError(code: "STORAGE_FAILED", message: "Session protection failed", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

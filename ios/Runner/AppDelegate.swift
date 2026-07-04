import Flutter
import QuickLook
import UIKit
import UserNotifications
import YandexMapsMobile

/// Retains the QL data source while Quick Look is on screen.
private final class WoodyQuickLookDataSource: NSObject, QLPreviewControllerDataSource {
  private let fileURL: URL

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

  func previewController(
    _ controller: QLPreviewController,
    previewItemAt index: Int
  ) -> QLPreviewItem {
    fileURL as QLPreviewItem
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Keep this in sync with `YANDEX_MAPKIT_API_KEY` in
  // android/app/src/main/kotlin/com/mebellar/app/MainActivity.kt.
  private let yandexMapKitApiKey = "6db07f4e-a68f-4845-9e3c-79ed8d6e9c1f"

  private var quickLookDataSource: WoodyQuickLookDataSource?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // SwiftYandexMapkitPlugin.register(with:) eagerly resolves
    // YMKMapKit.mapKit during GeneratedPluginRegistrant.register, which
    // asserts (and crashes the process) unless setApiKey ran first.
    // Unlike Android, assigning the key on iOS is cheap — no location
    // subscription is started here, so it's safe at app boot even though
    // the actual map screen mounts much later.
    YMKMapKit.setApiKey(yandexMapKitApiKey)
    YMKMapKit.setLocale("uz_UZ")

    // FCM bridges incoming pushes through UNUserNotificationCenter; without
    // this assignment, foreground notifications never reach the Dart-side
    // onMessage handler on iOS.
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WoodyArChannel")!
    let channel = FlutterMethodChannel(
      name: "com.mebellar.app/ar",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "isArSupported":
        result(true)
      case "launchQuickLook":
        self?.launchQuickLook(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func launchQuickLook(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String
    else {
      result(
        FlutterError(
          code: "INVALID_ARGS",
          message: "launchQuickLook requires {path}",
          details: nil
        )
      )
      return
    }

    let fileURL = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      result(false)
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let presenter = Self.topViewController() else {
        result(false)
        return
      }

      let dataSource = WoodyQuickLookDataSource(fileURL: fileURL)
      self?.quickLookDataSource = dataSource

      let preview = QLPreviewController()
      preview.dataSource = dataSource
      presenter.present(preview, animated: true) {
        result(true)
      }
    }
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }

    guard
      let root = scenes
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .rootViewController
    else {
      return nil
    }

    var current: UIViewController? = root
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }
}

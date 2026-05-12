import Flutter
import UIKit
import UserNotifications
import YandexMapsMobile

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Keep this in sync with `YANDEX_MAPKIT_API_KEY` in
  // android/app/src/main/kotlin/com/mebellar/app/MainActivity.kt.
  private let yandexMapKitApiKey = "6db07f4e-a68f-4845-9e3c-79ed8d6e9c1f"

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
  }
}

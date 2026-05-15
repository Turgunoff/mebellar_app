package com.mebellar.app

import com.yandex.mapkit.MapKitFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // True once a map screen has asked us to boot Yandex MapKit. Keeps the
    // 'init' channel call idempotent.
    private var mapKitStarted = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Must run before super: YandexMapkitPlugin.onAttachedToEngine (called
        // by GeneratedPluginRegistrant inside super) calls
        // MapKitFactory.initialize(), which asserts that setApiKey was already
        // called. setApiKey itself is a cheap static-string write — it does not
        // start any LocationSubscription.
        MapKitFactory.setApiKey(YANDEX_MAPKIT_API_KEY)

        super.configureFlutterEngine(flutterEngine)

        // The yandex_mapkit plugin's onAttachedToActivity (run inside super)
        // unconditionally calls MapKitFactory.getInstance().onStart(). That
        // boots Yandex's location subscriptions the instant the app launches —
        // before any map screen exists and before ACCESS_FINE_LOCATION is
        // granted — which floods logcat with SecurityExceptions on every cold
        // start. Stop it right back; the map screen restarts MapKit on demand
        // through the 'init' channel call below.
        MapKitFactory.getInstance().onStop()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPKIT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Called by Dart's YandexMapKitInitializer right before a
                    // YandexMap widget mounts (after the location permission
                    // prompt). This is the only place MapKit is actually
                    // started, so location services stay off until a map is
                    // genuinely needed.
                    "init" -> {
                        if (!mapKitStarted) {
                            MapKitFactory.getInstance().onStart()
                            mapKitStarted = true
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val MAPKIT_CHANNEL = "com.mebellar.app/yandex_mapkit"
        const val YANDEX_MAPKIT_API_KEY = "6db07f4e-a68f-4845-9e3c-79ed8d6e9c1f"
    }
}

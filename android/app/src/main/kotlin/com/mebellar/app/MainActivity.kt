package com.mebellar.app

import com.yandex.mapkit.MapKitFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Must run before super: YandexMapkitPlugin.onAttachedToEngine (called
        // by GeneratedPluginRegistrant inside super) calls
        // MapKitFactory.initialize(), which asserts that setApiKey was already
        // called. setApiKey itself is a cheap static-string write — it does not
        // start any LocationSubscription.
        MapKitFactory.setApiKey(YANDEX_MAPKIT_API_KEY)

        super.configureFlutterEngine(flutterEngine)

        // Keep the MethodChannel so Dart-side YandexMapKitInitializer still
        // compiles; the actual key was already set above, so this is a no-op.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPKIT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val MAPKIT_CHANNEL = "com.mebellar.app/yandex_mapkit"
        const val YANDEX_MAPKIT_API_KEY = "6db07f4e-a68f-4845-9e3c-79ed8d6e9c1f"
    }
}

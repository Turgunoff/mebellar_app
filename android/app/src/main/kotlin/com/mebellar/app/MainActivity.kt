package com.mebellar.app

import com.yandex.mapkit.MapKitFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mapKitInitialized = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPKIT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        if (!mapKitInitialized) {
                            MapKitFactory.setApiKey(YANDEX_MAPKIT_API_KEY)
                            mapKitInitialized = true
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

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Reads `google-services.json` and bakes the Firebase config into the
    // app at build time. Required for FCM message delivery to work.
    id("com.google.gms.google-services") version "4.4.2" apply false
    // Firebase Crashlytics Gradle plugin — uploads native (NDK) symbol
    // files automatically and tags each release build with a unique
    // mapping so deobfuscated stack traces land in the dashboard.
    id("com.google.firebase.crashlytics") version "3.0.3" apply false
}

include(":app")

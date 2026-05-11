import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Prepares Yandex MapKit for use right before a `YandexMap` widget mounts.
///
/// Initialization is split between the two platforms:
///
/// - **Android**: `MapKitFactory.setApiKey` starts a `LocationSubscription`
///   the moment it runs. Calling it at app boot before the user grants
///   `ACCESS_FINE_LOCATION` floods logcat with `SecurityException`s on every
///   cold start, so we defer it to here and request the permission first.
///   The `com.mebellar.app/yandex_mapkit` MethodChannel handler in
///   `MainActivity.kt` does the actual `setApiKey` call.
///
/// - **iOS**: `SwiftYandexMapkitPlugin.register(with:)` eagerly resolves
///   `YMKMapKit.mapKit` during plugin registration and crashes the
///   process if no key was set. The key therefore has to be assigned in
///   `AppDelegate.swift` before `GeneratedPluginRegistrant.register` runs —
///   which means by the time we reach Dart it's already wired up. Setting
///   the key on iOS does not start any subscription, so this is safe; the
///   location permission prompt only fires when the map view actually
///   needs the user's coordinates.
///
/// Either way, callers should `await ensureInitialized()` once before
/// mounting the `YandexMap` widget. Subsequent calls reuse the same
/// in-flight future and are cheap no-ops.
class YandexMapKitInitializer {
  YandexMapKitInitializer._();

  static const _channel = MethodChannel('com.mebellar.app/yandex_mapkit');
  static Future<void>? _pending;

  static Future<void> ensureInitialized() {
    return _pending ??= _initialize();
  }

  static Future<void> _initialize() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    // Init MapKit even when permission is denied — the map view itself
    // works without location, only the "my location" button needs it.
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('init');
    }
  }
}

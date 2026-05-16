import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../di/service_locator.dart';
import '../platform/location_facade.dart';

/// Prepares Yandex MapKit for use right before a `YandexMap` widget mounts.
///
/// Initialization is split between the two platforms:
///
/// - **Android**: the `yandex_mapkit` plugin calls
///   `MapKitFactory.getInstance().onStart()` from its `onAttachedToActivity`,
///   which runs at app boot (inside `GeneratedPluginRegistrant`). `onStart()`
///   spins up Yandex's `LocationSubscription`, so before the user grants
///   `ACCESS_FINE_LOCATION` it floods logcat with `SecurityException`s on
///   every cold start. `MainActivity.kt` therefore calls `onStop()` straight
///   after boot and re-runs `onStart()` only when this initializer invokes
///   the `init` method on the `com.mebellar.app/yandex_mapkit` channel —
///   after the permission prompt below.
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
    final location = sl<LocationFacade>();
    var permission = await location.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await location.requestPermission();
    }
    // Init MapKit even when permission is denied — the map view itself
    // works without location, only the "my location" button needs it.
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('init');
    }
  }
}

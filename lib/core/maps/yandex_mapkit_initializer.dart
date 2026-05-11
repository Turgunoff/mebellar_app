import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Lazily initializes Yandex MapKit and requests the runtime location
/// permission it needs.
///
/// MapKit's native runtime starts a `LocationSubscription` the moment
/// `MapKitFactory.setApiKey` is called. If we run that at app boot (the
/// pattern the Yandex docs suggest) before the user has granted
/// `ACCESS_FINE_LOCATION`, logcat fills with SecurityExceptions on every
/// cold start — and on iOS we'd be triggering the permission prompt before
/// the user has any context for it.
///
/// Instead, callers (currently only the seller onboarding address step)
/// invoke [ensureInitialized] right before mounting a `YandexMap` widget.
/// The first call requests permission, then bridges to the Android side
/// via the `com.mebellar.app/yandex_mapkit` MethodChannel; subsequent
/// calls are cheap no-ops because the in-flight Future is cached.
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
    // We init MapKit even when permission is denied — the map view itself
    // works without location, only the "my location" button needs it.
    // Worst case, MapKit logs a single SecurityException when the user
    // declines, instead of one on every cold start.
    await _channel.invokeMethod<void>('init');
  }
}

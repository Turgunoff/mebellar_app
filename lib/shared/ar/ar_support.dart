import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../core/logging/talker.dart';

/// Device AR-capability probe for the buyer 3D viewer.
///
/// The viewer launches AR through `<model-viewer>`'s `activateAR()`, which on
/// Android fires a Scene Viewer intent. On a device that isn't ARCore-capable
/// Scene Viewer doesn't fail gracefully — it bounces the user out to the Play
/// Store for a "Google Play Services for AR" build that won't run there. We
/// can't catch that after the intent leaves the app, so we check capability
/// FIRST and, when AR is unavailable, show the in-app 2D camera overlay
/// fallback instead of ever leaving for the store.
class ArSupport {
  ArSupport._();

  static final ArSupport instance = ArSupport._();

  static const MethodChannel _channel = MethodChannel('com.mebellar.app/ar');

  /// Whether the device can run the native AR experience.
  ///
  /// Android: queries `PackageManager.FEATURE_CAMERA_AR` natively — true only
  /// on ARCore-certified hardware. Any failure resolves to `false` so we never
  /// risk the Play Store bounce.
  ///
  /// iOS: AR Quick Look is broadly available on supported devices and
  /// model-viewer degrades to an in-page 3D view (never a store redirect), so
  /// the existing path is kept.
  Future<bool> isSupported() async {
    if (Platform.isAndroid) {
      try {
        final supported = await _channel.invokeMethod<bool>('isArSupported');
        return supported ?? false;
      } catch (e, st) {
        talker.handle(e, st, '[ar-support] capability check failed');
        return false;
      }
    }
    return Platform.isIOS;
  }
}

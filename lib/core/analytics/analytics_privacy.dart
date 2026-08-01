import 'package:hive_flutter/hive_flutter.dart';

import '../di/service_locator.dart';
import '../services/facebook_analytics_service.dart';
import 'analytics_service.dart';

/// Hive (`settings` box) key for the Settings "Foydalanish statistikasi"
/// privacy toggle. Shared by boot, Settings, and any other call site so the
/// preference can't drift across private string literals.
const String kAnalyticsCollectionEnabledKey = 'analytics_collection_enabled';

/// Reads the persisted analytics preference. Defaults to `true` when the key
/// has never been written (first launch / fresh install) — matching the
/// Settings UI default and App Store "collection until opt-out" model.
bool readAnalyticsCollectionEnabled(Box settingsBox) {
  final stored = settingsBox.get(kAnalyticsCollectionEnabledKey);
  return stored is bool ? stored : true;
}

/// Applies the privacy preference to every tracking sink the app owns:
/// Firebase Analytics + Crashlytics (via [AnalyticsService.setAnalyticsEnabled])
/// and Meta / Facebook App Events.
///
/// Called once at cold start after Hive opens (before `runApp`) and again
/// whenever the Settings toggle flips, so an opt-out sticks across restarts
/// and takes effect immediately.
Future<void> applyAnalyticsCollectionEnabled(bool enabled) async {
  if (sl.isRegistered<AnalyticsService>()) {
    await sl<AnalyticsService>().setAnalyticsEnabled(enabled);
  }
  if (sl.isRegistered<FacebookAnalyticsService>()) {
    await sl<FacebookAnalyticsService>().setPrivacyCollectionAllowed(enabled);
  }
}

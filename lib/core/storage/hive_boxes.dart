import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  const HiveBoxes._();

  static const String settings = 'settings';
  static const String cache = 'cache';
  static const String pendingRoute = 'pending_route';
  static const String onboardingDraft = 'onboarding_draft';
  static const String favorites = 'favorites';
  static const String cart = 'cart';

  /// Stores read-state for `news` rows. Anonymous users have no auth.uid,
  /// so we can't keep their per-news read flag server-side — Hive holds a
  /// `Set<String>` of read news ids keyed by 'read_ids'. Cleared when the
  /// user clears app data; that's an acceptable trade-off for marketing
  /// pings.
  static const String newsReads = 'news_reads';
}

typedef CoreBoxes = ({
  Box settings,
  Box cache,
  Box pendingRoute,
  Box onboardingDraft,
  Box favorites,
  Box cart,
  Box newsReads,
});

Future<CoreBoxes> openCoreBoxes() async {
  await Hive.initFlutter();
  final settings = await Hive.openBox(HiveBoxes.settings);
  final cache = await Hive.openBox(HiveBoxes.cache);
  final pendingRoute = await Hive.openBox(HiveBoxes.pendingRoute);
  final onboardingDraft = await Hive.openBox(HiveBoxes.onboardingDraft);
  final favorites = await Hive.openBox(HiveBoxes.favorites);
  final cart = await Hive.openBox(HiveBoxes.cart);
  final newsReads = await Hive.openBox(HiveBoxes.newsReads);
  return (
    settings: settings,
    cache: cache,
    pendingRoute: pendingRoute,
    onboardingDraft: onboardingDraft,
    favorites: favorites,
    cart: cart,
    newsReads: newsReads,
  );
}

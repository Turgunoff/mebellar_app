import 'dart:io';

import '../../core/result/result.dart';
import '../models/shop_settings.dart';

/// Seller shop-settings: working hours, contact info, brand, visibility.
///
/// ROADMAP B.1 — migrated to the `Result<T, Failure>` contract. [watch] stays
/// a plain `Stream` (a realtime feed, not a fallible request).
abstract class ShopSettingsRepository {
  Stream<ShopSettings> watch();
  Future<Result<ShopSettings>> get();
  Future<Result<ShopSettings>> save(ShopSettings settings);
  Future<Result<String>> uploadAsset({
    required String kind,
    required File file,
    required String fileExtension,
  });

  /// Generates a marketing shop description via the backend AI. [hint] is the
  /// seller's current draft to polish (null/empty → write from scratch);
  /// [previous] are texts already shown so a re-tap returns a different variant.
  /// Resolves to `null` when AI is unavailable (off/failed) — the caller shows
  /// a soft hint and leaves the field untouched.
  Future<Result<String?>> generateDescription({
    String? hint,
    List<String> previous,
  });
}

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
}

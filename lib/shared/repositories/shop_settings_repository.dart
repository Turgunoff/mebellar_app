import 'dart:io';

import '../../core/error/failure.dart';
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

/// Legacy Dio stub — superseded by `SupabaseShopSettingsRepository`. Kept so
/// the `RepositoryResolver` remote branch still resolves on non-Supabase
/// builds; every call returns an [Err].
class RemoteShopSettingsRepository implements ShopSettingsRepository {
  RemoteShopSettingsRepository(this._dio);

  // ignore: unused_field — superseded by the Supabase implementation.
  final Object? _dio;

  static const Failure _unavailable = UnknownFailure(
    message: 'Remote shop settings — use the Supabase repository',
  );

  @override
  Stream<ShopSettings> watch() => const Stream.empty();

  @override
  Future<Result<ShopSettings>> get() async => const Err(_unavailable);

  @override
  Future<Result<ShopSettings>> save(ShopSettings settings) async =>
      const Err(_unavailable);

  @override
  Future<Result<String>> uploadAsset({
    required String kind,
    required File file,
    required String fileExtension,
  }) async =>
      const Err(_unavailable);
}

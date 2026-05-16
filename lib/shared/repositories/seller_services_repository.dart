import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/shop_service_config.dart';

/// Selectable delivery / service configuration tied to the seller's shop.
///
/// ROADMAP B.1 — migrated to the `Result<T, Failure>` contract: callers
/// pattern-match the outcome instead of wrapping every call in try/catch.
abstract class SellerServicesRepository {
  Future<Result<List<ShopServiceConfig>>> list();
  Future<Result<List<ShopServiceConfig>>> save(List<ShopServiceConfig> configs);
}

/// Legacy Dio stub — superseded by `SupabaseSellerServicesRepository`. Kept so
/// the `RepositoryResolver` remote branch still resolves on non-Supabase
/// builds; every call returns an [Err].
class RemoteSellerServicesRepository implements SellerServicesRepository {
  RemoteSellerServicesRepository(this._dio);

  // ignore: unused_field — superseded by the Supabase implementation.
  final Dio _dio;

  static const Result<List<ShopServiceConfig>> _notImplemented =
      Err<List<ShopServiceConfig>>(
    UnknownFailure(
      message: 'Remote seller services — use the Supabase repository',
    ),
  );

  @override
  Future<Result<List<ShopServiceConfig>>> list() async => _notImplemented;

  @override
  Future<Result<List<ShopServiceConfig>>> save(
    List<ShopServiceConfig> configs,
  ) async =>
      _notImplemented;
}

import '../../core/network/woody_api_client.dart';
import '../../core/result/result.dart';
import '../models/shop_service.dart';
import '../models/shop_service_config.dart';
import 'seller_services_repository.dart';

/// REST-backed seller services — `GET /seller/services` + `POST
/// /seller/services` (bulk upsert). The backend scopes to the caller's shop,
/// so no client-side shop lookup is needed; an unrecognised `service_type`
/// row is skipped so a stale row can't crash the list.
class WoodySellerServicesRepository implements SellerServicesRepository {
  WoodySellerServicesRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<Result<List<ShopServiceConfig>>> list() => runCatching(() async {
    final rows = await _api.get<List<dynamic>>('/seller/services');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_fromRow)
        .whereType<ShopServiceConfig>()
        .toList(growable: false);
  });

  @override
  Future<Result<List<ShopServiceConfig>>> save(
    List<ShopServiceConfig> configs,
  ) => runCatching(() async {
    final rows = await _api.post<List<dynamic>>(
      '/seller/services',
      body: [for (final c in configs) c.toJson()],
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_fromRow)
        .whereType<ShopServiceConfig>()
        .toList(growable: false);
  });

  ShopServiceConfig? _fromRow(Map<String, dynamic> row) {
    final service = ShopService.fromCode(row['service_type'] as String? ?? '');
    if (service == null) return null;
    return ShopServiceConfig(
      service: service,
      enabled: (row['enabled'] as bool?) ?? false,
      minOrderAmount: row['min_order_amount'] as num?,
      feeAmount: row['fee_amount'] as num?,
      warrantyMonths: (row['warranty_months'] as num?)?.toInt(),
      installmentMonths: (row['installment_months'] as num?)?.toInt(),
    );
  }
}

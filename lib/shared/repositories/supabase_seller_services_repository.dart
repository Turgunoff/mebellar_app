import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/shop_service.dart';
import '../models/shop_service_config.dart';
import 'seller_services_repository.dart';

/// Live Supabase implementation of [SellerServicesRepository] (ROADMAP B.1).
///
/// Schema — `public.shop_services`:
/// ```
///   shop_id            uuid     FK → shops.id
///   service_type       text     ShopService.code
///   enabled            boolean
///   min_order_amount   numeric  nullable
///   fee_amount         numeric  nullable
///   warranty_months    integer  nullable
///   installment_months integer  nullable
///   PRIMARY KEY (shop_id, service_type)
/// ```
/// RLS: a seller may read/write only rows whose `shop_id` belongs to a shop
/// they own — see `docs/supabase_rls_policies.sql.md`.
class SupabaseSellerServicesRepository implements SellerServicesRepository {
  SupabaseSellerServicesRepository({required SupabaseClient supabase})
      : _client = supabase;

  final SupabaseClient _client;

  static const String _table = 'shop_services';

  @override
  Future<Result<List<ShopServiceConfig>>> list() => runCatching(() async {
        final shopId = await _requireShopId();
        final rows = await _client.from(_table).select().eq('shop_id', shopId);
        return rows
            .map(_configFromRow)
            .whereType<ShopServiceConfig>()
            .toList(growable: false);
      });

  @override
  Future<Result<List<ShopServiceConfig>>> save(
    List<ShopServiceConfig> configs,
  ) =>
      runCatching(() async {
        final shopId = await _requireShopId();
        final payload = [
          for (final config in configs)
            {'shop_id': shopId, ...config.toJson()},
        ];
        await _client
            .from(_table)
            .upsert(payload, onConflict: 'shop_id,service_type');
        return List<ShopServiceConfig>.unmodifiable(configs);
      });

  /// Resolves the current seller's shop id. Throws a [Failure] — caught and
  /// converted to an [Err] by [runCatching].
  Future<String> _requireShopId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
    }
    final row = await _client
        .from('shops')
        .select('id')
        .eq('seller_id', userId)
        .maybeSingle();
    final shopId = row?['id'] as String?;
    if (shopId == null) {
      throw const ServerFailure(message: "Do'kon topilmadi");
    }
    return shopId;
  }

  /// Maps a `shop_services` row to a [ShopServiceConfig]; returns `null` for
  /// an unrecognised `service_type` so a stale row can't crash the list.
  ShopServiceConfig? _configFromRow(Map<String, dynamic> row) {
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

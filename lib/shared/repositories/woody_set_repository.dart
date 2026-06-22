import '../../core/network/woody_api_client.dart';
import '../models/product_set.dart';

/// Reads the public `/catalog/sets*` endpoints — furniture sets (garnitur) the
/// buyer can view as a whole in AR / 2D. Only approved sets (with approved
/// member-product AR URLs) come back to the customer app.
class WoodySetRepository {
  WoodySetRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  static const _basePath = '/catalog/sets';

  /// The set plus its ordered member products. Throws on a missing/unapproved
  /// set (backend 404) — the caller surfaces a soft failure.
  Future<SetDetail> fetchSet(String setId) async {
    final body = await _api.get<Map<String, dynamic>>(
      '$_basePath/$setId',
      retries: 2,
    );
    return SetDetail.fromJson(body);
  }

  /// Approved sets, optionally scoped to one shop.
  Future<List<ProductSet>> listSets({String? shopId}) async {
    final query = <String, dynamic>{};
    if (shopId != null) query['shop_id'] = shopId;
    final body = await _api.get<List<dynamic>>(_basePath, query: query);
    return body
        .whereType<Map<String, dynamic>>()
        .map(ProductSet.fromJson)
        .toList(growable: false);
  }
}

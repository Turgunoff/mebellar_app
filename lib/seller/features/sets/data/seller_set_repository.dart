import '../../../../core/network/woody_api_client.dart';
import '../../../../shared/models/product_set.dart';

/// REST-backed seller furniture-set (garnitur) repository — targets
/// `/seller/sets` on api.woody.uz.
///
/// A set groups several of the seller's OWN products under a name so a buyer
/// can view the whole garnitur together in AR / 2D. New sets land as
/// `pending_review`; an admin moderates them before they reach the catalogue.
///
/// v1 surface is intentionally minimal — list + create + delete (archive).
/// There is no edit flow yet: the backend `PATCH /seller/sets/{id}` exists but
/// the seller UI doesn't expose it.
class WoodySellerSetRepository {
  WoodySellerSetRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  /// All of the seller's own sets, every status. The backend returns a bare
  /// JSON array of [ProductSet] rows.
  Future<List<ProductSet>> listMySets() async {
    final body = await _api.get<List<dynamic>>('/seller/sets');
    return body
        .whereType<Map<String, dynamic>>()
        .map(ProductSet.fromJson)
        .toList(growable: false);
  }

  /// Creates a set from the seller's own products. `productIds` order is the
  /// member order. The backend answers 403 `product_not_in_shop` if any id
  /// isn't the seller's, and 422 if the list is empty — both surface as the
  /// raised [ApiError] for the caller to map to a snackbar.
  Future<void> createSet({
    required String name,
    String? description,
    required List<String> productIds,
  }) async {
    final trimmed = description?.trim();
    await _api.post<dynamic>(
      '/seller/sets',
      body: {
        'name': name,
        if (trimmed != null && trimmed.isNotEmpty) 'description': trimmed,
        'product_ids': productIds,
      },
    );
  }

  /// Archives a set (`DELETE /seller/sets/{id}` → 204). Recoverable only via
  /// the admin flow, mirroring product archive semantics.
  Future<void> deleteSet(String id) async {
    await _api.delete<dynamic>('/seller/sets/$id');
  }
}

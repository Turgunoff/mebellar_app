import 'dart:io';


import '../models/paginated.dart';
import '../models/seller_product.dart';

class SellerProductFilter {
  const SellerProductFilter({
    this.statuses = const {},
    this.search,
  });

  final Set<SellerProductStatus> statuses;
  final String? search;

  bool matches(SellerProduct p) {
    if (statuses.isNotEmpty && !statuses.contains(p.status)) return false;
    if (search != null && search!.isNotEmpty) {
      final q = search!.toLowerCase();
      if (!p.name.uz!.toLowerCase().contains(q) &&
          !p.sku.toLowerCase().contains(q)) {
        return false;
      }
    }
    return true;
  }

  SellerProductFilter copyWith({
    Set<SellerProductStatus>? statuses,
    String? search,
    bool clearSearch = false,
  }) {
    return SellerProductFilter(
      statuses: statuses ?? this.statuses,
      search: clearSearch ? null : (search ?? this.search),
    );
  }
}

abstract class SellerProductRepository {
  Stream<List<SellerProduct>> watch();

  Future<Paginated<SellerProduct>> list({
    SellerProductFilter filter = const SellerProductFilter(),
    int page = 1,
    int perPage = 20,
  });

  Future<SellerProduct> getById(String id);

  /// Throws [TariffLimitException] when the active products quota is hit.
  Future<SellerProduct> create(SellerProductInput input);

  Future<SellerProduct> update(String id, SellerProductInput input);

  /// Soft-archive — drops the product from the customer catalogue and frees a
  /// tariff slot, but stays recoverable via [restore]. Backed by
  /// `POST /seller/products/{id}/archive`.
  Future<SellerProduct> archive(String id);

  /// Un-archive — sends the product back into moderation as `pending_review`.
  /// Only the admin flow can return it to `approved`. Re-claims a tariff slot,
  /// so the backend answers 422 ("Tarif limit: …") when the plan is full.
  Future<SellerProduct> restore(String id);

  /// Hard-delete — permanently removes the product row
  /// (`DELETE /seller/products/{id}`). Unlike [archive] there is no way back.
  /// The backend answers 409 when the product ever appeared in an order —
  /// purchase history must survive — so such products can only be archived.
  Future<void> delete(String id);

  Future<SellerProduct> submitForReview(String id);

  /// Mock variant copies the file path into a synthetic remote URL so the
  /// gallery can preview without the network.
  Future<SellerProductImage> uploadImage({
    required String productId,
    required File file,
    required String fileExtension,
  });

  Future<void> deleteImage({
    required String productId,
    required String imageId,
  });

  Future<SellerProduct> reorderImages({
    required String productId,
    required List<String> imageIdsInOrder,
  });

  Future<SellerProduct> setPrimaryImage({
    required String productId,
    required String imageId,
  });
}

/// What the form sends to the repository — local files (not yet uploaded)
/// are stripped before save; image uploads happen via [uploadImage] so the
/// progress lives on its own surface.
class SellerProductInput {
  const SellerProductInput({
    required this.name,
    required this.description,
    required this.categorySlug,
    required this.price,
    this.oldPrice,
    required this.stock,
    required this.sku,
    required this.attributes,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.weightKg,
    required this.status,
  });

  final dynamic name;
  final dynamic description;
  final String categorySlug;
  final num price;
  final num? oldPrice;
  final int stock;
  final String sku;
  final Map<String, dynamic> attributes;
  final num? lengthCm;
  final num? widthCm;
  final num? heightCm;
  final num? weightKg;
  final SellerProductStatus status;
}

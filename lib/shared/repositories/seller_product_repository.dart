import 'dart:io';

import '../../core/result/result.dart';
import '../models/paginated.dart';
import '../models/seller_product.dart';

class SellerProductFilter {
  const SellerProductFilter({this.statuses = const {}, this.search});

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

/// One page of the seller catalogue plus whole-catalogue per-status totals.
/// [statusCounts] ignores the active filter and pagination — it backs the
/// filter-chip badges ("Barchasi 11", "Tasdiqlangan 4"), so it must reflect
/// the entire DB catalogue, not the fetched page.
class SellerProductPage extends Paginated<SellerProduct> {
  const SellerProductPage({
    required super.items,
    required super.page,
    required super.perPage,
    required super.total,
    required super.hasNext,
    this.statusCounts = const {},
  });

  final Map<SellerProductStatus, int> statusCounts;
}

/// Seller product catalogue — money/inventory command surface (T-10
/// `Result<T>` migration). [watch] stays a bare `Stream` — the Woody impl
/// never emits on it (`Stream.empty()`, no realtime products feed), and
/// `Result<T>` doesn't apply to a stream's error channel the same way it does
/// to a single `Future` outcome, so it sits outside the file's
/// Result-vs-throw boundary check.
abstract class SellerProductRepository {
  Stream<List<SellerProduct>> watch();

  Future<Result<SellerProductPage>> list({
    SellerProductFilter filter = const SellerProductFilter(),
    int page = 1,
    int perPage = 20,
  });

  Future<Result<SellerProduct>> getById(String id);

  /// A 409 (active products quota hit) surfaces as a generic `Err` — the
  /// Woody impl used to `throw TariffLimitException` here, but nothing in the
  /// app ever caught that type specifically (this repo isn't on the
  /// add-product path — see `AddProductRepository`), so no distinguishing
  /// behaviour is lost by folding it into the same `Failure` every other
  /// error takes.
  Future<Result<SellerProduct>> create(SellerProductInput input);

  Future<Result<SellerProduct>> update(String id, SellerProductInput input);

  /// Soft-archive — drops the product from the customer catalogue and frees a
  /// tariff slot, but stays recoverable via [restore]. Backed by
  /// `POST /seller/products/{id}/archive`.
  Future<Result<SellerProduct>> archive(String id);

  /// Un-archive — sends the product back into moderation as `pending_review`.
  /// Only the admin flow can return it to `approved`. Re-claims a tariff slot,
  /// so the backend answers 422 ("Tarif limit: …") when the plan is full.
  Future<Result<SellerProduct>> restore(String id);

  /// Hard-delete — permanently removes the product row
  /// (`DELETE /seller/products/{id}`). Unlike [archive] there is no way back.
  /// The backend answers 409 when the product ever appeared in an order —
  /// purchase history must survive — so such products can only be archived.
  Future<Result<void>> delete(String id);

  Future<Result<SellerProduct>> submitForReview(String id);

  /// Mock variant copies the file path into a synthetic remote URL so the
  /// gallery can preview without the network.
  Future<Result<SellerProductImage>> uploadImage({
    required String productId,
    required File file,
    required String fileExtension,
  });

  Future<Result<void>> deleteImage({
    required String productId,
    required String imageId,
  });

  Future<Result<SellerProduct>> reorderImages({
    required String productId,
    required List<String> imageIdsInOrder,
  });

  Future<Result<SellerProduct>> setPrimaryImage({
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

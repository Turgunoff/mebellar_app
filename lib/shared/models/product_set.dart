import '../ar/ar_set_piece.dart';
import 'product_model.dart';

/// A named furniture set / garnitur (`product_sets`) grouping several products
/// the buyer can view together in AR / 2D. The list shape returned by
/// `GET /catalog/sets`; [SetDetail] adds the member products.
class ProductSet {
  const ProductSet({
    required this.id,
    required this.shopId,
    required this.sellerId,
    required this.name,
    this.nameI18n = const {},
    this.description,
    this.coverImageUrl,
    this.status = 'approved',
    this.rejectionReason,
    this.itemCount = 0,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String sellerId;
  final String name;
  final Map<String, dynamic> nameI18n;
  final String? description;
  final String? coverImageUrl;
  final String status;
  final String? rejectionReason;
  final int itemCount;
  final DateTime? createdAt;

  factory ProductSet.fromJson(Map<String, dynamic> json) {
    return ProductSet(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameI18n:
          (json['name_i18n'] as Map?)?.cast<String, dynamic>() ?? const {},
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      status: json['status'] as String? ?? 'approved',
      rejectionReason: json['rejection_reason'] as String?,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// A set plus its ordered member products (`GET /catalog/sets/{id}`). Members
/// are full [ProductModel]s, so their AR URLs / dimensions (already
/// approved-gated server-side) feed the multi-object AR + 2D sticker scenes.
class SetDetail {
  const SetDetail({required this.info, required this.items});

  final ProductSet info;
  final List<ProductModel> items;

  String get id => info.id;
  String get name => info.name;

  factory SetDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    return SetDetail(
      info: ProductSet.fromJson(json),
      items:
          rawItems
              ?.whereType<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList(growable: false) ??
          const [],
    );
  }

  /// Maps the member products to the placement-screen value type. Every member
  /// is included; the AR screen itself skips pieces without an approved model
  /// (image-only members still work in 2D sticker mode).
  List<ArSetPiece> toPieces() => items
      .map(
        (p) => ArSetPiece(
          id: p.id,
          name: p.name,
          glbUrl: p.hasAr ? p.arModelUrl : null,
          imageUrl: p.thumbnail,
          widthCm: p.widthCm,
          heightCm: p.heightCm,
          depthCm: p.depthCm,
        ),
      )
      .toList(growable: false);
}

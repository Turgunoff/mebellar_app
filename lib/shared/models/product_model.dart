import 'package:equatable/equatable.dart';

class ProductModel extends Equatable {
  const ProductModel({
    required this.id,
    required this.categoryId,
    this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    this.shopId,
    this.shopName,
    required this.name,
    this.description,
    required this.price,
    required this.images,
    this.attributes,
    required this.stock,
    required this.createdAt,
    this.colors = const [],
    this.material,
    this.widthCm,
    this.heightCm,
    this.depthCm,
    this.hasDelivery = false,
    this.deliveryPrice = 0,
    this.hasInstallation = false,
    this.installationPrice = 0,
    this.warrantyMonths = 0,
    this.productionTimeDays,
    this.discountPrice,
    this.arModelUrl,
    this.arStatus = 'none',
  });

  final String id;
  final String categoryId;

  /// Resolved category display name (joined `categories.name_uz`); null when
  /// the join wasn't requested or the category is missing.
  final String? categoryName;
  final String? subcategoryId;

  /// Resolved subcategory display name (joined `subcategories.name`).
  final String? subcategoryName;
  final String? shopId;
  final String? shopName;
  final String name;
  final String? description;
  final double price;
  final List<String> images;
  final Map<String, dynamic>? attributes;
  final int stock;
  final DateTime createdAt;

  /// Primary material text (`products.material`); null when left blank.
  final String? material;

  /// Typed dimension columns (cm). Null when the seller didn't enter them —
  /// most set products carry their per-piece dimensions in [attributes] instead.
  final num? widthCm;
  final num? heightCm;
  final num? depthCm;

  /// Canonical colour slugs from `products.colors` (`text[]`), e.g.
  /// `['white','black']`. Resolved against `kProductColors` for display.
  final List<String> colors;

  // ── Logistics — surfaced on the product detail page ──────────────────────
  final bool hasDelivery;
  final num deliveryPrice;
  final bool hasInstallation;
  final num installationPrice;
  final int warrantyMonths;
  final String? productionTimeDays;

  /// Discounted price from the product's variant (`product_variants.
  /// discount_price`), or null when the seller set no discount.
  final double? discountPrice;

  /// Public URL of the QC-approved 3D model (`.glb`). The backend only sends
  /// this once `ar_status == 'approved'`, so a non-null value means the buyer
  /// "view in your room" entry is live.
  final String? arModelUrl;

  /// AR pipeline state (mirrors backend `ArStatus`): `none | processing |
  /// pending_review | approved | rejected`.
  final String arStatus;

  String? get thumbnail => images.isNotEmpty ? images.first : null;
  bool get inStock => stock > 0;

  /// True when a published 3D model is available for the buyer AR viewer.
  bool get hasAr => (arModelUrl?.isNotEmpty ?? false) && arStatus == 'approved';

  /// True when a real discount applies — a positive discounted price strictly
  /// below the list price.
  bool get hasDiscount =>
      discountPrice != null && discountPrice! > 0 && discountPrice! < price;

  /// The price the customer actually pays — discounted when one applies.
  double get effectivePrice => hasDiscount ? discountPrice! : price;

  /// Whole-percent discount (e.g. 10 for −10%); 0 when there is none.
  int get discountPercent =>
      hasDiscount ? (((price - discountPrice!) / price) * 100).round() : 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final shopEmbed = json['shops'] as Map<String, dynamic>?;
    // `product_variants` embeds as a list; the product carries one variant
    // today, so the discount is read off the first row.
    final variants = json['product_variants'] as List<dynamic>?;
    final firstVariant = (variants != null && variants.isNotEmpty)
        ? variants.first as Map<String, dynamic>?
        : null;
    return ProductModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: (json['category_name'] as String?)?.trim().isNotEmpty == true
          ? (json['category_name'] as String).trim()
          : null,
      subcategoryId: json['subcategory_id'] as String?,
      subcategoryName:
          (json['subcategory_name'] as String?)?.trim().isNotEmpty == true
          ? (json['subcategory_name'] as String).trim()
          : null,
      shopId: json['shop_id'] as String?,
      shopName: shopEmbed?['name'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      images:
          (json['images'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      attributes: json['attributes'] as Map<String, dynamic>?,
      stock: json['stock'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      colors:
          (json['colors'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      material: (json['material'] as String?)?.trim().isNotEmpty == true
          ? (json['material'] as String).trim()
          : null,
      widthCm: json['width_cm'] as num?,
      heightCm: json['height_cm'] as num?,
      depthCm: json['depth_cm'] as num?,
      hasDelivery: json['has_delivery'] as bool? ?? false,
      deliveryPrice: (json['delivery_price'] as num?) ?? 0,
      hasInstallation: json['has_installation'] as bool? ?? false,
      installationPrice: (json['installation_price'] as num?) ?? 0,
      warrantyMonths: (json['warranty_months'] as num?)?.toInt() ?? 0,
      productionTimeDays: json['production_time_days'] as String?,
      discountPrice: (firstVariant?['discount_price'] as num?)?.toDouble(),
      arModelUrl: (json['ar_model_url'] as String?)?.trim().isNotEmpty == true
          ? (json['ar_model_url'] as String).trim()
          : null,
      arStatus: json['ar_status'] as String? ?? 'none',
    );
  }

  /// Serialises to a PostgREST-shaped Map so `fromJson` can round-trip the
  /// model from cache. `shops`/`product_variants` are re-emitted in the same
  /// embed shape PostgREST produces, so the parser stays one code path.
  Map<String, dynamic> toJson() => {
    'id': id,
    'category_id': categoryId,
    if (categoryName != null) 'category_name': categoryName,
    'subcategory_id': subcategoryId,
    if (subcategoryName != null) 'subcategory_name': subcategoryName,
    'shop_id': shopId,
    if (shopName != null) 'shops': {'name': shopName},
    'name': name,
    'description': description,
    'price': price,
    'images': images,
    'attributes': attributes,
    'stock': stock,
    'created_at': createdAt.toIso8601String(),
    'colors': colors,
    if (material != null) 'material': material,
    if (widthCm != null) 'width_cm': widthCm,
    if (heightCm != null) 'height_cm': heightCm,
    if (depthCm != null) 'depth_cm': depthCm,
    'has_delivery': hasDelivery,
    'delivery_price': deliveryPrice,
    'has_installation': hasInstallation,
    'installation_price': installationPrice,
    'warranty_months': warrantyMonths,
    'production_time_days': productionTimeDays,
    if (arModelUrl != null) 'ar_model_url': arModelUrl,
    'ar_status': arStatus,
    if (discountPrice != null)
      'product_variants': [
        {'price': price, 'discount_price': discountPrice},
      ],
  };

  @override
  List<Object?> get props => [id, categoryId, name, price, stock];
}

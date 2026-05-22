import 'package:equatable/equatable.dart';

class SupabaseProductModel extends Equatable {
  const SupabaseProductModel({
    required this.id,
    required this.categoryId,
    this.subcategoryId,
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
    this.hasDelivery = false,
    this.deliveryPrice = 0,
    this.hasInstallation = false,
    this.installationPrice = 0,
    this.warrantyMonths = 0,
    this.productionTimeDays,
    this.discountPrice,
  });

  final String id;
  final String categoryId;
  final String? subcategoryId;
  final String? shopId;
  final String? shopName;
  final String name;
  final String? description;
  final double price;
  final List<String> images;
  final Map<String, dynamic>? attributes;
  final int stock;
  final DateTime createdAt;

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

  String? get thumbnail => images.isNotEmpty ? images.first : null;
  bool get inStock => stock > 0;

  /// True when a real discount applies — a positive discounted price strictly
  /// below the list price.
  bool get hasDiscount =>
      discountPrice != null && discountPrice! > 0 && discountPrice! < price;

  /// The price the customer actually pays — discounted when one applies.
  double get effectivePrice => hasDiscount ? discountPrice! : price;

  /// Whole-percent discount (e.g. 10 for −10%); 0 when there is none.
  int get discountPercent =>
      hasDiscount ? (((price - discountPrice!) / price) * 100).round() : 0;

  factory SupabaseProductModel.fromJson(Map<String, dynamic> json) {
    final shopEmbed = json['shops'] as Map<String, dynamic>?;
    // `product_variants` embeds as a list; the product carries one variant
    // today, so the discount is read off the first row.
    final variants = json['product_variants'] as List<dynamic>?;
    final firstVariant = (variants != null && variants.isNotEmpty)
        ? variants.first as Map<String, dynamic>?
        : null;
    return SupabaseProductModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      subcategoryId: json['subcategory_id'] as String?,
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
      hasDelivery: json['has_delivery'] as bool? ?? false,
      deliveryPrice: (json['delivery_price'] as num?) ?? 0,
      hasInstallation: json['has_installation'] as bool? ?? false,
      installationPrice: (json['installation_price'] as num?) ?? 0,
      warrantyMonths: (json['warranty_months'] as num?)?.toInt() ?? 0,
      productionTimeDays: json['production_time_days'] as String?,
      discountPrice: (firstVariant?['discount_price'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [id, categoryId, name, price, stock];
}

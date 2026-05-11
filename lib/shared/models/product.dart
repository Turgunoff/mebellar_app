import 'package:equatable/equatable.dart';

import 'multilingual_text.dart';
import 'shop.dart';
import 'shop_service.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.slug,
    required this.name,
    required this.price,
    this.oldPrice,
    this.description,
    this.images = const [],
    this.primaryImage,
    this.categorySlug,
    this.shop,
    this.attributes,
    this.shopServices = const [],
    this.stock = 0,
    this.isFavorite = false,
  });

  final String id;
  final String slug;
  final MultilingualText name;
  final num price;
  final num? oldPrice;
  final MultilingualText? description;
  final List<String> images;
  final String? primaryImage;
  final String? categorySlug;
  final Shop? shop;
  final Map<String, dynamic>? attributes;
  final List<ShopService> shopServices;
  final int stock;
  final bool isFavorite;

  bool get isOnSale => oldPrice != null && oldPrice! > price;
  bool get inStock => stock > 0;
  String get heroImage =>
      primaryImage ?? (images.isNotEmpty ? images.first : '');

  Product copyWith({
    String? id,
    String? slug,
    MultilingualText? name,
    num? price,
    num? oldPrice,
    MultilingualText? description,
    List<String>? images,
    String? primaryImage,
    String? categorySlug,
    Shop? shop,
    Map<String, dynamic>? attributes,
    List<ShopService>? shopServices,
    int? stock,
    bool? isFavorite,
  }) {
    return Product(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      description: description ?? this.description,
      images: images ?? this.images,
      primaryImage: primaryImage ?? this.primaryImage,
      categorySlug: categorySlug ?? this.categorySlug,
      shop: shop ?? this.shop,
      attributes: attributes ?? this.attributes,
      shopServices: shopServices ?? this.shopServices,
      stock: stock ?? this.stock,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final imagesRaw = json['images'];
    final images = imagesRaw is List
        ? imagesRaw.whereType<String>().toList(growable: false)
        : const <String>[];
    final shopRaw = json['shop'];
    final servicesRaw = json['shop_services'];
    final services = servicesRaw is List
        ? servicesRaw
            .whereType<String>()
            .map(ShopService.fromCode)
            .whereType<ShopService>()
            .toList(growable: false)
        : const <ShopService>[];
    return Product(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? json['id'] as String,
      name: MultilingualText.fromJson(json['name'] as Map<String, dynamic>?),
      price: (json['price'] as num?) ?? 0,
      oldPrice: json['old_price'] as num?,
      description: MultilingualText.fromJson(
        json['description'] as Map<String, dynamic>?,
      ),
      images: images,
      primaryImage: json['primary_image'] as String?,
      categorySlug: json['category_slug'] as String?,
      shop: shopRaw is Map<String, dynamic> ? Shop.fromJson(shopRaw) : null,
      attributes: json['attributes'] is Map<String, dynamic>
          ? json['attributes'] as Map<String, dynamic>
          : null,
      shopServices: services,
      stock: json['stock'] as int? ?? 0,
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, slug, price, isFavorite, stock];
}

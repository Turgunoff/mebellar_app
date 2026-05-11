import 'package:equatable/equatable.dart';

class SupabaseProductModel extends Equatable {
  const SupabaseProductModel({
    required this.id,
    required this.categoryId,
    this.subcategoryId,
    this.shopId,
    required this.name,
    this.description,
    required this.price,
    required this.images,
    this.attributes,
    required this.stock,
    required this.createdAt,
  });

  final String id;
  final String categoryId;
  final String? subcategoryId;
  final String? shopId;
  final String name;
  final String? description;
  final double price;
  final List<String> images;
  final Map<String, dynamic>? attributes;
  final int stock;
  final DateTime createdAt;

  String? get thumbnail => images.isNotEmpty ? images.first : null;
  bool get inStock => stock > 0;

  factory SupabaseProductModel.fromJson(Map<String, dynamic> json) {
    return SupabaseProductModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      subcategoryId: json['subcategory_id'] as String?,
      shopId: json['shop_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      images: (json['images'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      attributes: json['attributes'] as Map<String, dynamic>?,
      stock: json['stock'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, categoryId, name, price, stock];
}

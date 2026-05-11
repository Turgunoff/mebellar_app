import 'package:equatable/equatable.dart';

import 'supabase_product_model.dart';

/// Storage-shape model for cart rows. Mirrors the `public.cart_items` table
/// in Supabase 1:1 — the JSON it serialises to is also the JSON the Hive box
/// holds for guest users, so the same encode/decode path serves both
/// authenticated and guest sessions.
///
/// We keep a `productSnapshot` of the catalog data so the cart screen can
/// render without re-fetching products from the server (same trick we use
/// for favorites). Price/name/image freshness is acceptable here — when the
/// user opens the product detail or proceeds to checkout the canonical
/// product is loaded again.
class CartItemModel extends Equatable {
  const CartItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.productPrice,
    required this.quantity,
    this.createdAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String productImage;
  final double productPrice;
  final int quantity;
  final DateTime? createdAt;

  double get lineTotal => productPrice * quantity;

  CartItemModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
    int? quantity,
    DateTime? createdAt,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      productPrice: productPrice ?? this.productPrice,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Build a snapshot from a [SupabaseProductModel]. The local id is the
  /// product id — Hive-only sessions don't need server-issued uuids and
  /// authenticated rows replace it with the server uuid on first load.
  factory CartItemModel.fromProduct(
    SupabaseProductModel product, {
    int quantity = 1,
    String? id,
  }) {
    return CartItemModel(
      id: id ?? product.id,
      productId: product.id,
      productName: product.name,
      productImage:
          product.images.isNotEmpty ? product.images.first : '',
      productPrice: product.price,
      quantity: quantity,
    );
  }

  /// Decode a Supabase row. Both the `cart_items` row layout and the
  /// `product_snapshot` JSONB are accepted here so a single helper covers
  /// remote rows and Hive payloads.
  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final snapshot = json['product_snapshot'] is Map<String, dynamic>
        ? json['product_snapshot'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return CartItemModel(
      id: json['id']?.toString() ?? json['product_id']?.toString() ?? '',
      productId: json['product_id'] as String? ??
          snapshot['id'] as String? ??
          '',
      productName: snapshot['name'] as String? ??
          json['product_name'] as String? ??
          '',
      productImage: snapshot['image'] as String? ??
          json['product_image'] as String? ??
          '',
      productPrice: (snapshot['price'] as num?)?.toDouble() ??
          (json['product_price'] as num?)?.toDouble() ??
          0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Hive-friendly JSON. The same structure is used as the `product_snapshot`
  /// JSONB column in Supabase so Hive→Supabase sync is a straight upsert.
  Map<String, dynamic> toSnapshotJson() => <String, dynamic>{
        'id': productId,
        'name': productName,
        'image': productImage,
        'price': productPrice,
      };

  Map<String, dynamic> toHiveJson() => <String, dynamic>{
        'id': id,
        'product_id': productId,
        'quantity': quantity,
        'product_snapshot': toSnapshotJson(),
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  @override
  List<Object?> get props => [id, productId, quantity, productPrice];
}

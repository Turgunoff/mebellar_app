import 'package:equatable/equatable.dart';

import 'product_model.dart';

/// Storage-shape model for cart rows. Mirrors the `public.cart_items` table
/// in the backend 1:1 — the JSON it serialises to is also the JSON the Hive box
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
    this.shopId,
    this.shopName,
    this.selectedColor,
    this.createdAt,
    this.hasDelivery = false,
    this.deliveryPrice = 0,
    this.maxDeliveryFee = 0,
    this.hasInstallation = false,
    this.installationPrice = 0,
  });

  final String id;
  final String productId;
  final String productName;
  final String productImage;
  final double productPrice;
  final int quantity;
  final String? shopId;
  final String? shopName;

  /// Canonical colour slug the customer picked on the product page, or null
  /// when the product has no colour palette. Carried through checkout into
  /// `order_items.color_slug`. Persisted inside the `product_snapshot` JSONB
  /// so neither the Hive box nor `cart_items` needs a dedicated column.
  final String? selectedColor;

  final DateTime? createdAt;

  // ── Per-item delivery / installation pricing ─────────────────────────────
  // Carried from the product so the checkout invoice can compute the delivery
  // and (opt-in) installation fees instantly, before the authoritative
  // `POST /orders/quote` returns. Persisted in the snapshot for guest carts;
  // an order ultimately re-prices these server-side, so a stale snapshot only
  // affects the first paint, never what the customer is charged.
  final bool hasDelivery;
  final num deliveryPrice;
  final int maxDeliveryFee;
  final bool hasInstallation;
  final num installationPrice;

  double get lineTotal => productPrice * quantity;

  /// Delivery contribution for this line (0 when the product offers none).
  double get deliveryFee =>
      hasDelivery ? (deliveryPrice * quantity).toDouble() : 0;

  /// Full installation cost for this line if the customer opts in (0 when the
  /// product offers none). The toggle decides whether it's added to the total.
  double get installationFee =>
      hasInstallation ? (installationPrice * quantity).toDouble() : 0;

  CartItemModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
    int? quantity,
    String? shopId,
    String? shopName,
    String? selectedColor,
    DateTime? createdAt,
    bool? hasDelivery,
    num? deliveryPrice,
    int? maxDeliveryFee,
    bool? hasInstallation,
    num? installationPrice,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      productPrice: productPrice ?? this.productPrice,
      quantity: quantity ?? this.quantity,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      selectedColor: selectedColor ?? this.selectedColor,
      createdAt: createdAt ?? this.createdAt,
      hasDelivery: hasDelivery ?? this.hasDelivery,
      deliveryPrice: deliveryPrice ?? this.deliveryPrice,
      maxDeliveryFee: maxDeliveryFee ?? this.maxDeliveryFee,
      hasInstallation: hasInstallation ?? this.hasInstallation,
      installationPrice: installationPrice ?? this.installationPrice,
    );
  }

  /// Build a snapshot from a [ProductModel]. The local id is the
  /// product id — Hive-only sessions don't need server-issued uuids and
  /// authenticated rows replace it with the server uuid on first load.
  factory CartItemModel.fromProduct(
    ProductModel product, {
    int quantity = 1,
    String? id,
    String? selectedColor,
  }) {
    return CartItemModel(
      id: id ?? product.id,
      productId: product.id,
      productName: product.name,
      productImage: product.images.isNotEmpty ? product.images.first : '',
      // Charge the discounted price when the product is on sale.
      productPrice: product.effectivePrice,
      quantity: quantity,
      shopId: product.shopId,
      shopName: product.shopName,
      selectedColor: selectedColor,
      hasDelivery: product.hasDelivery,
      deliveryPrice: product.deliveryPrice,
      maxDeliveryFee: product.maxDeliveryFee,
      hasInstallation: product.hasInstallation,
      installationPrice: product.installationPrice,
    );
  }

  /// Decode a backend row. Both the `cart_items` row layout and the
  /// `product_snapshot` JSONB are accepted here so a single helper covers
  /// remote rows and Hive payloads.
  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final snapshot = json['product_snapshot'] is Map<String, dynamic>
        ? json['product_snapshot'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return CartItemModel(
      id: json['id']?.toString() ?? json['product_id']?.toString() ?? '',
      productId:
          json['product_id'] as String? ?? snapshot['id'] as String? ?? '',
      productName:
          snapshot['name'] as String? ?? json['product_name'] as String? ?? '',
      productImage:
          snapshot['image'] as String? ??
          json['product_image'] as String? ??
          '',
      productPrice:
          (snapshot['price'] as num?)?.toDouble() ??
          (json['product_price'] as num?)?.toDouble() ??
          0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      shopId: snapshot['shop_id'] as String? ?? json['shop_id'] as String?,
      shopName:
          snapshot['shop_name'] as String? ?? json['shop_name'] as String?,
      // 'selected_color' inside the snapshot covers rows written by app
      // versions that POSTed the colour without a full snapshot.
      selectedColor:
          snapshot['color'] as String? ??
          snapshot['selected_color'] as String? ??
          json['selected_color'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      // Fee fields default off for snapshots written before this feature —
      // the order quote re-derives the authoritative amounts from the catalog.
      hasDelivery: snapshot['has_delivery'] as bool? ?? false,
      deliveryPrice: (snapshot['delivery_price'] as num?) ?? 0,
      maxDeliveryFee: (snapshot['max_delivery_fee'] as num?)?.toInt() ?? 0,
      hasInstallation: snapshot['has_installation'] as bool? ?? false,
      installationPrice: (snapshot['installation_price'] as num?) ?? 0,
    );
  }

  /// Hive-friendly JSON. The same structure is used as the `product_snapshot`
  /// JSONB column in the backend so Hive→backend sync is a straight upsert.
  Map<String, dynamic> toSnapshotJson() => <String, dynamic>{
    'id': productId,
    'name': productName,
    'image': productImage,
    'price': productPrice,
    if (shopId != null) 'shop_id': shopId,
    if (shopName != null) 'shop_name': shopName,
    if (selectedColor != null) 'color': selectedColor,
    if (hasDelivery) 'has_delivery': hasDelivery,
    if (deliveryPrice != 0) 'delivery_price': deliveryPrice,
    if (maxDeliveryFee > 0) 'max_delivery_fee': maxDeliveryFee,
    if (hasInstallation) 'has_installation': hasInstallation,
    if (installationPrice != 0) 'installation_price': installationPrice,
  };

  Map<String, dynamic> toHiveJson() => <String, dynamic>{
    'id': id,
    'product_id': productId,
    'quantity': quantity,
    'product_snapshot': toSnapshotJson(),
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    productId,
    quantity,
    productPrice,
    shopId,
    selectedColor,
    // Fee fields participate in value identity so a fee change re-emits the
    // cart/checkout state instead of being swallowed as "unchanged".
    hasDelivery,
    deliveryPrice,
    maxDeliveryFee,
    hasInstallation,
    installationPrice,
  ];
}

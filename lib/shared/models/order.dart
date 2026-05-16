import 'package:equatable/equatable.dart';

import 'address.dart';
import 'multilingual_text.dart';
import 'order_status.dart';
import 'region.dart';
import 'shop.dart';
import 'shop_service.dart';

class OrderItem extends Equatable {
  const OrderItem({
    required this.productId,
    required this.productSlug,
    required this.productName,
    required this.thumbnail,
    required this.unitPrice,
    required this.quantity,
    this.selectedServices = const [],
  });

  final String productId;
  final String productSlug;
  final MultilingualText productName;
  final String thumbnail;
  final num unitPrice;
  final int quantity;
  final List<ShopService> selectedServices;

  num get lineTotal => unitPrice * quantity;

  /// Maps a `public.order_items` row. `product_name` is stored as a plain
  /// text snapshot of the name at order time; absent columns degrade to
  /// empty defaults so a partial row can't crash the list.
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'] as String? ?? '',
      productSlug: json['product_slug'] as String? ?? '',
      productName: MultilingualText(uz: json['product_name'] as String? ?? ''),
      thumbnail: json['thumbnail'] as String? ?? '',
      unitPrice: (json['unit_price'] as num?) ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_slug': productSlug,
        'product_name': productName.uz,
        'thumbnail': thumbnail,
        'unit_price': unitPrice,
        'quantity': quantity,
      };

  @override
  List<Object?> get props =>
      [productId, unitPrice, quantity, selectedServices.length];
}

enum OrderPaymentMethod {
  cashOnDelivery('cash_on_delivery'),
  card('card');

  const OrderPaymentMethod(this.code);
  final String code;

  static OrderPaymentMethod fromCode(String? code) {
    return OrderPaymentMethod.values.firstWhere(
      (m) => m.code == code,
      orElse: () => OrderPaymentMethod.cashOnDelivery,
    );
  }
}

enum OrderDeliveryMethod {
  delivery('delivery'),
  expressDelivery('express_delivery'),
  pickup('pickup');

  const OrderDeliveryMethod(this.code);
  final String code;

  static OrderDeliveryMethod fromCode(String code) {
    return OrderDeliveryMethod.values.firstWhere(
      (m) => m.code == code,
      orElse: () => OrderDeliveryMethod.delivery,
    );
  }
}

class OrderStatusEvent extends Equatable {
  const OrderStatusEvent({
    required this.status,
    required this.timestamp,
    this.note,
  });

  final OrderStatus status;
  final DateTime timestamp;
  final String? note;

  @override
  List<Object?> get props => [status, timestamp];
}

class Order extends Equatable {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.shop,
    required this.items,
    required this.address,
    required this.deliveryMethod,
    required this.paymentMethod,
    required this.status,
    required this.itemsTotal,
    required this.deliveryFee,
    required this.servicesFee,
    required this.grandTotal,
    required this.createdAt,
    required this.timeline,
    this.cancelReason,
    this.expectedDeliveryAt,
  });

  final String id;
  final String orderNumber;
  final Shop shop;
  final List<OrderItem> items;
  final Address address;
  final OrderDeliveryMethod deliveryMethod;
  final OrderPaymentMethod paymentMethod;
  final OrderStatus status;
  final num itemsTotal;
  final num deliveryFee;
  final num servicesFee;
  final num grandTotal;
  final DateTime createdAt;
  final List<OrderStatusEvent> timeline;
  final String? cancelReason;
  final DateTime? expectedDeliveryAt;

  /// Maps a `public.orders` row. Sub-aggregates that live in other tables
  /// ([items], [timeline]) or are not part of the seller order schema
  /// ([shop], [address]) are supplied by the repository — the repo fetches
  /// `order_items` separately and passes a placeholder shop/address for the
  /// seller-side views, which never render the shop card.
  factory Order.fromJson(
    Map<String, dynamic> json, {
    List<OrderItem> items = const [],
    List<OrderStatusEvent> timeline = const [],
    Shop? shop,
    Address? address,
  }) {
    final id = json['id'] as String? ?? '';
    return Order(
      id: id,
      orderNumber: (json['order_number'] as String?) ?? _deriveOrderNumber(id),
      shop: shop ?? _placeholderShop,
      items: items,
      address: address ?? _placeholderAddress,
      deliveryMethod:
          OrderDeliveryMethod.fromCode(json['delivery_method'] as String? ?? ''),
      paymentMethod: OrderPaymentMethod.fromCode(json['payment_method'] as String?),
      status: OrderStatus.fromCode(json['status'] as String?),
      itemsTotal: (json['items_total'] as num?) ?? 0,
      deliveryFee: (json['delivery_fee'] as num?) ?? 0,
      servicesFee: (json['services_fee'] as num?) ?? 0,
      grandTotal: (json['total_amount'] as num?) ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      timeline: timeline,
      cancelReason: json['cancel_reason'] as String?,
      expectedDeliveryAt: _parseDateOrNull(json['expected_delivery_at']),
    );
  }

  /// Serialises the scalar `orders`-table columns. Sub-aggregates are written
  /// to their own tables, so they are intentionally omitted here.
  Map<String, dynamic> toJson() => {
        'id': id,
        'order_number': orderNumber,
        'status': status.code,
        'items_total': itemsTotal,
        'delivery_fee': deliveryFee,
        'services_fee': servicesFee,
        'total_amount': grandTotal,
        'delivery_method': deliveryMethod.code,
        'payment_method': paymentMethod.code,
        'created_at': createdAt.toIso8601String(),
        if (cancelReason != null) 'cancel_reason': cancelReason,
        if (expectedDeliveryAt != null)
          'expected_delivery_at': expectedDeliveryAt!.toIso8601String(),
      };

  Order copyWith({
    OrderStatus? status,
    String? cancelReason,
    List<OrderStatusEvent>? timeline,
  }) {
    return Order(
      id: id,
      orderNumber: orderNumber,
      shop: shop,
      items: items,
      address: address,
      deliveryMethod: deliveryMethod,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      itemsTotal: itemsTotal,
      deliveryFee: deliveryFee,
      servicesFee: servicesFee,
      grandTotal: grandTotal,
      createdAt: createdAt,
      timeline: timeline ?? this.timeline,
      cancelReason: cancelReason ?? this.cancelReason,
      expectedDeliveryAt: expectedDeliveryAt,
    );
  }

  @override
  List<Object?> get props => [id, status, timeline.length];
}

// Placeholders for the sub-aggregates a seller `orders` row doesn't carry.
// The seller order list/detail views render customer + items + payment, never
// the shop card, so a placeholder shop is harmless there.
const _placeholderShop = Shop(
  id: '_',
  slug: '_',
  name: MultilingualText(uz: "Do'kon", ru: 'Магазин', en: 'Shop'),
);

const _placeholderRegion = Region(id: '_', code: '_', name: MultilingualText());

const _placeholderAddress = Address(
  id: '_',
  label: '',
  recipientName: '',
  phone: '',
  region: _placeholderRegion,
  city: _placeholderRegion,
  streetLine: '',
);

/// Synthesises a human-readable order number from the row id when the
/// `order_number` column is absent (mirrors the dashboard repo's convention).
String _deriveOrderNumber(String id) {
  final stub = id.length >= 8 ? id.substring(0, 8) : id;
  return 'M-${stub.toUpperCase()}';
}

DateTime? _parseDateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

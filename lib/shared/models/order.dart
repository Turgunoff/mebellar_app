import 'package:equatable/equatable.dart';

import 'address.dart';
import 'multilingual_text.dart';
import 'order_status.dart';
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

  @override
  List<Object?> get props =>
      [productId, unitPrice, quantity, selectedServices.length];
}

enum OrderPaymentMethod {
  cashOnDelivery('cash_on_delivery'),
  card('card');

  const OrderPaymentMethod(this.code);
  final String code;
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

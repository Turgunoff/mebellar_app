import '../models/address.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import 'mock_data.dart';
import 'mock_regions.dart';

/// Seed data for the mock OrderRepository / AddressRepository. Two addresses
/// (one default), three orders across distinct lifecycle stages so the
/// orders list tabs (active / completed / cancelled) all have something to
/// render on first launch.
class MockOrdersData {
  const MockOrdersData._();

  static final tashkentCity = MockRegions.tree
      .firstWhere((r) => r.id == 'reg-tashkent-city');
  static final chilanzar =
      tashkentCity.children.firstWhere((r) => r.id == 'reg-tsh-chilanzar');
  static final yashnobod =
      tashkentCity.children.firstWhere((r) => r.id == 'reg-tsh-yashnobod');

  static final List<Address> addresses = [
    Address(
      id: 'addr-home',
      label: 'Uy',
      recipientName: 'Aziz Karimov',
      phone: '+998 90 123 45 67',
      region: tashkentCity,
      city: tashkentCity,
      district: chilanzar,
      streetLine: 'Bunyodkor 24',
      apartment: '15',
      lat: 41.2829,
      lng: 69.2167,
      isDefault: true,
    ),
    Address(
      id: 'addr-work',
      label: 'Ish',
      recipientName: 'Aziz Karimov',
      phone: '+998 90 123 45 67',
      region: tashkentCity,
      city: tashkentCity,
      district: yashnobod,
      streetLine: 'Mustaqillik 5A',
      apartment: 'Office 304',
      lat: 41.3111,
      lng: 69.2797,
    ),
  ];

  static final List<Order> orders = [
    _orderShipped(),
    _orderDelivered(),
    _orderCancelled(),
  ];

  static Order _orderShipped() {
    final shop =
        MockData.shops.firstWhere((s) => s.id == 'shop-mh');
    final products =
        MockData.products.where((p) => p.shop?.id == 'shop-mh').take(2).toList();
    final items = [
      OrderItem(
        productId: products[0].id,
        productSlug: products[0].slug,
        productName: products[0].name,
        thumbnail: products[0].heroImage,
        unitPrice: products[0].price,
        quantity: 1,
        selectedServices: products[0].shopServices.take(1).toList(),
      ),
      OrderItem(
        productId: products[1].id,
        productSlug: products[1].slug,
        productName: products[1].name,
        thumbnail: products[1].heroImage,
        unitPrice: products[1].price,
        quantity: 2,
      ),
    ];
    final itemsTotal =
        items.fold<num>(0, (sum, it) => sum + it.lineTotal);
    final now = DateTime.now();
    return Order(
      id: 'ord-1001',
      orderNumber: 'M-2026-001',
      shop: shop,
      items: items,
      address: addresses.first,
      deliveryMethod: OrderDeliveryMethod.delivery,
      paymentMethod: OrderPaymentMethod.cashOnDelivery,
      status: OrderStatus.shipped,
      itemsTotal: itemsTotal,
      deliveryFee: 50000,
      servicesFee: 0,
      grandTotal: itemsTotal + 50000,
      createdAt: now.subtract(const Duration(days: 2)),
      expectedDeliveryAt: now.add(const Duration(days: 1)),
      timeline: [
        OrderStatusEvent(
          status: OrderStatus.pending,
          timestamp: now.subtract(const Duration(days: 2)),
        ),
        OrderStatusEvent(
          status: OrderStatus.confirmed,
          timestamp: now.subtract(
              const Duration(days: 2) - const Duration(hours: 1)),
        ),
        OrderStatusEvent(
          status: OrderStatus.preparing,
          timestamp: now.subtract(const Duration(days: 1)),
        ),
        OrderStatusEvent(
          status: OrderStatus.shipped,
          timestamp: now.subtract(const Duration(hours: 6)),
        ),
      ],
    );
  }

  static Order _orderDelivered() {
    final shop = MockData.shops.firstWhere((s) => s.id == 'shop-rm');
    final product =
        MockData.products.firstWhere((p) => p.shop?.id == 'shop-rm');
    final items = [
      OrderItem(
        productId: product.id,
        productSlug: product.slug,
        productName: product.name,
        thumbnail: product.heroImage,
        unitPrice: product.price,
        quantity: 1,
      ),
    ];
    final itemsTotal = items.fold<num>(0, (sum, it) => sum + it.lineTotal);
    final created = DateTime.now().subtract(const Duration(days: 14));
    return Order(
      id: 'ord-1002',
      orderNumber: 'M-2026-002',
      shop: shop,
      items: items,
      address: addresses.first,
      deliveryMethod: OrderDeliveryMethod.delivery,
      paymentMethod: OrderPaymentMethod.cashOnDelivery,
      status: OrderStatus.delivered,
      itemsTotal: itemsTotal,
      deliveryFee: 0,
      servicesFee: 0,
      grandTotal: itemsTotal,
      createdAt: created,
      timeline: [
        OrderStatusEvent(
            status: OrderStatus.pending, timestamp: created),
        OrderStatusEvent(
          status: OrderStatus.confirmed,
          timestamp: created.add(const Duration(hours: 2)),
        ),
        OrderStatusEvent(
          status: OrderStatus.preparing,
          timestamp: created.add(const Duration(days: 1)),
        ),
        OrderStatusEvent(
          status: OrderStatus.shipped,
          timestamp: created.add(const Duration(days: 3)),
        ),
        OrderStatusEvent(
          status: OrderStatus.delivered,
          timestamp: created.add(const Duration(days: 5)),
        ),
      ],
    );
  }

  static Order _orderCancelled() {
    final shop = MockData.shops.firstWhere((s) => s.id == 'shop-ch');
    final product =
        MockData.products.firstWhere((p) => p.shop?.id == 'shop-ch');
    final items = [
      OrderItem(
        productId: product.id,
        productSlug: product.slug,
        productName: product.name,
        thumbnail: product.heroImage,
        unitPrice: product.price,
        quantity: 1,
      ),
    ];
    final itemsTotal = items.fold<num>(0, (sum, it) => sum + it.lineTotal);
    final created = DateTime.now().subtract(const Duration(days: 21));
    return Order(
      id: 'ord-1003',
      orderNumber: 'M-2026-003',
      shop: shop,
      items: items,
      address: addresses[1],
      deliveryMethod: OrderDeliveryMethod.pickup,
      paymentMethod: OrderPaymentMethod.cashOnDelivery,
      status: OrderStatus.cancelled,
      itemsTotal: itemsTotal,
      deliveryFee: 0,
      servicesFee: 0,
      grandTotal: itemsTotal,
      createdAt: created,
      cancelReason: 'Mahsulot omborda mavjud emas',
      timeline: [
        OrderStatusEvent(
            status: OrderStatus.pending, timestamp: created),
        OrderStatusEvent(
          status: OrderStatus.cancelled,
          timestamp: created.add(const Duration(hours: 4)),
          note: 'Mahsulot omborda mavjud emas',
        ),
      ],
    );
  }
}

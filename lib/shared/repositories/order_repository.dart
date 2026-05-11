import 'package:dio/dio.dart';

import '../models/address.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/shop.dart';

class CreateOrderInput {
  CreateOrderInput({
    required this.shop,
    required this.items,
    required this.address,
    required this.deliveryMethod,
    required this.paymentMethod,
    this.note,
  });

  final Shop shop;
  final List<CartItem> items;
  final Address address;
  final OrderDeliveryMethod deliveryMethod;
  final OrderPaymentMethod paymentMethod;
  final String? note;
}

abstract class OrderRepository {
  Future<List<Order>> list();
  Future<Order> getById(String id);

  /// Single-shop order. `CheckoutBloc` calls this once per shop group from
  /// the cart so multi-shop carts result in N orders.
  Future<Order> create(CreateOrderInput input);
  Future<Order> cancel(String id, {required String reason});

  /// Stream that yields the latest version of [orderId] when the backend
  /// reports a status change. The mock variant simulates progression every
  /// few seconds; real impl will subscribe to a Supabase realtime channel.
  Stream<Order> watch(String orderId);
}

class RemoteOrderRepository implements OrderRepository {
  RemoteOrderRepository(this._dio);
  // ignore: unused_field — Sprint 5 backend wires real endpoints in
  final Dio _dio;

  @override
  Future<List<Order>> list() async {
    throw UnimplementedError('Remote orders — Sprint 5 backend');
  }

  @override
  Future<Order> getById(String id) async {
    throw UnimplementedError('Remote order detail — Sprint 5 backend');
  }

  @override
  Future<Order> create(CreateOrderInput input) async {
    throw UnimplementedError('Remote order create — Sprint 5 backend');
  }

  @override
  Future<Order> cancel(String id, {required String reason}) async {
    throw UnimplementedError('Remote order cancel — Sprint 5 backend');
  }

  @override
  Stream<Order> watch(String orderId) async* {
    // Backed by Supabase realtime channel in production.
    return;
  }
}

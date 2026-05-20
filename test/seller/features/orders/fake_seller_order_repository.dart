import 'dart:async';

import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/models/order_status.dart';
import 'package:woody_app/shared/repositories/seller_order_repository.dart';

/// Test double for `SellerOrderRepository` with deterministic behavior.
///
/// Unlike the in-memory mock, every dependency the bloc cares about
/// (list result, realtime stream, transition handlers) is set or driven
/// by the test — no timers, no seeded data, no delays. Lets us pin down
/// exactly which `Result` the bloc sees for each call.
class FakeSellerOrderRepository implements SellerOrderRepository {
  FakeSellerOrderRepository({
    Result<List<Order>>? listResult,
    Result<Order> Function(String id)? getByIdResult,
  })  : _listResult = listResult ?? const Ok<List<Order>>(<Order>[]),
        _getByIdResult = getByIdResult;

  Result<List<Order>> _listResult;
  Result<Order> Function(String id)? _getByIdResult;

  final _newOrdersCtrl = StreamController<Order>.broadcast();
  final _updatesCtrl = StreamController<Order>.broadcast();
  final _watchCtrls = <String, StreamController<Order>>{};

  int listCalls = 0;
  int confirmCalls = 0;
  int cancelCalls = 0;
  final List<String> transitionLog = [];

  /// Mutator the tests use to swap the `list()` outcome between calls.
  set listResult(Result<List<Order>> value) => _listResult = value;

  /// Mutator for `getById()`.
  set getByIdResult(Result<Order> Function(String id) builder) =>
      _getByIdResult = builder;

  /// Push a synthetic new-order event from the test side.
  void emitNewOrder(Order order) => _newOrdersCtrl.add(order);

  /// Push a synthetic update event (status flip, customer cancel, etc.).
  void emitOrderUpdate(Order order) {
    _updatesCtrl.add(order);
    _watchCtrls[order.id]?.add(order);
  }

  @override
  Future<Result<List<Order>>> list() async {
    listCalls += 1;
    return _listResult;
  }

  @override
  Future<Result<Order>> getById(String id) async {
    final builder = _getByIdResult;
    if (builder == null) {
      return const Err(ServerFailure(message: 'getById not stubbed'));
    }
    return builder(id);
  }

  @override
  Stream<Order> newOrders() => _newOrdersCtrl.stream;

  @override
  Stream<Order> orderUpdates() => _updatesCtrl.stream;

  @override
  Stream<Order> watch(String orderId) {
    final ctrl = _watchCtrls.putIfAbsent(
      orderId,
      () => StreamController<Order>.broadcast(),
    );
    return ctrl.stream;
  }

  @override
  Future<Result<Order>> confirm(String id) =>
      _transition(id, OrderStatus.confirmed, label: 'confirm', counter: () {
        confirmCalls += 1;
      });

  @override
  Future<Result<Order>> markPreparing(String id) =>
      _transition(id, OrderStatus.preparing, label: 'preparing');

  @override
  Future<Result<Order>> markShipped(String id) =>
      _transition(id, OrderStatus.shipped, label: 'shipped');

  @override
  Future<Result<Order>> markDelivered(String id) =>
      _transition(id, OrderStatus.delivered, label: 'delivered');

  @override
  Future<Result<Order>> cancel(String id, {required String reason}) async {
    cancelCalls += 1;
    transitionLog.add('cancel:$id:$reason');
    final builder = _getByIdResult;
    if (builder == null) {
      return const Err(ServerFailure(message: 'cancel: no stub'));
    }
    return builder(id).map(
      (order) => order.copyWith(status: OrderStatus.cancelled, cancelReason: reason),
    );
  }

  Future<Result<Order>> _transition(
    String id,
    OrderStatus next, {
    required String label,
    void Function()? counter,
  }) async {
    counter?.call();
    transitionLog.add('$label:$id');
    final builder = _getByIdResult;
    if (builder == null) {
      return Err(ServerFailure(message: '$label: no stub'));
    }
    return builder(id).map((order) => order.copyWith(status: next));
  }

  @override
  Future<void> dispose() async {
    if (!_newOrdersCtrl.isClosed) await _newOrdersCtrl.close();
    if (!_updatesCtrl.isClosed) await _updatesCtrl.close();
    for (final c in _watchCtrls.values) {
      if (!c.isClosed) await c.close();
    }
    _watchCtrls.clear();
  }
}

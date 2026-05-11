import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/address.dart';
import '../../../../shared/models/cart.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/repositories/address_repository.dart';
import '../../../../shared/repositories/cart_repository.dart';
import '../../../../shared/repositories/order_repository.dart';

enum CheckoutStep {
  review,
  address,
  delivery,
  payment,
  confirm;

  static const total = 5;
}

class ShopSubmissionResult extends Equatable {
  const ShopSubmissionResult({
    required this.shopId,
    required this.shopName,
    this.order,
    this.error,
  });

  final String shopId;
  final String shopName;
  final Order? order;
  final String? error;

  bool get success => order != null;

  @override
  List<Object?> get props => [shopId, order?.id, error];
}

sealed class CheckoutEvent extends Equatable {
  const CheckoutEvent();
  @override
  List<Object?> get props => const [];
}

class CheckoutStarted extends CheckoutEvent {
  const CheckoutStarted(this.cart);
  final Cart cart;
  @override
  List<Object?> get props => [cart];
}

class CheckoutNextStep extends CheckoutEvent {
  const CheckoutNextStep();
}

class CheckoutPreviousStep extends CheckoutEvent {
  const CheckoutPreviousStep();
}

class CheckoutAddressSelected extends CheckoutEvent {
  const CheckoutAddressSelected(this.address);
  final Address address;
  @override
  List<Object?> get props => [address.id];
}

class CheckoutDeliveryMethodSelected extends CheckoutEvent {
  const CheckoutDeliveryMethodSelected({
    required this.shopId,
    required this.method,
  });
  final String shopId;
  final OrderDeliveryMethod method;
  @override
  List<Object?> get props => [shopId, method];
}

class CheckoutPaymentSelected extends CheckoutEvent {
  const CheckoutPaymentSelected(this.method);
  final OrderPaymentMethod method;
  @override
  List<Object?> get props => [method];
}

class CheckoutSubmitted extends CheckoutEvent {
  const CheckoutSubmitted();
}

enum CheckoutStatus { editing, submitting, success, partialFailure, failure }

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.editing,
    this.step = CheckoutStep.review,
    this.cart = const Cart(),
    this.address,
    this.deliveryByShop = const {},
    this.paymentMethod = OrderPaymentMethod.cashOnDelivery,
    this.results = const [],
    this.error,
  });

  final CheckoutStatus status;
  final CheckoutStep step;
  final Cart cart;
  final Address? address;
  final Map<String, OrderDeliveryMethod> deliveryByShop;
  final OrderPaymentMethod paymentMethod;
  final List<ShopSubmissionResult> results;
  final String? error;

  bool get hasAddress => address != null;
  bool get allShopsHaveDelivery {
    final groups = cart.groupByShop();
    return groups.every((g) => deliveryByShop.containsKey(g.shop.id));
  }

  bool canAdvanceFrom(CheckoutStep s) {
    return switch (s) {
      CheckoutStep.review => cart.isNotEmpty,
      CheckoutStep.address => hasAddress,
      CheckoutStep.delivery => allShopsHaveDelivery,
      CheckoutStep.payment => true,
      CheckoutStep.confirm => false,
    };
  }

  num get deliveryFeeTotal {
    num total = 0;
    for (final group in cart.groupByShop()) {
      final method = deliveryByShop[group.shop.id];
      if (method == null) continue;
      total += switch (method) {
        OrderDeliveryMethod.delivery => 50000,
        OrderDeliveryMethod.expressDelivery => 80000,
        OrderDeliveryMethod.pickup => 0,
      };
    }
    return total;
  }

  num get grandTotal => cart.grandTotal + deliveryFeeTotal;

  CheckoutState copyWith({
    CheckoutStatus? status,
    CheckoutStep? step,
    Cart? cart,
    Address? address,
    Map<String, OrderDeliveryMethod>? deliveryByShop,
    OrderPaymentMethod? paymentMethod,
    List<ShopSubmissionResult>? results,
    String? error,
    bool clearError = false,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      step: step ?? this.step,
      cart: cart ?? this.cart,
      address: address ?? this.address,
      deliveryByShop: deliveryByShop ?? this.deliveryByShop,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      results: results ?? this.results,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        step,
        cart,
        address?.id,
        deliveryByShop,
        paymentMethod,
        results,
        error,
      ];
}

class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  CheckoutBloc({
    required OrderRepository orderRepo,
    required AddressRepository addressRepo,
    required CartRepository cartRepo,
  })  : _orderRepo = orderRepo,
        _addressRepo = addressRepo,
        _cartRepo = cartRepo,
        super(const CheckoutState()) {
    on<CheckoutStarted>(_onStarted);
    on<CheckoutNextStep>(_onNext);
    on<CheckoutPreviousStep>(_onPrev);
    on<CheckoutAddressSelected>(
        (e, emit) => emit(state.copyWith(address: e.address)));
    on<CheckoutDeliveryMethodSelected>(_onDeliveryChanged);
    on<CheckoutPaymentSelected>(
        (e, emit) => emit(state.copyWith(paymentMethod: e.method)));
    on<CheckoutSubmitted>(_onSubmitted);
  }

  final OrderRepository _orderRepo;
  final AddressRepository _addressRepo;
  final CartRepository _cartRepo;

  Future<void> _onStarted(
    CheckoutStarted event,
    Emitter<CheckoutState> emit,
  ) async {
    // Default delivery picks `delivery` for every shop so the UI doesn't
    // start with the next button disabled. User can switch to pickup or
    // express on the delivery step.
    final deliveryByShop = <String, OrderDeliveryMethod>{
      for (final group in event.cart.groupByShop())
        group.shop.id: OrderDeliveryMethod.delivery,
    };
    emit(state.copyWith(
      cart: event.cart,
      deliveryByShop: deliveryByShop,
      step: CheckoutStep.review,
      status: CheckoutStatus.editing,
      clearError: true,
    ));
    // Pre-fill default address if the user has any saved.
    try {
      final addresses = await _addressRepo.list();
      final defaultAddr = addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => addresses.isNotEmpty ? addresses.first : throw _NoAddr(),
      );
      emit(state.copyWith(address: defaultAddr));
    } on _NoAddr catch (_) {
      // No addresses yet; user picks/creates one on step 2.
    } catch (_) {
      // Non-fatal — UI lets user pick one.
    }
  }

  void _onNext(CheckoutNextStep event, Emitter<CheckoutState> emit) {
    if (!state.canAdvanceFrom(state.step)) return;
    final nextIdx = state.step.index + 1;
    if (nextIdx >= CheckoutStep.total) return;
    emit(state.copyWith(
      step: CheckoutStep.values[nextIdx],
      clearError: true,
    ));
  }

  void _onPrev(CheckoutPreviousStep event, Emitter<CheckoutState> emit) {
    final prevIdx = state.step.index - 1;
    if (prevIdx < 0) return;
    emit(state.copyWith(step: CheckoutStep.values[prevIdx]));
  }

  void _onDeliveryChanged(
    CheckoutDeliveryMethodSelected event,
    Emitter<CheckoutState> emit,
  ) {
    final next = Map<String, OrderDeliveryMethod>.from(state.deliveryByShop);
    next[event.shopId] = event.method;
    emit(state.copyWith(deliveryByShop: next));
  }

  /// Multi-shop split: one POST /orders per shop group. We collect successes
  /// and failures separately so the success path doesn't get rolled back when
  /// a sibling shop fails (the pattern docs Sprint 5 mandates).
  Future<void> _onSubmitted(
    CheckoutSubmitted event,
    Emitter<CheckoutState> emit,
  ) async {
    final address = state.address;
    if (address == null) return;
    emit(state.copyWith(
      status: CheckoutStatus.submitting,
      results: const [],
      clearError: true,
    ));
    final results = <ShopSubmissionResult>[];
    for (final group in state.cart.groupByShop()) {
      final method = state.deliveryByShop[group.shop.id] ??
          OrderDeliveryMethod.delivery;
      try {
        final order = await _orderRepo.create(CreateOrderInput(
          shop: group.shop,
          items: group.items,
          address: address,
          deliveryMethod: method,
          paymentMethod: state.paymentMethod,
        ));
        results.add(ShopSubmissionResult(
          shopId: group.shop.id,
          shopName: group.shop.slug,
          order: order,
        ));
      } catch (e) {
        results.add(ShopSubmissionResult(
          shopId: group.shop.id,
          shopName: group.shop.slug,
          error: e.toString(),
        ));
      }
    }
    final anySuccess = results.any((r) => r.success);
    final anyFailure = results.any((r) => !r.success);

    // Clear cart items only for shops whose order succeeded; failed ones stay
    // in the cart so the user can retry without re-adding products.
    if (anySuccess) {
      final successfulShopIds =
          results.where((r) => r.success).map((r) => r.shopId).toSet();
      final remainingItems = state.cart.items
          .where((it) => !successfulShopIds.contains(it.product.shop?.id))
          .toList();
      if (remainingItems.isEmpty) {
        await _cartRepo.clear();
      } else {
        // Repository doesn't expose a "remove by shop" — drop one by one.
        final toRemove = state.cart.items
            .where((it) => successfulShopIds.contains(it.product.shop?.id))
            .toList();
        for (final it in toRemove) {
          try {
            await _cartRepo.removeItem(it.id);
          } catch (_) {
            // Best-effort cleanup; cart will reconcile on next fetch.
          }
        }
      }
    }
    final status = anyFailure && anySuccess
        ? CheckoutStatus.partialFailure
        : (anySuccess ? CheckoutStatus.success : CheckoutStatus.failure);
    emit(state.copyWith(status: status, results: results));
  }
}

class _NoAddr implements Exception {}

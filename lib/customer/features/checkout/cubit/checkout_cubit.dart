import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../shared/models/cart_item_model.dart';
import '../../../../shared/repositories/cart_repository.dart';
import '../../../../shared/repositories/checkout_repository.dart';

enum CheckoutPayment { cash, card }

enum CheckoutStatus { idle, submitting, success, failure }

/// A group of cart items that belong to the same shop. Each group results in
/// one `orders` row so the seller sees only their own items.
class ShopOrderGroup extends Equatable {
  const ShopOrderGroup({
    required this.shopId,
    required this.shopName,
    required this.items,
  });

  /// Empty string when shop info is unknown (old snapshot without shop_id).
  final String shopId;
  final String shopName;
  final List<CartItemModel> items;

  double get subtotal => items.fold(0.0, (s, it) => s + it.lineTotal);

  /// Delivery fee for this shop group (sum of per-line delivery fees).
  double get deliveryFee => items.fold(0.0, (s, it) => s + it.deliveryFee);

  /// Full installation fee for this shop group if the customer opts in.
  double get installationFee =>
      items.fold(0.0, (s, it) => s + it.installationFee);

  @override
  List<Object?> get props => [shopId, items];
}

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.groups = const [],
    this.payment = CheckoutPayment.cash,
    this.deliveryAddress = '',
    this.placedOrderIds = const [],
    this.wantsInstallation = false,
    this.quote,
    this.error,
  });

  final CheckoutStatus status;
  final List<ShopOrderGroup> groups;
  final CheckoutPayment payment;
  final String deliveryAddress;

  /// Order IDs created during [submit] — populated on success.
  final List<String> placedOrderIds;

  /// Whether the customer toggled "Ustamiz o'rnatib berishini xohlaysizmi?".
  final bool wantsInstallation;

  /// The latest server invoice (`POST /orders/quote`). Null until it returns —
  /// the getters fall back to a local estimate computed from the cart items so
  /// the card paints instantly.
  final CheckoutQuote? quote;

  final String? error;

  bool get hasAddress => deliveryAddress.trim().isNotEmpty;

  double get subtotal => groups.fold(0.0, (s, g) => s + g.subtotal);

  // Local fallbacks from the cart-item snapshots, used until the server quote
  // arrives (and if it never does — graceful degrade).
  double get _deliveryFeeLocal => groups.fold(0.0, (s, g) => s + g.deliveryFee);
  double get _installationFeeLocal =>
      groups.fold(0.0, (s, g) => s + g.installationFee);

  /// Authoritative delivery fee (server quote) or the local estimate.
  double get deliveryFee => quote?.deliveryFee ?? _deliveryFeeLocal;

  /// Full installation fee available for the cart — independent of the toggle,
  /// so flipping the switch adds/removes it with no refetch.
  double get installationFee => quote?.installationFee ?? _installationFeeLocal;

  /// Whether any item offers installation (so the switch should be shown).
  bool get installationAvailable =>
      quote?.installationAvailable ?? (_installationFeeLocal > 0);

  /// Whether the delivery fee shown is authoritative — every line's product
  /// prices its own delivery (even when that price is 0 = free). When false,
  /// no product pre-prices delivery, so the seller proposes it after the order
  /// is placed and the invoice shows "Sotuvchi belgilaydi" rather than a
  /// misleading "Tekin".
  bool get deliveryPriced =>
      groups.isNotEmpty && allItems.every((it) => it.hasDelivery);

  /// Instantly recomputed: subtotal + delivery + (installation if opted in).
  double get grandTotal =>
      subtotal + deliveryFee + (wantsInstallation ? installationFee : 0);

  List<CartItemModel> get allItems => [for (final g in groups) ...g.items];

  CheckoutState copyWith({
    CheckoutStatus? status,
    List<ShopOrderGroup>? groups,
    CheckoutPayment? payment,
    String? deliveryAddress,
    List<String>? placedOrderIds,
    bool? wantsInstallation,
    CheckoutQuote? quote,
    String? error,
    bool clearError = false,
  }) => CheckoutState(
    status: status ?? this.status,
    groups: groups ?? this.groups,
    payment: payment ?? this.payment,
    deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    placedOrderIds: placedOrderIds ?? this.placedOrderIds,
    wantsInstallation: wantsInstallation ?? this.wantsInstallation,
    quote: quote ?? this.quote,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    status,
    groups,
    payment,
    deliveryAddress,
    placedOrderIds,
    wantsInstallation,
    quote,
    error,
  ];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required List<CartItemModel> items,
    required CheckoutRepository checkout,
    required CartRepository cartRepo,
    AnalyticsService? analytics,
  }) : _checkout = checkout,
       _cartRepo = cartRepo,
       _analytics = analytics,
       super(CheckoutState(groups: _groupByShop(items))) {
    // Funnel start — one event per checkout session, regardless of how
    // many shops the cart spans. Per-shop conversion is logged in submit.
    final total = state.groups.fold<double>(
      0,
      (sum, g) => sum + g.subtotal.toDouble(),
    );
    unawaited(
      _analytics?.beginCheckout(value: total, itemsCount: items.length),
    );
    // Pull the authoritative invoice (delivery + installation) from the server.
    // The card already shows a local estimate from the cart snapshots, so this
    // only refines the numbers when it returns.
    unawaited(_refreshQuote());
  }

  final CheckoutRepository _checkout;
  final CartRepository _cartRepo;
  final AnalyticsService? _analytics;

  void selectPayment(CheckoutPayment payment) {
    emit(state.copyWith(payment: payment));
    unawaited(_analytics?.paymentInfoAdded(paymentType: payment.name));
  }

  void updateAddress(String address) {
    final trimmed = address.trim();
    emit(state.copyWith(deliveryAddress: trimmed));
    if (trimmed.isNotEmpty) {
      unawaited(_analytics?.shippingInfoAdded());
    }
    // Delivery fee may depend on the address server-side — re-quote.
    unawaited(_refreshQuote());
  }

  /// Toggles the installation opt-in. The grand total recomputes instantly via
  /// [CheckoutState.grandTotal] (the installation fee is already known), so no
  /// network round-trip is needed.
  void toggleInstallation(bool value) {
    emit(state.copyWith(wantsInstallation: value));
  }

  /// Fetches the server-computed invoice and merges it into the state. Failures
  /// are swallowed: the local estimate stays on screen and the order is priced
  /// server-side at submit time regardless.
  Future<void> _refreshQuote() async {
    final items = state.allItems;
    if (items.isEmpty) return;
    try {
      final quote = await _checkout.quote(
        lines: [
          for (final it in items)
            CheckoutOrderLine(productId: it.productId, quantity: it.quantity),
        ],
        deliveryAddress: state.deliveryAddress,
        wantInstallation: state.wantsInstallation,
      );
      if (isClosed) return;
      emit(state.copyWith(quote: quote));
    } catch (_) {
      // Keep the local estimate; nothing to surface to the customer here.
    }
  }

  Future<void> submit(String userId) async {
    if (state.status == CheckoutStatus.submitting) return;
    emit(state.copyWith(status: CheckoutStatus.submitting, clearError: true));

    try {
      final placedIds = <String>[];

      for (final group in state.groups) {
        // One order per shop group → POST /orders. The backend resolves the
        // caller from the JWT and computes the authoritative total from product
        // prices (so total_amount/price/status aren't client-supplied). Per-item
        // colour isn't persisted on the Woody order yet — a known limitation.
        final orderId = await _checkout.placeOrder(
          lines: [
            for (final it in group.items)
              CheckoutOrderLine(productId: it.productId, quantity: it.quantity),
          ],
          deliveryAddress: state.deliveryAddress,
          wantInstallation: state.wantsInstallation,
        );
        placedIds.add(orderId);

        // Per-shop purchase event — Firebase counts each as one conversion
        // so a 2-shop cart shows up as 2 rows in the dashboard, matching
        // how the shops are billed and fulfilled separately.
        unawaited(
          _analytics?.purchased(
            transactionId: orderId,
            value: group.subtotal.toDouble(),
            itemsCount: group.items.length,
          ),
        );
      }

      await _cartRepo.clear();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CheckoutStatus.success,
          placedOrderIds: placedIds,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  /// Groups items by [CartItemModel.shopId]. Items without a shopId are
  /// pooled under key `''` so they still produce a valid order.
  static List<ShopOrderGroup> _groupByShop(List<CartItemModel> items) {
    final map = <String, List<CartItemModel>>{};
    for (final item in items) {
      final key = item.shopId ?? '';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map.entries
        .map((e) {
          final name = e.value.first.shopName ?? '';
          return ShopOrderGroup(shopId: e.key, shopName: name, items: e.value);
        })
        .toList(growable: false);
  }
}

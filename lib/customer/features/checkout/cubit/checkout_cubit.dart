import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/result/result.dart';
import '../../../../core/services/facebook_analytics_service.dart';
import '../../../../shared/models/cart_item_model.dart';
import '../../../../shared/repositories/cart_repository.dart';
import '../../../../shared/repositories/checkout_repository.dart';
import '../../../../shared/repositories/payment_repository.dart';

/// How the customer pays. `payme` / `click` mint a checkout deep-link the app
/// opens after the order is placed; `cash` is COD (no link).
///
/// Online checkout is **deferred**: place-order only stores the method. The
/// Payme/Click deep-link is minted later from order detail once status is
/// `awaiting_payment` (see [PaymentRepository.checkoutUrl]).
enum CheckoutPayment { cash, payme, click }

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

  /// Whether every line offers delivery with a fixed checkout price (> 0).
  bool get deliveryFixedPriced =>
      items.isNotEmpty &&
      items.every((it) => it.hasDelivery && it.deliveryPrice > 0);

  /// Seller sets the exact fee after reviewing the address (has_delivery but no
  /// fixed delivery_price).
  bool get deliveryDeferred =>
      items.isNotEmpty &&
      items.every((it) => it.hasDelivery && it.deliveryPrice <= 0);

  /// Max estimated delivery across lines (for the deferred "0 – max" hint).
  int get maxDeliveryFeeEstimate =>
      items.fold(0, (sum, it) => sum + it.maxDeliveryFee * it.quantity);

  @override
  List<Object?> get props => [shopId, items];
}

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.groups = const [],
    this.payment = CheckoutPayment.cash,
    this.checkoutUrl,
    this.deliveryAddress = '',
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.placedOrderIds = const [],
    this.installationByShop = const {},
    this.quotesByShop = const {},
    this.error,
  });

  final CheckoutStatus status;
  final List<ShopOrderGroup> groups;
  final CheckoutPayment payment;

  /// The checkout deep-link to open after a successful Payme/Click order. Null
  /// for cash, or until [CheckoutCubit.submit] mints it; the screen launches it
  /// externally.
  final String? checkoutUrl;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  /// Order IDs created during [submit] — populated on success.
  final List<String> placedOrderIds;

  /// Per-shop installation opt-in, keyed by [ShopOrderGroup.shopId]. A shop's
  /// "Ustamiz o'rnatib berishini xohlaysizmi?" switch flips only its own entry,
  /// so one seller's installation never bleeds into another's order total.
  /// Missing key = not opted in.
  final Map<String, bool> installationByShop;

  /// The latest server invoice per shop (`POST /orders/quote`, one call per
  /// shop — matching how each shop becomes its own order). Empty until the
  /// quotes return; the per-group getters fall back to a local estimate from
  /// the cart snapshots so each card paints instantly.
  final Map<String, CheckoutQuote> quotesByShop;

  final String? error;

  bool get hasAddress => deliveryAddress.trim().isNotEmpty;

  /// Whether any shop defers delivery pricing to the seller after checkout.
  bool get hasDeferredDelivery => groups.any((g) => g.deliveryDeferred);

  /// The order is ready to submit — every method only needs a delivery
  /// address (Payme/Click open their app after the order is placed).
  bool get canSubmit => hasAddress;

  /// The repository provider for the chosen method, or null for cash.
  PaymentProvider? get provider => switch (payment) {
    CheckoutPayment.payme => PaymentProvider.payme,
    CheckoutPayment.click => PaymentProvider.click,
    CheckoutPayment.cash => null,
  };

  // ── Per-shop fees (authoritative server quote or local snapshot estimate) ──
  // Each shop is priced independently because it becomes its own order; the
  // backend rejects a multi-shop order, so the aggregate is just the sum of
  // these per-shop figures — never a single blended invoice.

  /// Whether this shop's installation switch is on.
  bool wantsInstallationFor(String shopId) =>
      installationByShop[shopId] ?? false;

  /// This shop's authoritative delivery fee (its server quote) or the local
  /// estimate until the quote returns.
  double deliveryFeeFor(ShopOrderGroup g) =>
      quotesByShop[g.shopId]?.deliveryFee ?? g.deliveryFee;

  /// This shop's full available installation fee — independent of the switch,
  /// so flipping it adds/removes the amount with no refetch (the server quote
  /// always returns the potential amount).
  double installationFeeFor(ShopOrderGroup g) =>
      quotesByShop[g.shopId]?.installationFee ?? g.installationFee;

  /// Whether this shop offers installation (so its switch should be shown).
  bool installationAvailableFor(ShopOrderGroup g) =>
      quotesByShop[g.shopId]?.installationAvailable ?? (g.installationFee > 0);

  /// This shop's all-in order total: products + delivery + (installation if
  /// that shop opted in).
  double groupTotal(ShopOrderGroup g) =>
      g.subtotal +
      deliveryFeeFor(g) +
      (wantsInstallationFor(g.shopId) ? installationFeeFor(g) : 0);

  // ── Cart-wide aggregates (sum of the per-shop figures above) ───────────────

  double get subtotal => groups.fold(0.0, (s, g) => s + g.subtotal);

  /// Total delivery across every shop.
  double get deliveryFee => groups.fold(0.0, (s, g) => s + deliveryFeeFor(g));

  /// Total available installation across every shop (independent of toggles).
  double get installationFee =>
      groups.fold(0.0, (s, g) => s + installationFeeFor(g));

  /// Whether any shop offers installation.
  bool get installationAvailable =>
      groups.any((g) => installationAvailableFor(g));

  /// Grand total — the dynamic sum of each shop's all-in order total, so only
  /// the shops whose switch is on contribute their installation fee.
  double get grandTotal => groups.fold(0.0, (s, g) => s + groupTotal(g));

  List<CartItemModel> get allItems => [for (final g in groups) ...g.items];

  CheckoutState copyWith({
    CheckoutStatus? status,
    List<ShopOrderGroup>? groups,
    CheckoutPayment? payment,
    String? checkoutUrl,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    bool clearDeliveryCoordinates = false,
    List<String>? placedOrderIds,
    Map<String, bool>? installationByShop,
    Map<String, CheckoutQuote>? quotesByShop,
    String? error,
    bool clearError = false,
  }) => CheckoutState(
    status: status ?? this.status,
    groups: groups ?? this.groups,
    payment: payment ?? this.payment,
    checkoutUrl: checkoutUrl ?? this.checkoutUrl,
    deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    deliveryLatitude: clearDeliveryCoordinates
        ? null
        : (deliveryLatitude ?? this.deliveryLatitude),
    deliveryLongitude: clearDeliveryCoordinates
        ? null
        : (deliveryLongitude ?? this.deliveryLongitude),
    placedOrderIds: placedOrderIds ?? this.placedOrderIds,
    installationByShop: installationByShop ?? this.installationByShop,
    quotesByShop: quotesByShop ?? this.quotesByShop,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    status,
    groups,
    payment,
    checkoutUrl,
    deliveryAddress,
    deliveryLatitude,
    deliveryLongitude,
    placedOrderIds,
    installationByShop,
    quotesByShop,
    error,
  ];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required List<CartItemModel> items,
    required CheckoutRepository checkout,
    required CartRepository cartRepo,
    PaymentRepository? payments,
    AnalyticsService? analytics,
    FacebookAnalyticsService? facebookAnalytics,
  }) : _checkout = checkout,
       _cartRepo = cartRepo,
       _analytics = analytics,
       _facebookAnalytics = facebookAnalytics,
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
    // Meta InitiateCheckout — one event per checkout session, mirroring the
    // Firebase begin_checkout above.
    unawaited(
      _facebookAnalytics?.logInitiateCheckout(
        numItems: items.length,
        value: total,
      ),
    );
    // Pull the authoritative invoice (delivery + installation) from the server.
    // The card already shows a local estimate from the cart snapshots, so this
    // only refines the numbers when it returns.
    unawaited(_refreshQuote());
  }

  final CheckoutRepository _checkout;
  final CartRepository _cartRepo;
  final AnalyticsService? _analytics;
  final FacebookAnalyticsService? _facebookAnalytics;

  void selectPayment(CheckoutPayment payment) {
    emit(state.copyWith(payment: payment));
    unawaited(_analytics?.paymentInfoAdded(paymentType: payment.name));
  }

  void updateAddress(String address, {double? latitude, double? longitude}) {
    final trimmed = address.trim();
    emit(
      state.copyWith(
        deliveryAddress: trimmed,
        deliveryLatitude: latitude,
        deliveryLongitude: longitude,
        clearDeliveryCoordinates: latitude == null && longitude == null,
      ),
    );
    if (trimmed.isNotEmpty) {
      unawaited(_analytics?.shippingInfoAdded());
    }
    // Delivery fee may depend on the address server-side — re-quote.
    unawaited(_refreshQuote());
  }

  /// Toggles one shop's installation opt-in. The grand total recomputes
  /// instantly via [CheckoutState.grandTotal] (the installation fee is already
  /// known from the quote), so no network round-trip is needed, and flipping
  /// one shop never touches another's total.
  void toggleInstallation(String shopId, bool value) {
    final next = Map<String, bool>.from(state.installationByShop);
    next[shopId] = value;
    emit(state.copyWith(installationByShop: next));
  }

  /// Fetches the server-computed invoice for each shop and merges them into the
  /// state. One quote per shop, because each shop becomes its own order — the
  /// backend rejects a multi-shop order, so a single aggregate quote would be a
  /// fiction. Failures are swallowed per-shop: that shop keeps its local
  /// estimate and is priced server-side at submit time regardless.
  Future<void> _refreshQuote() async {
    final groups = state.groups;
    if (groups.isEmpty) return;
    final quotes = await Future.wait(groups.map(_quoteGroup));
    if (isClosed) return;
    // Merge onto the previous map so a shop whose quote failed this round keeps
    // its last-known-good figure instead of dropping back to the local estimate.
    final merged = Map<String, CheckoutQuote>.from(state.quotesByShop);
    var changed = false;
    for (var i = 0; i < groups.length; i++) {
      final q = quotes[i];
      if (q != null) {
        merged[groups[i].shopId] = q;
        changed = true;
      }
    }
    if (changed) emit(state.copyWith(quotesByShop: merged));
  }

  /// Quotes a single shop group, or null if the call fails. The server quote
  /// always returns the *potential* installation fee, so the per-shop switch
  /// can add/remove it locally — [wantInstallation] only sets which figure the
  /// (unused-here) `grand_total` reflects.
  Future<CheckoutQuote?> _quoteGroup(ShopOrderGroup group) async {
    final result = await _checkout.quote(
      lines: [
        for (final it in group.items)
          CheckoutOrderLine(
            productId: it.productId,
            quantity: it.quantity,
            colorSlug: it.selectedColor,
          ),
      ],
      deliveryAddress: state.deliveryAddress,
      wantInstallation: state.wantsInstallationFor(group.shopId),
    );
    // A failed quote keeps the last-known-good figure (null → not merged),
    // exactly as the old catch-returns-null did.
    return result.valueOrNull;
  }

  Future<void> submit(String userId) async {
    if (state.status == CheckoutStatus.submitting) return;
    emit(state.copyWith(status: CheckoutStatus.submitting, clearError: true));

    try {
      final placedIds = <String>[];

      for (final group in state.groups) {
        // One order per shop group → POST /orders. The backend resolves the
        // caller from the JWT and computes the authoritative total from product
        // prices (so total_amount/price/status aren't client-supplied).
        final result = await _checkout.placeOrder(
          lines: [
            for (final it in group.items)
              CheckoutOrderLine(
                productId: it.productId,
                quantity: it.quantity,
                colorSlug: it.selectedColor,
              ),
          ],
          deliveryAddress: state.deliveryAddress,
          deliveryLatitude: state.deliveryLatitude,
          deliveryLongitude: state.deliveryLongitude,
          // Stored on the order so seller-accept can branch (cash → confirmed,
          // online → awaiting_payment). Deferred payment: NO charge here.
          paymentMethod: state.payment.name,
          // Each shop carries its own installation opt-in, so its order is
          // priced exactly as that shop's card shows — never the global flag.
          wantInstallation: state.wantsInstallationFor(group.shopId),
        );
        final String orderId;
        switch (result) {
          case Ok(:final value):
            orderId = value;
          case Err(:final failure):
            // A failed placement aborts the whole submit with the same
            // localised message the caught ApiError used to yield.
            if (isClosed) return;
            emit(
              state.copyWith(
                status: CheckoutStatus.failure,
                error: failure.message,
              ),
            );
            return;
        }
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
        unawaited(
          _facebookAnalytics?.logPurchase(
            group.subtotal.toDouble(),
            'UZS',
            contentIds: [for (final it in group.items) it.productId],
            numItems: group.items.length,
            orderId: orderId,
          ),
        );
      }

      // Orders now exist server-side, so the cart is empty regardless of what
      // happens next — clear it so a failed hand-off can't leave a stale cart
      // that re-checks-out into duplicates.
      await _cartRepo.clear();

      // Deferred payment: NO checkout link is minted here, even for Payme/Click.
      // The order stays pending until the seller reviews the address and sets
      // the exact delivery fee; for an online order it then moves to
      // `awaiting_payment` and the customer pays the final total from the order
      // screen ("To'lovni amalga oshirish"). Checkout just confirms placement.
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

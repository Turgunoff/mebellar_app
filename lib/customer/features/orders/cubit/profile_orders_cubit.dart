import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../shared/models/cancel_reason.dart';
import '../../../../shared/repositories/profile_orders_repository.dart';

class ProfileOrdersState extends Equatable {
  const ProfileOrdersState({this.orders = const [], this.isLoading = false});

  final List<Map<String, dynamic>> orders;
  final bool isLoading;

  // Derived counts — always reflect latest state without extra fields.
  // Status codes mirror `OrderStatus` in shared/models/order_status.dart:
  // pending · confirmed · preparing · shipped · delivered · cancelled.
  int get pendingCount => orders.where((o) => o['status'] == 'pending').length;

  /// Orders the seller has accepted and is preparing — surfaced under the
  /// "Tayyorlanmoqda" tile.
  int get processingCount => orders
      .where((o) => o['status'] == 'confirmed' || o['status'] == 'preparing')
      .length;

  /// Orders out for delivery — the "Yo'lda" tile.
  int get deliveringCount =>
      orders.where((o) => o['status'] == 'shipped').length;

  bool get hasActivity =>
      pendingCount > 0 || processingCount > 0 || deliveringCount > 0;

  ProfileOrdersState copyWith({
    List<Map<String, dynamic>>? orders,
    bool? isLoading,
  }) => ProfileOrdersState(
    orders: orders ?? this.orders,
    isLoading: isLoading ?? this.isLoading,
  );

  @override
  List<Object?> get props => [orders, isLoading];
}

class ProfileOrdersCubit extends Cubit<ProfileOrdersState> {
  ProfileOrdersCubit(this._repo, this._auth)
    : super(const ProfileOrdersState());

  final ProfileOrdersRepository _repo;
  final AuthRepository _auth;

  Future<void> fetch() async {
    if (!_auth.isAuthenticated) return;

    emit(state.copyWith(isLoading: true));

    try {
      final rows = await _repo.fetchOrders();
      // A mode switch / logout can close this cubit while the request is
      // in flight (e.g. login racing a stale-cache seller promotion tears
      // down the customer scope mid-fetch) — emitting after close throws.
      if (isClosed) return;
      emit(ProfileOrdersState(orders: rows.map(_toCardMap).toList()));
    } catch (e, st) {
      // Order-list fetch failed — clear the spinner so the UI isn't stuck,
      // and log the cause so an auth/transport failure isn't mistaken for an
      // empty list.
      appLog.handle(e, st, 'ProfileOrdersCubit.load failed');
      if (isClosed) return;
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Cancels via the backend, then patches the in-memory list so every
  /// listener (OrdersHistoryScreen, ProfileScreen badges, delete-account
  /// guard) immediately reflects the cancellation without a full re-fetch.
  Future<void> cancelOrder(
    String orderId, {
    required String reasonCode,
    String? reasonText,
  }) async {
    await _repo.cancel(orderId, reasonCode: reasonCode, reasonText: reasonText);
    if (isClosed) return;

    final updated = state.orders.map((o) {
      if (o['id'] == orderId) {
        return <String, dynamic>{
          ...o,
          'status': 'cancelled',
          'cancel_reason_code': reasonCode,
          if (reasonText != null && reasonText.isNotEmpty)
            'cancel_reason_text': reasonText,
        };
      }
      return o;
    }).toList();

    emit(state.copyWith(orders: updated));
  }

  /// Predefined cancel reasons for the picker (delegates to the repo).
  Future<List<CancelReason>> cancelReasons() => _repo.fetchCancelReasons();

  /// Maps a woody_backend `CustomerOrder` JSON row to the legacy
  /// PostgREST-shaped map the order-history UI consumes: `items`→`order_items`,
  /// `product`→`products`. `reviews` is a non-null marker when the backend's
  /// per-item `reviewed` flag is set (else null) — so the "rate products" CTA
  /// disappears once every delivered line has been reviewed.
  Map<String, dynamic> _toCardMap(Map<String, dynamic> row) {
    final items = (row['items'] as List?) ?? const [];
    return {
      'id': row['id'],
      'status': row['status'],
      'total_amount': row['total_amount'],
      'created_at': row['created_at'],
      'delivery_address': row['delivery_address'],
      'cancellation_reason': row['cancellation_reason'],
      'fee_adjustment_status': row['fee_adjustment_status'],
      'proposed_delivery_fee': row['proposed_delivery_fee'],
      'order_items': [
        for (final raw in items)
          if (raw is Map<String, dynamic>)
            {
              'quantity': raw['quantity'],
              // Non-null ⇒ this line is already reviewed (backend `reviewed`
              // flag). The history card treats a null `reviews` as unreviewed.
              'reviews': raw['reviewed'] == true
                  ? {'rating': raw['review_rating']}
                  : null,
              'products': {
                'images': _itemImages(raw),
                'name':
                    raw['product_name'] ??
                    (raw['product'] is Map<String, dynamic>
                        ? raw['product']['name']
                        : null),
              },
            },
      ],
    };
  }

  /// First product image for an order line as a one-element list — the flat
  /// `product_image` the backend now returns, falling back to a nested
  /// `product.images` join for older payloads. Kept as a list because the
  /// history card reads `products.images.first`.
  List<String> _itemImages(Map<String, dynamic> raw) {
    final flat = raw['product_image'];
    if (flat is String && flat.isNotEmpty) return [flat];
    final nested = raw['product'];
    if (nested is Map<String, dynamic>) {
      final images = nested['images'];
      if (images is List) return images.whereType<String>().toList();
    }
    return const [];
  }
}

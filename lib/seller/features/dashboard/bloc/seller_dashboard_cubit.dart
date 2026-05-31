import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/repositories/seller_dashboard_repository.dart';
import '../../profile/data/seller_identity_cache.dart';

/// Single-state cubit that powers `SellerDashboardScreen`. The state always
/// holds a valid (possibly zero-filled) `data` object so the UI never has to
/// branch on null — the zero-state experience is just `data == empty`.
class SellerDashboardCubit extends Cubit<SellerDashboardState> {
  SellerDashboardCubit(this._repo, {this.cache, AuthRepository? auth})
    : _auth = auth,
      super(SellerDashboardState.initial()) {
    _newOrdersSub = _repo.newOrders().listen((_) => refresh());
  }

  final SellerDashboardRepository _repo;
  final SellerIdentityCache? cache;
  final AuthRepository? _auth;
  StreamSubscription<Order>? _newOrdersSub;

  Future<void> load() async {
    // Hydrate the greeting from cache so the user's shop name paints
    // immediately while the live snapshot fetch is still in flight.
    final cached = _readCachedGreeting();
    if (cached != null) {
      emit(
        state.copyWith(
          isLoading: true,
          clearError: true,
          data: state.data.copyWith(
            shopName: cached.shopName,
            sellerName: cached.sellerName,
          ),
        ),
      );
    } else {
      emit(state.copyWith(isLoading: true, clearError: true));
    }
    await _loadInto(state.data);
  }

  Future<void> refresh() async {
    // Keep previous data on screen, no shimmer flash on a manual pull-to-refresh.
    await _loadInto(state.data, skipLoadingFlag: true);
  }

  Future<void> _loadInto(
    SellerDashboardData previous, {
    bool skipLoadingFlag = false,
  }) async {
    try {
      final snap = await _repo.snapshot();
      emit(
        SellerDashboardState(
          isLoading: false,
          // Shop/seller name come from the identity cache (populated by the
          // profile cubit); the Woody dashboard snapshot carries KPIs only —
          // so preserve whatever greeting was already painted.
          data: SellerDashboardData(
            sellerName: previous.sellerName,
            shopName: previous.shopName,
            todaysSales: snap.todaysRevenue,
            todaysOrders: snap.todaysOrders,
            pendingOrders: snap.pendingOrdersCount,
            productsCount: snap.activeProductsCount,
            recentOrders: List<Order>.from(snap.recentOrders),
          ),
        ),
      );
    } catch (e) {
      emit(
        SellerDashboardState(
          isLoading: false,
          data: previous,
          error: e.toString(),
        ),
      );
    }
  }

  SellerIdentitySnapshot? _readCachedGreeting() {
    final c = cache;
    final userId = _auth?.currentUserId;
    if (c == null || userId == null) return null;
    final snapshot = c.read(userId);
    if (snapshot == null || snapshot.isEmpty) return null;
    return snapshot;
  }

  @override
  Future<void> close() async {
    await _newOrdersSub?.cancel();
    return super.close();
  }
}

/// Immutable view-model for the dashboard screen. Zero-state is the default
/// — UI just reads the numbers and decides what to render.
class SellerDashboardData extends Equatable {
  const SellerDashboardData({
    this.sellerName,
    this.shopName,
    this.todaysSales = 0,
    this.todaysOrders = 0,
    this.pendingOrders = 0,
    this.productsCount = 0,
    this.productLimit = 30,
    this.recentOrders = const [],
  });

  /// `sellers.legal_name`. `null` when blank — UI falls back to "Sotuvchi".
  final String? sellerName;
  final String? shopName;
  final num todaysSales;
  final int todaysOrders;
  final int pendingOrders;
  final int productsCount;
  final int productLimit;
  final List<Order> recentOrders;

  /// Greeting name. Always non-empty: "Sotuvchi" when `sellerName` is blank.
  String get displaySellerName =>
      (sellerName == null || sellerName!.isEmpty) ? 'Sotuvchi' : sellerName!;

  bool get hasRecentOrders => recentOrders.isNotEmpty;
  bool get productLimitExceeded => productsCount > productLimit;

  SellerDashboardData copyWith({
    String? sellerName,
    String? shopName,
    num? todaysSales,
    int? todaysOrders,
    int? pendingOrders,
    int? productsCount,
    int? productLimit,
    List<Order>? recentOrders,
  }) {
    return SellerDashboardData(
      sellerName: sellerName ?? this.sellerName,
      shopName: shopName ?? this.shopName,
      todaysSales: todaysSales ?? this.todaysSales,
      todaysOrders: todaysOrders ?? this.todaysOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      productsCount: productsCount ?? this.productsCount,
      productLimit: productLimit ?? this.productLimit,
      recentOrders: recentOrders ?? this.recentOrders,
    );
  }

  @override
  List<Object?> get props => [
    sellerName,
    shopName,
    todaysSales,
    todaysOrders,
    pendingOrders,
    productsCount,
    productLimit,
    recentOrders.length,
  ];
}

class SellerDashboardState extends Equatable {
  const SellerDashboardState({
    required this.isLoading,
    required this.data,
    this.error,
  });

  factory SellerDashboardState.initial() =>
      const SellerDashboardState(isLoading: true, data: SellerDashboardData());

  final bool isLoading;
  final SellerDashboardData data;
  final String? error;

  SellerDashboardState copyWith({
    bool? isLoading,
    SellerDashboardData? data,
    String? error,
    bool clearError = false,
  }) {
    return SellerDashboardState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [isLoading, data, error];
}

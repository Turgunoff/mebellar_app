import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/order.dart';
import '../../../../shared/repositories/seller_dashboard_repository.dart';
import '../../../../shared/repositories/supabase_seller_dashboard_repository.dart';

/// Single-state cubit that powers `SellerDashboardScreen`. The state always
/// holds a valid (possibly zero-filled) `data` object so the UI never has to
/// branch on null — the zero-state experience is just `data == empty`.
class SellerDashboardCubit extends Cubit<SellerDashboardState> {
  SellerDashboardCubit(this._repo)
      : super(SellerDashboardState.initial()) {
    final repo = _repo;
    if (repo is SupabaseSellerDashboardRepository) {
      _shopInfoFetcher = repo.fetchShopInfo;
    }
    _newOrdersSub = _repo.newOrders().listen((_) => refresh());
  }

  final SellerDashboardRepository _repo;
  Future<SellerShopInfo> Function()? _shopInfoFetcher;
  StreamSubscription<Order>? _newOrdersSub;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
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
      final shopInfoFuture = _shopInfoFetcher?.call() ??
          Future.value(const SellerShopInfo());
      final snapshotFuture = _repo.snapshot();

      final results = await Future.wait<dynamic>([
        shopInfoFuture,
        snapshotFuture,
      ]);
      final info = results[0] as SellerShopInfo;
      final snap = results[1] as dynamic; // DashboardSnapshot

      emit(
        SellerDashboardState(
          isLoading: false,
          data: SellerDashboardData(
            sellerName: info.sellerName,
            shopName: info.shopName,
            todaysSales: snap.todaysRevenue as num,
            todaysOrders: snap.todaysOrders as int,
            pendingOrders: snap.pendingOrdersCount as int,
            productsCount: snap.activeProductsCount as int,
            productLimit: SupabaseSellerDashboardRepository.productLimit,
            recentOrders: List<Order>.from(snap.recentOrders as Iterable),
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

  factory SellerDashboardState.initial() => const SellerDashboardState(
        isLoading: true,
        data: SellerDashboardData(),
      );

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

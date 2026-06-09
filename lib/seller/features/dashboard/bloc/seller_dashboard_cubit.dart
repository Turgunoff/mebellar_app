import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../shared/models/dashboard_snapshot.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/repositories/seller_dashboard_repository.dart';
import '../../profile/data/seller_identity_cache.dart';
import '../data/dashboard_models.dart';

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
    // Fetch the greeting (name/shop) here — independent of the profile tab —
    // so it's correct on the first load after sign-in, not only after a hot
    // restart that happens to read a surviving cache.
    await _refreshIdentity();
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
            plan: snap.tariff.plan,
            productLimit: snap.tariff.plan.maxActiveProducts,
            recentOrders: List<Order>.from(snap.recentOrders),
            weekly: snap.weekly,
            kpiDeltas: snap.kpiDeltas,
            achievements: snap.achievements
                .map(Achievement.fromProgress)
                .toList(growable: false),
            leaderboard: snap.leaderboard
                .map(LeaderboardEntry.fromStanding)
                .toList(growable: false),
            topProducts: snap.topProducts
                .map(TopProduct.fromStat)
                .toList(growable: false),
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

  /// Fetches the seller's display name + shop name and updates the greeting.
  /// Best-effort: a 404 (no seller row yet) or a transient failure leaves the
  /// cached/default greeting untouched. The result is persisted to the shared
  /// identity cache so the profile tab and the next cold start read it too.
  Future<void> _refreshIdentity() async {
    try {
      final ident = await _repo.identity();
      final name = (ident.sellerName?.isNotEmpty ?? false)
          ? ident.sellerName
          : state.data.sellerName;
      final shop = (ident.shopName?.isNotEmpty ?? false)
          ? ident.shopName
          : state.data.shopName;
      if (name == state.data.sellerName && shop == state.data.shopName) return;
      emit(
        state.copyWith(
          data: state.data.copyWith(sellerName: name, shopName: shop),
        ),
      );
      _persistIdentity(name, shop);
    } catch (_) {
      // Best-effort — keep whatever greeting is already on screen.
    }
  }

  void _persistIdentity(String? sellerName, String? shopName) {
    final c = cache;
    final userId = _auth?.currentUserId;
    if (c == null || userId == null) return;
    // Merge (not write) so the profile-only fields the cache also holds —
    // logo, verification status, plan — survive.
    unawaited(
      c.merge(
        userId,
        SellerIdentitySnapshot(sellerName: sellerName, shopName: shopName),
      ),
    );
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
    this.plan = TariffPlan.free,
    this.productLimit = 3,
    this.recentOrders = const [],
    this.weekly = const WeeklySales(),
    this.kpiDeltas = const KpiDeltas(),
    this.achievements = const [],
    this.leaderboard = const [],
    this.topProducts = const [],
  });

  /// `sellers.legal_name`. `null` when blank — UI falls back to "Sotuvchi".
  final String? sellerName;
  final String? shopName;
  final num todaysSales;
  final int todaysOrders;
  final int pendingOrders;
  final int productsCount;

  /// The seller's current plan — drives the product-quota label/limit.
  final TariffPlan plan;

  /// Active-product cap for [plan]. `-1` means unlimited.
  final int productLimit;
  final List<Order> recentOrders;

  /// Last-7-days sales series + week total + delta for the hero sparkline.
  final WeeklySales weekly;

  /// Period-over-period deltas for the KPI trend chips.
  final KpiDeltas kpiDeltas;

  /// Milestone progress for the achievements strip + detail screen.
  final List<Achievement> achievements;

  /// This week's top sellers (top 5 + the caller's own row).
  final List<LeaderboardEntry> leaderboard;

  /// Best-selling products over the last 30 days.
  final List<TopProduct> topProducts;

  /// Greeting name. Always non-empty: "Sotuvchi" when `sellerName` is blank.
  String get displaySellerName =>
      (sellerName == null || sellerName!.isEmpty) ? 'Sotuvchi' : sellerName!;

  bool get hasRecentOrders => recentOrders.isNotEmpty;
  bool get productLimitExceeded =>
      !plan.isUnlimited && productsCount > productLimit;

  SellerDashboardData copyWith({
    String? sellerName,
    String? shopName,
    num? todaysSales,
    int? todaysOrders,
    int? pendingOrders,
    int? productsCount,
    TariffPlan? plan,
    int? productLimit,
    List<Order>? recentOrders,
    WeeklySales? weekly,
    KpiDeltas? kpiDeltas,
    List<Achievement>? achievements,
    List<LeaderboardEntry>? leaderboard,
    List<TopProduct>? topProducts,
  }) {
    return SellerDashboardData(
      sellerName: sellerName ?? this.sellerName,
      shopName: shopName ?? this.shopName,
      todaysSales: todaysSales ?? this.todaysSales,
      todaysOrders: todaysOrders ?? this.todaysOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      productsCount: productsCount ?? this.productsCount,
      plan: plan ?? this.plan,
      productLimit: productLimit ?? this.productLimit,
      recentOrders: recentOrders ?? this.recentOrders,
      weekly: weekly ?? this.weekly,
      kpiDeltas: kpiDeltas ?? this.kpiDeltas,
      achievements: achievements ?? this.achievements,
      leaderboard: leaderboard ?? this.leaderboard,
      topProducts: topProducts ?? this.topProducts,
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
    plan,
    productLimit,
    recentOrders.length,
    weekly,
    kpiDeltas,
    achievements.length,
    leaderboard.length,
    topProducts.length,
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

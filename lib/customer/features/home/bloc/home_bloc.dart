import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/connectivity/network_cubit.dart';
import '../../../../core/i18n/app_locale_controller.dart';
import '../../../../core/i18n/locale_refetch.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../shared/models/banner.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/repositories/banner_repository.dart';
import '../../../../shared/repositories/product_data_source.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => const [];
}

class HomeRequested extends HomeEvent {
  const HomeRequested({this.refresh = false});
  final bool refresh;
  @override
  List<Object?> get props => [refresh];
}

/// Fired by the feed's scroll trigger when the user nears the end of the loaded
/// page. Appends the next page; ignored when a page is already loading or the
/// catalog is exhausted.
class HomeLoadMoreProducts extends HomeEvent {
  const HomeLoadMoreProducts();
}

/// Re-orders the feed (sort bottom sheet). Resets pagination and refetches the
/// first page; the current items stay on screen until the new page lands.
class HomeSortChanged extends HomeEvent {
  const HomeSortChanged(this.sort);
  final HomeFeedSort sort;
  @override
  List<Object?> get props => [sort];
}

enum HomeStatus { initial, loading, ready, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.banners = const [],
    this.recommended = const [],
    this.sort = HomeFeedSort.recommended,
    this.hasMore = false,
    this.loadingMore = false,
    this.feedReloading = false,
    this.error,
  });

  final HomeStatus status;
  final List<HomeBanner> banners;
  final List<ProductModel> recommended;

  /// Active ordering of the feed — surfaced in the sort chip and re-sent on
  /// every page fetch so pagination and ordering stay in lock-step.
  final HomeFeedSort sort;

  /// Whether another page remains to fetch. Drives the scroll trigger + footer.
  final bool hasMore;

  /// A next-page append is in flight (footer spinner).
  final bool loadingMore;

  /// A sort change is refetching the first page (sort-chip spinner); the
  /// current items stay visible until it completes.
  final bool feedReloading;

  final String? error;

  HomeState copyWith({
    HomeStatus? status,
    List<HomeBanner>? banners,
    List<ProductModel>? recommended,
    HomeFeedSort? sort,
    bool? hasMore,
    bool? loadingMore,
    bool? feedReloading,
    String? error,
    bool clearError = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      banners: banners ?? this.banners,
      recommended: recommended ?? this.recommended,
      sort: sort ?? this.sort,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      feedReloading: feedReloading ?? this.feedReloading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    status,
    banners,
    recommended,
    sort,
    hasMore,
    loadingMore,
    feedReloading,
    error,
  ];
}

class HomeBloc extends Bloc<HomeEvent, HomeState>
    with LocaleRefetch<HomeState> {
  HomeBloc({
    required BannerRepository bannerRepo,
    required ProductDataSource productSource,
    NetworkCubit? networkCubit,
    AppLocaleController? localeController,
  }) : _bannerRepo = bannerRepo,
       _productSource = productSource,
       _networkCubit = networkCubit,
       super(const HomeState()) {
    watchLocale(localeController);
    // ROADMAP B.7 — droppable: a refresh fired while a load is already in
    // flight (connectivity retry + manual pull-to-refresh racing) is dropped
    // rather than queued, so the home feed never double-fetches.
    on<HomeRequested>(_onRequested, transformer: droppable());
    // Droppable too: rapid scroll past the trigger must not stack up a queue
    // of identical next-page fetches.
    on<HomeLoadMoreProducts>(_onLoadMore, transformer: droppable());
    // Restartable: a second sort tap cancels the first in-flight refetch so the
    // latest choice always wins, even on a slow network.
    on<HomeSortChanged>(_onSortChanged, transformer: restartable());

    // Auto-retry when connectivity comes back. We only fire the refresh
    // when the previous load actually failed — there's no point hammering
    // the API every time the user toggles airplane mode if the feed is
    // already up to date.
    final cubit = _networkCubit;
    if (cubit != null) {
      _netSub = cubit.stream.listen((next) {
        final wasOffline = _lastNetwork == NetworkStatus.offline;
        _lastNetwork = next;
        if (wasOffline &&
            next == NetworkStatus.online &&
            state.status == HomeStatus.failure) {
          add(const HomeRequested(refresh: true));
        }
      });
      _lastNetwork = cubit.state;
    }
  }

  final BannerRepository _bannerRepo;
  final ProductDataSource _productSource;
  final NetworkCubit? _networkCubit;
  StreamSubscription<NetworkStatus>? _netSub;
  NetworkStatus _lastNetwork = NetworkStatus.initial;

  static const int _pageSize = kHomeFeedPageSize;

  // Banners + recommended products arrive pre-localised; reload them in the
  // new language without flipping the home feed into a loading state.
  @override
  void onLocaleChanged() => add(const HomeRequested(refresh: true));

  // Tier 3 of the network-UX flow: a hard 5s ceiling on the load. Shorter than
  // Dio's 15s connect / 30s receive timeouts so a dead connection surfaces the
  // blocking modal fast instead of spinning for 30s. This *races* the request —
  // it does not cancel the underlying Dio call, which runs to completion in the
  // background (its late result is discarded, though CachedProductDataSource
  // still writes it to the cache for next time).
  static const Duration _loadTimeout = Duration(seconds: 5);

  Future<void> _onRequested(
    HomeRequested event,
    Emitter<HomeState> emit,
  ) async {
    // Cache-first paint: if both rails have a fresh cached snapshot, emit
    // `ready` *before* the network call so the user never sees a spinner on
    // cold start. We still fetch in the background to refresh the cache;
    // any deltas land as a second `ready` emit a few hundred ms later. The
    // cached feed page only matches when we're on the default sort.
    final cachedBanners = _bannerRepo.peek();
    final cachedFeed = state.sort == HomeFeedSort.recommended
        ? _productSource.peekFeed()
        : null;
    final hasCache = cachedBanners != null && cachedFeed != null;
    final hasData = state.banners.isNotEmpty || state.recommended.isNotEmpty;
    if (hasCache && !event.refresh) {
      emit(
        state.copyWith(
          status: HomeStatus.ready,
          banners: cachedBanners,
          recommended: cachedFeed.items,
          hasMore: cachedFeed.items.length < cachedFeed.total,
          loadingMore: false,
          feedReloading: false,
          clearError: true,
        ),
      );
    } else if (!hasData) {
      // Tier 2 — nothing on screen: show the shimmer. We emit `loading` even on
      // a refresh (e.g. the retry fired from the blocking modal) so the attempt
      // is observable: it drives the modal's button spinner, and — because Bloc
      // de-dupes identical states via Equatable — it guarantees a *repeated*
      // failure still re-emits (failure → loading → failure) instead of being
      // swallowed, which would otherwise hang the spinner forever.
      emit(state.copyWith(status: HomeStatus.loading, clearError: true));
    }

    try {
      final results = await Future.wait([
        _bannerRepo.list(),
        _productSource.listFeed(limit: _pageSize, offset: 0, sort: state.sort),
      ]).timeout(_loadTimeout);

      final banners = results[0] as List<HomeBanner>;
      final page = results[1] as ProductFeedPage;
      emit(
        state.copyWith(
          status: HomeStatus.ready,
          banners: banners,
          recommended: page.items,
          hasMore: page.items.length < page.total,
          loadingMore: false,
          feedReloading: false,
          clearError: true,
        ),
      );
    } catch (e) {
      // Keep showing the rails we already have (cached snapshot OR the
      // currently rendered state — e.g. a locale-switch refetch finds the
      // new language's cache cold) — surface the error only when there is
      // nothing to display, otherwise the user sees a populated screen with
      // a transient banner instead of a blank failure.
      if (hasCache || state.status == HomeStatus.ready) {
        emit(state.copyWith(error: apiErrorMessage(e)));
      } else {
        emit(
          state.copyWith(status: HomeStatus.failure, error: apiErrorMessage(e)),
        );
      }
    }
  }

  Future<void> _onLoadMore(
    HomeLoadMoreProducts event,
    Emitter<HomeState> emit,
  ) async {
    // Only paginate a healthy, settled feed with more rows left.
    if (state.status != HomeStatus.ready ||
        !state.hasMore ||
        state.loadingMore ||
        state.feedReloading) {
      return;
    }
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _productSource
          .listFeed(
            limit: _pageSize,
            offset: state.recommended.length,
            sort: state.sort,
          )
          .timeout(_loadTimeout);
      // Dedup by id so a catalog shift between pages can't double-render a
      // product; `seen.add` returns false for ids already loaded.
      final seen = state.recommended.map((p) => p.id).toSet();
      final fresh = page.items.where((p) => seen.add(p.id)).toList();
      final merged = [...state.recommended, ...fresh];
      emit(
        state.copyWith(
          recommended: merged,
          // An empty page (offset past the end) or reaching the total stops
          // the trigger; never loop on a stale/short total.
          hasMore: page.items.isNotEmpty && merged.length < page.total,
          loadingMore: false,
        ),
      );
    } catch (e) {
      // Soft-fail: keep what we have and clear the spinner. The next scroll
      // re-arms the trigger, letting the user retry by simply scrolling again.
      emit(state.copyWith(loadingMore: false));
    }
  }

  Future<void> _onSortChanged(
    HomeSortChanged event,
    Emitter<HomeState> emit,
  ) async {
    if (event.sort == state.sort) return;
    final previous = state.sort;
    // Keep the current items visible under the sort-chip spinner so the feed
    // doesn't flash a skeleton on every re-sort; swap them when the page lands.
    emit(state.copyWith(sort: event.sort, feedReloading: true, clearError: true));
    try {
      final page = await _productSource
          .listFeed(limit: _pageSize, offset: 0, sort: event.sort)
          .timeout(_loadTimeout);
      emit(
        state.copyWith(
          recommended: page.items,
          hasMore: page.items.isNotEmpty && page.items.length < page.total,
          loadingMore: false,
          feedReloading: false,
        ),
      );
    } catch (e) {
      // Revert the chip to the previous sort so the label matches the items
      // still on screen; surface a soft error.
      emit(
        state.copyWith(
          sort: previous,
          feedReloading: false,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _netSub?.cancel();
    return super.close();
  }
}

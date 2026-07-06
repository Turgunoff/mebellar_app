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

/// Re-orders the trending feed (sort bottom sheet). Resets pagination and
/// refetches the first page; the current items stay on screen until the new page
/// lands.
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
    this.forYou = const [],
    this.forYouPersonalized = false,
    this.trending = const [],
    this.sort = HomeFeedSort.popular,
    this.hasMore = false,
    this.loadingMore = false,
    this.feedReloading = false,
    this.error,
  });

  final HomeStatus status;
  final List<HomeBanner> banners;
  final List<ProductModel> forYou;
  final bool forYouPersonalized;
  final List<ProductModel> trending;

  /// Active ordering of the trending feed — surfaced in the sort chip and
  /// re-sent on every page fetch so pagination and ordering stay in lock-step.
  final HomeFeedSort sort;

  /// Whether another page remains to fetch. Drives the scroll trigger + footer.
  final bool hasMore;

  /// A next-page append is in flight (footer spinner).
  final bool loadingMore;

  /// A sort change is refetching the first trending page (sort-chip spinner).
  final bool feedReloading;

  final String? error;

  HomeState copyWith({
    HomeStatus? status,
    List<HomeBanner>? banners,
    List<ProductModel>? forYou,
    bool? forYouPersonalized,
    List<ProductModel>? trending,
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
      forYou: forYou ?? this.forYou,
      forYouPersonalized: forYouPersonalized ?? this.forYouPersonalized,
      trending: trending ?? this.trending,
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
    forYou,
    forYouPersonalized,
    trending,
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
    on<HomeRequested>(_onRequested, transformer: droppable());
    on<HomeLoadMoreProducts>(_onLoadMore, transformer: droppable());
    on<HomeSortChanged>(_onSortChanged, transformer: restartable());

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

  int _feedOffset = 0;

  static const int _pageSize = kHomeFeedPageSize;

  bool _moreAfter(ProductFeedPage page) =>
      page.items.length >= _pageSize && _feedOffset < page.total;

  @override
  void onLocaleChanged() => add(const HomeRequested(refresh: true));

  static const Duration _loadTimeout = Duration(seconds: 5);

  Future<void> _onRequested(
    HomeRequested event,
    Emitter<HomeState> emit,
  ) async {
    final cachedBanners = _bannerRepo.peek();
    final cachedForYou = _productSource.peekForYou();
    final cachedTrending = state.sort == HomeFeedSort.popular
        ? _productSource.peekFeed()
        : null;
    final hasCache =
        cachedBanners != null && cachedForYou != null && cachedTrending != null;
    final hasData =
        state.banners.isNotEmpty ||
        state.forYou.isNotEmpty ||
        state.trending.isNotEmpty;
    if (hasCache && !event.refresh) {
      _feedOffset = cachedTrending.items.length;
      emit(
        state.copyWith(
          status: HomeStatus.ready,
          banners: cachedBanners,
          forYou: cachedForYou.items,
          forYouPersonalized: cachedForYou.personalized,
          trending: cachedTrending.items,
          hasMore: _moreAfter(cachedTrending),
          loadingMore: false,
          feedReloading: false,
          clearError: true,
        ),
      );
    } else if (!hasData) {
      emit(state.copyWith(status: HomeStatus.loading, clearError: true));
    }

    final requestedSort = state.sort;
    try {
      final forYouPage = await _productSource
          .fetchForYou(limit: kHomeForYouLimit)
          .timeout(_loadTimeout);
      final excludeIds = forYouPage.items.map((p) => p.id).toList();
      final results = await Future.wait([
        _bannerRepo.list(),
        _productSource.listFeed(
          limit: _pageSize,
          offset: 0,
          sort: requestedSort,
          excludeIds: excludeIds,
        ),
      ]).timeout(_loadTimeout);
      if (emit.isDone || state.sort != requestedSort) return;

      final banners = results[0] as List<HomeBanner>;
      final page = results[1] as ProductFeedPage;
      final feedGrew =
          state.loadingMore || state.trending.length > page.items.length;
      if (feedGrew) {
        emit(
          state.copyWith(
            status: HomeStatus.ready,
            banners: banners,
            forYou: forYouPage.items,
            forYouPersonalized: forYouPage.personalized,
            feedReloading: false,
            clearError: true,
          ),
        );
        return;
      }
      _feedOffset = page.items.length;
      emit(
        state.copyWith(
          status: HomeStatus.ready,
          banners: banners,
          forYou: forYouPage.items,
          forYouPersonalized: forYouPage.personalized,
          trending: page.items,
          hasMore: _moreAfter(page),
          loadingMore: false,
          feedReloading: false,
          clearError: true,
        ),
      );
    } catch (e) {
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
    if (state.status != HomeStatus.ready ||
        !state.hasMore ||
        state.loadingMore ||
        state.feedReloading) {
      return;
    }
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _productSource
          .listFeed(limit: _pageSize, offset: _feedOffset, sort: state.sort)
          .timeout(_loadTimeout);
      _feedOffset += page.items.length;
      final seen = state.trending.map((p) => p.id).toSet();
      final fresh = page.items.where((p) => seen.add(p.id)).toList();
      final merged = [...state.trending, ...fresh];
      emit(
        state.copyWith(
          trending: merged,
          hasMore: _moreAfter(page),
          loadingMore: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingMore: false));
    }
  }

  Future<void> _onSortChanged(
    HomeSortChanged event,
    Emitter<HomeState> emit,
  ) async {
    if (event.sort == state.sort) return;
    final previous = state.sort;
    emit(
      state.copyWith(sort: event.sort, feedReloading: true, clearError: true),
    );
    try {
      final page = await _productSource
          .listFeed(limit: _pageSize, offset: 0, sort: event.sort)
          .timeout(_loadTimeout);
      if (emit.isDone) return;
      _feedOffset = page.items.length;
      emit(
        state.copyWith(
          trending: page.items,
          hasMore: _moreAfter(page),
          loadingMore: false,
          feedReloading: false,
        ),
      );
    } catch (e) {
      if (emit.isDone) return;
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

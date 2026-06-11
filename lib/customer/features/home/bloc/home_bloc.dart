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

enum HomeStatus { initial, loading, ready, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.banners = const [],
    this.recommended = const [],
    this.error,
  });

  final HomeStatus status;
  final List<HomeBanner> banners;
  final List<ProductModel> recommended;
  final String? error;

  HomeState copyWith({
    HomeStatus? status,
    List<HomeBanner>? banners,
    List<ProductModel>? recommended,
    String? error,
    bool clearError = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      banners: banners ?? this.banners,
      recommended: recommended ?? this.recommended,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, banners, recommended, error];
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

  // Banners + recommended products arrive pre-localised; reload them in the
  // new language without flipping the home feed into a loading state.
  @override
  void onLocaleChanged() => add(const HomeRequested(refresh: true));

  Future<void> _onRequested(
    HomeRequested event,
    Emitter<HomeState> emit,
  ) async {
    // Cache-first paint: if both rails have a fresh cached snapshot, emit
    // `ready` *before* the network call so the user never sees a spinner on
    // cold start. We still fetch in the background to refresh the cache;
    // any deltas land as a second `ready` emit a few hundred ms later.
    final cachedBanners = _bannerRepo.peek();
    final cachedRecommended = _productSource.peekRecommended();
    final hasCache = cachedBanners != null && cachedRecommended != null;
    if (hasCache && !event.refresh) {
      emit(
        state.copyWith(
          status: HomeStatus.ready,
          banners: cachedBanners,
          recommended: cachedRecommended,
          clearError: true,
        ),
      );
    } else if (!event.refresh) {
      emit(state.copyWith(status: HomeStatus.loading, clearError: true));
    }

    try {
      final results = await Future.wait([
        _bannerRepo.list(),
        _productSource.listAll(limit: 10),
      ]);

      emit(
        state.copyWith(
          status: HomeStatus.ready,
          banners: results[0] as List<HomeBanner>,
          recommended: results[1] as List<ProductModel>,
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
        emit(state.copyWith(status: HomeStatus.failure, error: apiErrorMessage(e)));
      }
    }
  }

  @override
  Future<void> close() async {
    await _netSub?.cancel();
    return super.close();
  }
}

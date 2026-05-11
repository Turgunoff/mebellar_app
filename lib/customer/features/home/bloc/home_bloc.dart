import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/connectivity/network_cubit.dart';
import '../../../../shared/models/banner.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/banner_repository.dart';
import '../../../../shared/repositories/supabase_product_data_source.dart';

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
  final List<SupabaseProductModel> recommended;
  final String? error;

  HomeState copyWith({
    HomeStatus? status,
    List<HomeBanner>? banners,
    List<SupabaseProductModel>? recommended,
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

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required BannerRepository bannerRepo,
    required SupabaseProductDataSource productSource,
    NetworkCubit? networkCubit,
  }) : _bannerRepo = bannerRepo,
       _productSource = productSource,
       _networkCubit = networkCubit,
       super(const HomeState()) {
    on<HomeRequested>(_onRequested);

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
  final SupabaseProductDataSource _productSource;
  final NetworkCubit? _networkCubit;
  StreamSubscription<NetworkStatus>? _netSub;
  NetworkStatus _lastNetwork = NetworkStatus.initial;

  Future<void> _onRequested(
    HomeRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (!event.refresh) {
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
          recommended: results[1] as List<SupabaseProductModel>,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.failure, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _netSub?.cancel();
    return super.close();
  }
}

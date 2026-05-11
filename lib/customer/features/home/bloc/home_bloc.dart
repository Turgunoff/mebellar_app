import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  }) : _bannerRepo = bannerRepo,
       _productSource = productSource,
       super(const HomeState()) {
    on<HomeRequested>(_onRequested);
  }

  final BannerRepository _bannerRepo;
  final SupabaseProductDataSource _productSource;

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
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/home/bloc/home_bloc.dart';
import 'package:woody_app/shared/models/banner.dart';
import 'package:woody_app/shared/models/supabase_product_model.dart';
import 'package:woody_app/shared/repositories/banner_repository.dart';
import 'package:woody_app/shared/repositories/supabase_product_data_source.dart';

class _MockBannerRepo extends Mock implements BannerRepository {}

class _MockProductSource extends Mock implements SupabaseProductDataSource {}

HomeBanner _banner(String id) => HomeBanner(id: id, imageUrl: 'https://x/$id');

SupabaseProductModel _sp(String id) => SupabaseProductModel(
      id: id,
      categoryId: 'cat-1',
      name: 'Product $id',
      price: 100000,
      images: const [],
      stock: 5,
      createdAt: DateTime.utc(2026, 5, 16),
    );

void main() {
  late _MockBannerRepo bannerRepo;
  late _MockProductSource productSource;

  setUp(() {
    bannerRepo = _MockBannerRepo();
    productSource = _MockProductSource();
  });

  HomeBloc build() => HomeBloc(
        bannerRepo: bannerRepo,
        productSource: productSource,
      );

  blocTest<HomeBloc, HomeState>(
    'HomeRequested emits [loading, ready] with banners + recommended',
    build: () {
      when(bannerRepo.list).thenAnswer((_) async => [_banner('b1')]);
      when(() => productSource.listAll(limit: any(named: 'limit')))
          .thenAnswer((_) async => [_sp('p1'), _sp('p2')]);
      return build();
    },
    act: (bloc) => bloc.add(const HomeRequested()),
    expect: () => [
      isA<HomeState>().having((s) => s.status, 'status', HomeStatus.loading),
      isA<HomeState>()
          .having((s) => s.status, 'status', HomeStatus.ready)
          .having((s) => s.banners.length, 'banners', 1)
          .having((s) => s.recommended.length, 'recommended', 2),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'HomeRequested emits [loading, failure] when a source throws',
    build: () {
      when(bannerRepo.list).thenThrow(Exception('banners down'));
      when(() => productSource.listAll(limit: any(named: 'limit')))
          .thenAnswer((_) async => const <SupabaseProductModel>[]);
      return build();
    },
    act: (bloc) => bloc.add(const HomeRequested()),
    expect: () => [
      isA<HomeState>().having((s) => s.status, 'status', HomeStatus.loading),
      isA<HomeState>()
          .having((s) => s.status, 'status', HomeStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'a refresh HomeRequested does NOT re-emit the loading state',
    build: () {
      when(bannerRepo.list).thenAnswer((_) async => [_banner('b1')]);
      when(() => productSource.listAll(limit: any(named: 'limit')))
          .thenAnswer((_) async => [_sp('p1')]);
      return build();
    },
    seed: () => const HomeState(status: HomeStatus.ready),
    act: (bloc) => bloc.add(const HomeRequested(refresh: true)),
    expect: () => [
      isA<HomeState>()
          .having((s) => s.status, 'status', HomeStatus.ready)
          .having((s) => s.banners.length, 'banners', 1),
    ],
  );
}

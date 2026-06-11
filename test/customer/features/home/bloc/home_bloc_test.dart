import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/i18n/app_locale_controller.dart';
import 'package:woody_app/customer/features/home/bloc/home_bloc.dart';
import 'package:woody_app/shared/models/banner.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/repositories/banner_repository.dart';
import 'package:woody_app/shared/repositories/product_data_source.dart';

class _MockBannerRepo extends Mock implements BannerRepository {}

class _MockProductSource extends Mock implements ProductDataSource {}

HomeBanner _banner(String id) => HomeBanner(id: id, imageUrl: 'https://x/$id');

ProductModel _sp(String id) => ProductModel(
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
          .thenAnswer((_) async => const <ProductModel>[]);
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

  group('locale refetch', () {
    late AppLocaleController controller;

    blocTest<HomeBloc, HomeState>(
      'setLocale silently reloads the feed — no loading flash',
      setUp: () => controller = AppLocaleController.inMemory(
        initial: const Locale('uz'),
      ),
      build: () {
        when(bannerRepo.list).thenAnswer((_) async => [_banner('b-ru')]);
        when(() => productSource.listAll(limit: any(named: 'limit')))
            .thenAnswer((_) async => [_sp('p-ru')]);
        return HomeBloc(
          bannerRepo: bannerRepo,
          productSource: productSource,
          localeController: controller,
        );
      },
      seed: () => HomeState(
        status: HomeStatus.ready,
        banners: [_banner('b-uz')],
        recommended: [_sp('p-uz')],
      ),
      act: (_) => controller.setLocale(const Locale('ru')),
      expect: () => [
        // Single emit: straight to the re-localised rails.
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.ready)
            .having((s) => s.banners.single.id, 'banner', 'b-ru')
            .having((s) => s.recommended.single.id, 'product', 'p-ru'),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'a failed locale refetch keeps the old-language rails on screen',
      setUp: () => controller = AppLocaleController.inMemory(
        initial: const Locale('uz'),
      ),
      build: () {
        when(bannerRepo.list).thenThrow(Exception('network down'));
        when(() => productSource.listAll(limit: any(named: 'limit')))
            .thenAnswer((_) async => const <ProductModel>[]);
        return HomeBloc(
          bannerRepo: bannerRepo,
          productSource: productSource,
          localeController: controller,
        );
      },
      seed: () => HomeState(
        status: HomeStatus.ready,
        banners: [_banner('b-uz')],
        recommended: [_sp('p-uz')],
      ),
      act: (_) => controller.setLocale(const Locale('ru')),
      expect: () => [
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.ready)
            .having((s) => s.banners.single.id, 'banner kept', 'b-uz')
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });

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

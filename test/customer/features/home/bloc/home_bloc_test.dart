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

List<ProductModel> _sps(int n) => [for (var i = 0; i < n; i++) _sp('p$i')];

ProductFeedPage _page(List<ProductModel> items, {int? total}) =>
    ProductFeedPage(items: items, total: total ?? items.length);

void main() {
  setUpAll(() => registerFallbackValue(HomeFeedSort.popular));

  late _MockBannerRepo bannerRepo;
  late _MockProductSource productSource;

  setUp(() {
    bannerRepo = _MockBannerRepo();
    productSource = _MockProductSource();
    when(
      () => productSource.fetchForYou(limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => const HomeForYouPage(items: [], personalized: false),
    );
  });

  HomeBloc build() =>
      HomeBloc(bannerRepo: bannerRepo, productSource: productSource);

  void stubFetchForYou(HomeForYouPage page) {
    when(
      () => productSource.fetchForYou(limit: any(named: 'limit')),
    ).thenAnswer((_) async => page);
  }

  void stubFeed(ProductFeedPage page) {
    when(
      () => productSource.listFeed(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        sort: any(named: 'sort'),
        excludeIds: any(named: 'excludeIds'),
      ),
    ).thenAnswer((_) async => page);
  }

  blocTest<HomeBloc, HomeState>(
    'HomeRequested emits [loading, ready] with banners, forYou + trending',
    build: () {
      when(bannerRepo.list).thenAnswer((_) async => [_banner('b1')]);
      stubFetchForYou(HomeForYouPage(items: [_sp('fy1')], personalized: true));
      stubFeed(_page([_sp('p1'), _sp('p2')], total: 2));
      return build();
    },
    act: (bloc) => bloc.add(const HomeRequested()),
    expect: () => [
      isA<HomeState>().having((s) => s.status, 'status', HomeStatus.loading),
      isA<HomeState>()
          .having((s) => s.status, 'status', HomeStatus.ready)
          .having((s) => s.banners.length, 'banners', 1)
          .having((s) => s.forYou.length, 'forYou', 1)
          .having((s) => s.trending.length, 'trending', 2)
          .having((s) => s.hasMore, 'hasMore', false),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'HomeRequested sets hasMore when a full page leaves more in the catalog',
    build: () {
      when(bannerRepo.list).thenAnswer((_) async => [_banner('b1')]);
      // A full page (>= page size) with a larger catalog total ⇒ more to load.
      stubFeed(_page(_sps(15), total: 40));
      return build();
    },
    act: (bloc) => bloc.add(const HomeRequested()),
    expect: () => [
      isA<HomeState>().having((s) => s.status, 'status', HomeStatus.loading),
      isA<HomeState>()
          .having((s) => s.status, 'status', HomeStatus.ready)
          .having((s) => s.hasMore, 'hasMore', true),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'HomeRequested treats a short first page as the last page (hasMore false)',
    build: () {
      when(bannerRepo.list).thenAnswer((_) async => [_banner('b1')]);
      // Short page (< page size) even though total claims more ⇒ stop. The
      // short page is the dedup-immune "last page" signal.
      stubFeed(_page([_sp('p1'), _sp('p2')], total: 40));
      return build();
    },
    act: (bloc) => bloc.add(const HomeRequested()),
    expect: () => [
      isA<HomeState>().having((s) => s.status, 'status', HomeStatus.loading),
      isA<HomeState>()
          .having((s) => s.status, 'status', HomeStatus.ready)
          .having((s) => s.hasMore, 'hasMore', false),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'HomeRequested emits [loading, failure] when a source throws',
    build: () {
      when(bannerRepo.list).thenThrow(Exception('banners down'));
      stubFeed(_page(const []));
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

  group('pagination', () {
    blocTest<HomeBloc, HomeState>(
      'HomeLoadMoreProducts appends the next page and clears hasMore at the end',
      build: () {
        stubFeed(_page([_sp('p2')], total: 2));
        return build();
      },
      seed: () => HomeState(
        status: HomeStatus.ready,
        banners: [_banner('b0')],
        trending: [_sp('p1')],
        hasMore: true,
      ),
      act: (bloc) => bloc.add(const HomeLoadMoreProducts()),
      expect: () => [
        isA<HomeState>()
            .having((s) => s.loadingMore, 'loadingMore', true)
            .having((s) => s.trending.length, 'len', 1),
        isA<HomeState>()
            .having((s) => s.loadingMore, 'loadingMore', false)
            .having((s) => s.trending.length, 'len', 2)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'HomeLoadMoreProducts is a no-op when there is nothing more to load',
      build: () => build(),
      seed: () => HomeState(
        status: HomeStatus.ready,
        trending: [_sp('p1')],
        // hasMore defaults to false.
      ),
      act: (bloc) => bloc.add(const HomeLoadMoreProducts()),
      expect: () => const <HomeState>[],
      verify: (_) => verifyNever(
        () => productSource.listFeed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sort: any(named: 'sort'),
        ),
      ),
    );

    blocTest<HomeBloc, HomeState>(
      'a failed next page clears the spinner and keeps the current items',
      build: () {
        when(
          () => productSource.listFeed(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenThrow(Exception('page down'));
        return build();
      },
      seed: () => HomeState(
        status: HomeStatus.ready,
        trending: [_sp('p1')],
        hasMore: true,
      ),
      act: (bloc) => bloc.add(const HomeLoadMoreProducts()),
      expect: () => [
        isA<HomeState>().having((s) => s.loadingMore, 'loadingMore', true),
        isA<HomeState>()
            .having((s) => s.loadingMore, 'loadingMore', false)
            .having((s) => s.trending.length, 'len kept', 1)
            .having((s) => s.hasMore, 'hasMore kept', true),
      ],
    );

    // Regression: the server offset must advance by the RAW page size, not the
    // deduped list length — otherwise a catalog re-order that returns an
    // all-duplicate page would re-request the same offset forever and the feed
    // would stall before reaching the tail.
    blocTest<HomeBloc, HomeState>(
      'load-more advances the offset past an all-duplicate page (no stall)',
      build: () {
        when(bannerRepo.list).thenAnswer((_) async => const <HomeBanner>[]);
        // Every page returns the SAME 15 ids — page 2+ is pure overlap.
        stubFeed(_page(_sps(15), total: 100));
        return build();
      },
      act: (bloc) async {
        bloc.add(const HomeRequested());
        await bloc.stream.firstWhere((s) => s.status == HomeStatus.ready);
        bloc.add(const HomeLoadMoreProducts());
        await bloc.stream.firstWhere(
          (s) => !s.loadingMore && s.trending.length == 15,
        );
        bloc.add(const HomeLoadMoreProducts());
        await bloc.stream.firstWhere((s) => !s.loadingMore);
      },
      verify: (_) {
        // Three distinct windows requested — the cursor never stuck at 15.
        verify(
          () => productSource.listFeed(
            limit: any(named: 'limit'),
            offset: 0,
            sort: any(named: 'sort'),
          ),
        ).called(1);
        verify(
          () => productSource.listFeed(
            limit: any(named: 'limit'),
            offset: 15,
            sort: any(named: 'sort'),
          ),
        ).called(1);
        verify(
          () => productSource.listFeed(
            limit: any(named: 'limit'),
            offset: 30,
            sort: any(named: 'sort'),
          ),
        ).called(1);
      },
    );
  });

  group('sort', () {
    blocTest<HomeBloc, HomeState>(
      'HomeSortChanged refetches the first page under the new sort',
      build: () {
        stubFeed(_page([_sp('p2'), _sp('p3')], total: 2));
        return build();
      },
      seed: () => HomeState(status: HomeStatus.ready, trending: [_sp('p1')]),
      act: (bloc) => bloc.add(const HomeSortChanged(HomeFeedSort.discount)),
      expect: () => [
        isA<HomeState>()
            .having((s) => s.sort, 'sort', HomeFeedSort.discount)
            .having((s) => s.feedReloading, 'reloading', true)
            .having((s) => s.trending.length, 'len', 1),
        isA<HomeState>()
            .having((s) => s.feedReloading, 'reloading', false)
            .having((s) => s.sort, 'sort', HomeFeedSort.discount)
            .having((s) => s.trending.length, 'len', 2),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'HomeSortChanged reverts the chip and keeps items on failure',
      build: () {
        when(
          () => productSource.listFeed(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenThrow(Exception('sort down'));
        return build();
      },
      seed: () => HomeState(status: HomeStatus.ready, trending: [_sp('p1')]),
      act: (bloc) => bloc.add(const HomeSortChanged(HomeFeedSort.discount)),
      expect: () => [
        isA<HomeState>()
            .having((s) => s.sort, 'sort', HomeFeedSort.discount)
            .having((s) => s.feedReloading, 'reloading', true),
        isA<HomeState>()
            .having((s) => s.sort, 'sort reverted', HomeFeedSort.recommended)
            .having((s) => s.feedReloading, 'reloading', false)
            .having((s) => s.trending.length, 'len kept', 1)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'HomeSortChanged to the active sort is a no-op',
      build: () => build(),
      seed: () => HomeState(
        status: HomeStatus.ready,
        trending: [_sp('p1')],
        // sort defaults to recommended.
      ),
      act: (bloc) => bloc.add(const HomeSortChanged(HomeFeedSort.recommended)),
      expect: () => const <HomeState>[],
    );
  });

  group('locale refetch', () {
    late AppLocaleController controller;

    blocTest<HomeBloc, HomeState>(
      'setLocale silently reloads the feed — no loading flash',
      setUp: () => controller = AppLocaleController.inMemory(
        initial: const Locale('uz'),
      ),
      build: () {
        when(bannerRepo.list).thenAnswer((_) async => [_banner('b-ru')]);
        stubFeed(_page([_sp('p-ru')]));
        return HomeBloc(
          bannerRepo: bannerRepo,
          productSource: productSource,
          localeController: controller,
        );
      },
      seed: () => HomeState(
        status: HomeStatus.ready,
        banners: [_banner('b-uz')],
        trending: [_sp('p-uz')],
      ),
      act: (_) => controller.setLocale(const Locale('ru')),
      expect: () => [
        // Single emit: straight to the re-localised rails.
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.ready)
            .having((s) => s.banners.single.id, 'banner', 'b-ru')
            .having((s) => s.trending.single.id, 'product', 'p-ru'),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'a failed locale refetch keeps the old-language rails on screen',
      setUp: () => controller = AppLocaleController.inMemory(
        initial: const Locale('uz'),
      ),
      build: () {
        when(bannerRepo.list).thenThrow(Exception('network down'));
        stubFeed(_page(const []));
        return HomeBloc(
          bannerRepo: bannerRepo,
          productSource: productSource,
          localeController: controller,
        );
      },
      seed: () => HomeState(
        status: HomeStatus.ready,
        banners: [_banner('b-uz')],
        trending: [_sp('p-uz')],
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
    'a refresh on a POPULATED feed does NOT re-emit the loading state',
    build: () {
      when(bannerRepo.list).thenAnswer((_) async => [_banner('b1')]);
      stubFeed(_page([_sp('p1')]));
      return build();
    },
    seed: () => HomeState(
      status: HomeStatus.ready,
      banners: [_banner('b0')],
      trending: [_sp('p0')],
    ),
    act: (bloc) => bloc.add(const HomeRequested(refresh: true)),
    expect: () => [
      isA<HomeState>()
          .having((s) => s.status, 'status', HomeStatus.ready)
          .having((s) => s.banners.length, 'banners', 1),
    ],
  );

  // Tier 3 — the blocking modal's "Try Again". With nothing on screen, a
  // refresh re-emits `loading` so the modal's button can show its spinner.
  blocTest<HomeBloc, HomeState>(
    'a retry with nothing on screen re-emits loading (drives the modal spinner)',
    build: () {
      when(bannerRepo.list).thenAnswer((_) async => [_banner('b1')]);
      stubFeed(_page([_sp('p1')]));
      return build();
    },
    seed: () => const HomeState(status: HomeStatus.failure),
    act: (bloc) => bloc.add(const HomeRequested(refresh: true)),
    expect: () => [
      isA<HomeState>().having((s) => s.status, 'status', HomeStatus.loading),
      isA<HomeState>()
          .having((s) => s.status, 'status', HomeStatus.ready)
          .having((s) => s.banners.length, 'banners', 1),
    ],
  );

  // The Equatable-dedup guard: a retry that fails again must still surface a
  // state transition (failure → loading → failure) so the modal's spinner
  // resets instead of hanging on a swallowed duplicate `failure`.
  blocTest<HomeBloc, HomeState>(
    'a retry that fails again re-emits via loading so the spinner resets',
    build: () {
      when(bannerRepo.list).thenThrow(Exception('still down'));
      stubFeed(_page(const []));
      return build();
    },
    seed: () => const HomeState(status: HomeStatus.failure, error: 'err'),
    act: (bloc) => bloc.add(const HomeRequested(refresh: true)),
    expect: () => [
      isA<HomeState>().having((s) => s.status, 'status', HomeStatus.loading),
      isA<HomeState>().having((s) => s.status, 'status', HomeStatus.failure),
    ],
  );
}

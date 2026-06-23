import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/product_list/cubit/ar_viewer_cubit.dart';
import 'package:woody_app/shared/ar/glb_cache_manager.dart';
import 'package:woody_app/shared/models/ar_part.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/models/product_set.dart';
import 'package:woody_app/shared/repositories/woody_set_repository.dart';

/// Controllable in-memory stand-in for the file cache. Tracks which model URLs
/// are "on disk" and records every download so tests can assert that a part is
/// fetched at most once.
class _FakeCache extends GlbCacheService {
  _FakeCache({Set<String> cached = const {}, this.downloadFails = false})
    : _cached = {...cached};

  final Set<String> _cached;

  /// When true, [resolve] mimics a failed download by returning the remote URL
  /// unchanged (GlbCacheService's real fallback behaviour) and caches nothing.
  final bool downloadFails;

  final List<String> downloads = [];

  String _file(String url) => 'file:///cache/${url.hashCode}.glb';

  @override
  Future<String?> peek(String url) async =>
      _cached.contains(url) ? _file(url) : null;

  @override
  Future<String> resolve(String url) async {
    downloads.add(url);
    if (downloadFails) return url;
    _cached.add(url);
    return _file(url);
  }
}

class _MockSetRepo extends Mock implements WoodySetRepository {}

ProductModel _product({
  required String id,
  String name = 'Part',
  bool hasModel = true,
  String arStatus = 'approved',
  String? setId,
  num? widthCm,
  num? heightCm,
  num? depthCm,
  List<ArPart> arParts = const [],
}) => ProductModel(
  id: id,
  categoryId: 'cat',
  name: name,
  price: 1000,
  images: ['https://cdn/$name.jpg'],
  stock: 1,
  createdAt: DateTime(2026, 1, 1),
  arModelUrl: hasModel ? 'https://cdn/$id.glb' : null,
  arStatus: arStatus,
  arParts: arParts,
  setId: setId,
  widthCm: widthCm,
  heightCm: heightCm,
  depthCm: depthCm,
);

ArPart _part(String id, {String? url}) => ArPart(
  id: id,
  label: id,
  arModelUrl: url ?? 'https://cdn/$id.glb',
);

void main() {
  group('ArViewerCubit — single product', () {
    late _FakeCache cache;

    blocTest<ArViewerCubit, ArViewerState>(
      'cache miss downloads once then renders from file://',
      build: () {
        cache = _FakeCache();
        return ArViewerCubit(product: _product(id: 'a'), cache: cache);
      },
      wait: const Duration(milliseconds: 20),
      verify: (cubit) {
        expect(cubit.state.phase, ArViewerPhase.rendering);
        expect(cubit.state.src, startsWith('file://'));
        // The model was fetched exactly once.
        expect(cache.downloads, ['https://cdn/a.glb']);
        expect(cubit.state.hasMultipleParts, isFalse);
      },
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'cache hit renders straight from file:// with no download',
      build: () {
        final cache = _FakeCache(cached: {'https://cdn/a.glb'});
        return ArViewerCubit(product: _product(id: 'a'), cache: cache);
      },
      wait: const Duration(milliseconds: 20),
      verify: (cubit) {
        expect(cubit.state.phase, ArViewerPhase.rendering);
        expect(cubit.state.src, startsWith('file://'));
      },
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'falls back to the network URL when the download fails',
      build: () => ArViewerCubit(
        product: _product(id: 'a'),
        cache: _FakeCache(downloadFails: true),
      ),
      wait: const Duration(milliseconds: 20),
      verify: (cubit) {
        expect(cubit.state.phase, ArViewerPhase.rendering);
        expect(cubit.state.src, 'https://cdn/a.glb');
      },
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'onModelRendered flips rendering → ready',
      build: () => ArViewerCubit(
        product: _product(id: 'a'),
        cache: _FakeCache(cached: {'https://cdn/a.glb'}),
      ),
      act: (cubit) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        cubit.onModelRendered();
      },
      wait: const Duration(milliseconds: 20),
      verify: (cubit) => expect(cubit.state.phase, ArViewerPhase.ready),
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'onModelFailed surfaces the retry phase',
      build: () => ArViewerCubit(
        product: _product(id: 'a'),
        cache: _FakeCache(cached: {'https://cdn/a.glb'}),
      ),
      act: (cubit) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        cubit.onModelFailed();
      },
      wait: const Duration(milliseconds: 20),
      verify: (cubit) => expect(cubit.state.phase, ArViewerPhase.failed),
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'a part with no model URL goes straight to failed',
      build: () => ArViewerCubit(
        product: _product(id: 'a', hasModel: false, arStatus: 'none'),
        cache: _FakeCache(),
      ),
      wait: const Duration(milliseconds: 20),
      verify: (cubit) => expect(cubit.state.phase, ArViewerPhase.failed),
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'derives the model-viewer scale string from real dimensions',
      build: () => ArViewerCubit(
        product: _product(id: 'a', widthCm: 180, heightCm: 90, depthCm: 200),
        cache: _FakeCache(),
      ),
      wait: const Duration(milliseconds: 20),
      verify: (cubit) =>
          expect(cubit.state.selectedPart.scaleString, '1.8 0.9 2.0'),
    );
  });

  group('ArViewerCubit — furniture set', () {
    late _FakeCache cache;

    SetDetail buildSet(List<ProductModel> members) => SetDetail(
      info: const ProductSet(
        id: 's1',
        shopId: 'shop',
        sellerId: 'seller',
        name: 'Yotoqxona',
      ),
      items: members,
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'hydrates set siblings and keeps the opened product selected',
      build: () {
        final repo = _MockSetRepo();
        when(() => repo.fetchSet(any())).thenAnswer(
          (_) async => buildSet([
            _product(id: 'bed', name: 'Krovat', setId: 's1'),
            _product(id: 'wardrobe', name: 'Shkaf', setId: 's1'),
            _product(id: 'mirror', name: 'Tryumo', setId: 's1'),
          ]),
        );
        return ArViewerCubit(
          product: _product(id: 'wardrobe', name: 'Shkaf', setId: 's1'),
          cache: _FakeCache(),
          setRepository: repo,
        );
      },
      wait: const Duration(milliseconds: 30),
      verify: (cubit) {
        expect(cubit.state.parts.length, 3);
        expect(cubit.state.hasMultipleParts, isTrue);
        expect(cubit.state.selectedPart.id, 'wardrobe');
        expect(
          cubit.state.parts.map((p) => p.name),
          ['Krovat', 'Shkaf', 'Tryumo'],
        );
      },
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'skips set members without an approved model',
      build: () {
        final repo = _MockSetRepo();
        when(() => repo.fetchSet(any())).thenAnswer(
          (_) async => buildSet([
            _product(id: 'wardrobe', name: 'Shkaf', setId: 's1'),
            _product(
              id: 'rug',
              name: 'Gilam',
              hasModel: false,
              arStatus: 'none',
              setId: 's1',
            ),
          ]),
        );
        return ArViewerCubit(
          product: _product(id: 'wardrobe', name: 'Shkaf', setId: 's1'),
          cache: _FakeCache(),
          setRepository: repo,
        );
      },
      wait: const Duration(milliseconds: 30),
      // Only one model-bearing member remains → nothing to toggle, single part.
      verify: (cubit) => expect(cubit.state.hasMultipleParts, isFalse),
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'leaves the viewer single-part when the set fetch fails',
      build: () {
        final repo = _MockSetRepo();
        when(() => repo.fetchSet(any())).thenThrow(Exception('boom'));
        return ArViewerCubit(
          product: _product(id: 'wardrobe', setId: 's1'),
          cache: _FakeCache(),
          setRepository: repo,
        );
      },
      wait: const Duration(milliseconds: 30),
      verify: (cubit) => expect(cubit.state.parts.length, 1),
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'selectPart switches model, bumps the render token, downloads once',
      build: () {
        cache = _FakeCache();
        final repo = _MockSetRepo();
        when(() => repo.fetchSet(any())).thenAnswer(
          (_) async => buildSet([
            _product(id: 'bed', name: 'Krovat', setId: 's1'),
            _product(id: 'wardrobe', name: 'Shkaf', setId: 's1'),
          ]),
        );
        return ArViewerCubit(
          product: _product(id: 'bed', name: 'Krovat', setId: 's1'),
          cache: cache,
          setRepository: repo,
        );
      },
      act: (cubit) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await cubit.selectPart(1);
      },
      wait: const Duration(milliseconds: 20),
      verify: (cubit) {
        expect(cubit.state.selectedIndex, 1);
        expect(cubit.state.selectedPart.id, 'wardrobe');
        expect(cubit.state.phase, ArViewerPhase.rendering);
        expect(cubit.state.renderToken, greaterThan(0));
        // Each part downloaded exactly once (bed on open, wardrobe on switch).
        expect(
          cache.downloads.where((u) => u == 'https://cdn/wardrobe.glb').length,
          1,
        );
        expect(cache.downloads, contains('https://cdn/bed.glb'));
      },
    );

    blocTest<ArViewerCubit, ArViewerState>(
      're-tapping the active ready part is a no-op',
      build: () => ArViewerCubit(
        product: _product(id: 'a'),
        cache: _FakeCache(cached: {'https://cdn/a.glb'}),
      ),
      act: (cubit) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        cubit.onModelRendered();
        final tokenBefore = cubit.state.renderToken;
        await cubit.selectPart(0);
        expect(cubit.state.renderToken, tokenBefore);
      },
      wait: const Duration(milliseconds: 20),
      verify: (cubit) => expect(cubit.state.phase, ArViewerPhase.ready),
    );
  });

  group('ArViewerCubit — multi-part product', () {
    blocTest<ArViewerCubit, ArViewerState>(
      'hydrates the product own parts and keeps the primary selected',
      build: () => ArViewerCubit(
        // The primary model URL mirrors the 'bed' part, so that part stays
        // selected after hydration.
        product: _product(
          id: 'bed',
          arParts: [_part('bed'), _part('wardrobe')],
        ),
        cache: _FakeCache(),
      ),
      wait: const Duration(milliseconds: 20),
      verify: (cubit) {
        expect(cubit.state.hasMultipleParts, isTrue);
        expect(cubit.state.parts.map((p) => p.name), ['bed', 'wardrobe']);
        expect(cubit.state.selectedPart.name, 'bed');
      },
    );

    blocTest<ArViewerCubit, ArViewerState>(
      'a single part leaves the viewer without a selector',
      build: () => ArViewerCubit(
        product: _product(id: 'bed', arParts: [_part('bed')]),
        cache: _FakeCache(),
      ),
      wait: const Duration(milliseconds: 20),
      verify: (cubit) => expect(cubit.state.hasMultipleParts, isFalse),
    );
  });
}

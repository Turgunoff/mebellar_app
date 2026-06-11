import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/favorites/bloc/favorites_bloc.dart';
import 'package:woody_app/shared/models/product.dart';
import 'package:woody_app/shared/repositories/favorites_repository.dart';
import '../../../../fixtures/mocks/mock/mock_data.dart';
import '../../../../fixtures/mocks/mock/mock_favorites_repository.dart';

/// Counts `list()` calls and fails every `toggle()` — exercises the
/// optimistic-rollback and auth-refetch paths without a network.
class _FailingToggleRepo implements FavoritesRepository {
  final _controller = StreamController<Set<String>>.broadcast();
  int listCalls = 0;

  Future<void> close() => _controller.close();

  @override
  Stream<Set<String>> watchIds() => _controller.stream;

  @override
  Set<String> get currentIds => const {};

  @override
  bool isFavorite(String productId) => false;

  @override
  Future<List<Product>> list() async {
    listCalls++;
    return const [];
  }

  @override
  Future<void> toggle(Product product) async => throw Exception('network down');

  @override
  Future<void> remove(String productId) async {}
}

void main() {
  group('FavoritesBloc (mock repository)', () {
    blocTest<FavoritesBloc, FavoritesState>(
      'initial fetch -> empty list',
      build: () => FavoritesBloc(MockFavoritesRepository()),
      act: (bloc) => bloc.add(const FavoritesRequested()),
      wait: const Duration(milliseconds: 400),
      skip: 1,
      expect: () => [
        isA<FavoritesState>()
            .having((s) => s.status, 'status', FavoritesStatus.ready)
            .having((s) => s.products, 'products', isEmpty),
      ],
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'toggle -> adds id then removes it',
      build: () => FavoritesBloc(MockFavoritesRepository()),
      act: (bloc) async {
        final p = MockData.products.first;
        bloc.add(const FavoritesRequested());
        await Future<void>.delayed(const Duration(milliseconds: 250));
        bloc.add(FavoriteToggled(p));
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(bloc.state.ids.contains(p.id), isTrue);
        bloc.add(FavoriteToggled(p));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      verify: (bloc) {
        expect(bloc.state.ids, isEmpty);
      },
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'remove -> drops product from list',
      build: () => FavoritesBloc(MockFavoritesRepository()),
      act: (bloc) async {
        final p = MockData.products.first;
        bloc.add(const FavoritesRequested());
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(FavoriteToggled(p));
        // Allow toggle (toggle + list reload) to settle: each repo call adds
        // ~180ms of mock delay, so 600ms is comfortably enough.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        bloc.add(FavoriteRemoved(p.id));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      verify: (bloc) {
        expect(bloc.state.ids.contains(MockData.products.first.id), isFalse);
        expect(bloc.state.products, isEmpty);
      },
    );

    test('a failed toggle rolls the optimistic heart back', () async {
      final repo = _FailingToggleRepo();
      final bloc = FavoritesBloc(repo);
      final p = MockData.products.first;

      bloc.add(FavoriteToggled(p));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        bloc.state.ids.contains(p.id),
        isFalse,
        reason: 'the heart must not stay filled after a failed save',
      );
      expect(bloc.state.error, isNotNull);

      await bloc.close();
      await repo.close();
    });

    test('an auth flip triggers a refetch; repeats are deduped', () async {
      final repo = _FailingToggleRepo();
      final auth = StreamController<bool>.broadcast();
      final bloc = FavoritesBloc(repo, authChanges: auth.stream);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final before = repo.listCalls;

      auth.add(true); // login
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.listCalls, before + 1);

      auth.add(true); // token refresh — same state, must be deduped
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.listCalls, before + 1);

      auth.add(false); // logout — the tab must empty via a refetch
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.listCalls, before + 2);

      await bloc.close();
      await auth.close();
      await repo.close();
    });
  });
}

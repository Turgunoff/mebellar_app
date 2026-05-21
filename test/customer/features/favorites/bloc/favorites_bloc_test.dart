import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/favorites/bloc/favorites_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_data.dart';
import '../../../../fixtures/mocks/mock/mock_favorites_repository.dart';

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
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/search/bloc/search_bloc.dart';
import 'package:woody_app/shared/models/supabase_product_model.dart';
import 'package:woody_app/shared/repositories/supabase_product_data_source.dart';

class _MockProductSource extends Mock implements SupabaseProductDataSource {}

class _MockBox extends Mock implements Box {}

SupabaseProductModel _sp(String id) => SupabaseProductModel(
      id: id,
      categoryId: 'cat-1',
      name: 'Product $id',
      price: 100000,
      images: const [],
      stock: 5,
      createdAt: DateTime.utc(2026, 5, 16),
    );

// The query-changed handler is debounced by 300ms; tests must outwait it.
const _afterDebounce = Duration(milliseconds: 360);

void main() {
  late _MockProductSource source;
  late _MockBox box;

  setUp(() {
    source = _MockProductSource();
    box = _MockBox();
    when(() => box.get('search_recent')).thenReturn(null);
    when(() => box.put(any<dynamic>(), any<dynamic>()))
        .thenAnswer((_) async {});
    when(() => box.delete(any<dynamic>())).thenAnswer((_) async {});
  });

  SearchBloc build() => SearchBloc(source: source, cacheBox: box);

  blocTest<SearchBloc, SearchState>(
    'SearchQueryChanged debounces then emits [loading, ready]',
    build: () {
      when(() => source.search(any()))
          .thenAnswer((_) async => [_sp('a'), _sp('b')]);
      return build();
    },
    act: (bloc) => bloc.add(const SearchQueryChanged('stol')),
    wait: _afterDebounce,
    expect: () => [
      isA<SearchState>()
          .having((s) => s.status, 'status', SearchStatus.loading)
          .having((s) => s.query, 'query', 'stol'),
      isA<SearchState>()
          .having((s) => s.status, 'status', SearchStatus.ready)
          .having((s) => s.results.length, 'results', 2),
    ],
  );

  blocTest<SearchBloc, SearchState>(
    'SearchQueryChanged emits [loading, failure] when the search throws',
    build: () {
      when(() => source.search(any())).thenThrow(Exception('search down'));
      return build();
    },
    act: (bloc) => bloc.add(const SearchQueryChanged('stol')),
    wait: _afterDebounce,
    expect: () => [
      isA<SearchState>()
          .having((s) => s.status, 'status', SearchStatus.loading),
      isA<SearchState>()
          .having((s) => s.status, 'status', SearchStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<SearchBloc, SearchState>(
    'SearchSubmitted prepends the query to recent history and persists it',
    build: build,
    act: (bloc) => bloc.add(const SearchSubmitted('divan')),
    expect: () => [
      isA<SearchState>().having((s) => s.recent, 'recent', ['divan']),
    ],
    verify: (_) {
      verify(() => box.put('search_recent', ['divan'])).called(1);
    },
  );

  blocTest<SearchBloc, SearchState>(
    'SearchHistoryCleared empties recent history and clears the cache',
    build: build,
    seed: () => const SearchState(recent: ['divan', 'stol']),
    act: (bloc) => bloc.add(const SearchHistoryCleared()),
    expect: () => [
      isA<SearchState>().having((s) => s.recent, 'recent', isEmpty),
    ],
    verify: (_) {
      verify(() => box.delete('search_recent')).called(1);
    },
  );
}

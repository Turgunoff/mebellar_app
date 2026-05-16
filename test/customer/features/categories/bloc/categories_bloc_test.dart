import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/categories/bloc/categories_bloc.dart';
import 'package:woody_app/shared/models/category_model.dart';
import 'package:woody_app/shared/repositories/supabase_category_repository.dart';

class _MockCategorySource extends Mock implements CategoryDataSource {}

CategoryModel _cat(String id) =>
    CategoryModel(id: id, name: 'Category $id', sortOrder: 0);

void main() {
  late _MockCategorySource source;

  setUp(() => source = _MockCategorySource());

  blocTest<CategoriesBloc, CategoriesState>(
    'emits [loading, ready] when the source returns categories',
    build: () {
      when(source.list).thenAnswer((_) async => [_cat('a'), _cat('b')]);
      return CategoriesBloc(source);
    },
    act: (bloc) => bloc.add(const CategoriesRequested()),
    expect: () => [
      isA<CategoriesState>()
          .having((s) => s.status, 'status', CategoriesStatus.loading),
      isA<CategoriesState>()
          .having((s) => s.status, 'status', CategoriesStatus.ready)
          .having((s) => s.categories.length, 'count', 2)
          .having((s) => s.error, 'error', isNull),
    ],
  );

  blocTest<CategoriesBloc, CategoriesState>(
    'emits [loading, failure] when the source throws',
    build: () {
      when(source.list).thenThrow(Exception('network down'));
      return CategoriesBloc(source);
    },
    act: (bloc) => bloc.add(const CategoriesRequested()),
    expect: () => [
      isA<CategoriesState>()
          .having((s) => s.status, 'status', CategoriesStatus.loading),
      isA<CategoriesState>()
          .having((s) => s.status, 'status', CategoriesStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<CategoriesBloc, CategoriesState>(
    'a failed load followed by a successful retry recovers to ready',
    build: () {
      var attempt = 0;
      when(source.list).thenAnswer((_) async {
        if (attempt++ == 0) throw Exception('first attempt fails');
        return [_cat('a')];
      });
      return CategoriesBloc(source);
    },
    act: (bloc) async {
      bloc.add(const CategoriesRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const CategoriesRequested());
    },
    skip: 3,
    expect: () => [
      isA<CategoriesState>()
          .having((s) => s.status, 'status', CategoriesStatus.ready)
          .having((s) => s.categories.length, 'count', 1),
    ],
  );
}

import 'package:woody_app/shared/models/category.dart';
import 'package:woody_app/shared/repositories/category_repository.dart';
import 'mock_data.dart';

class MockCategoryRepository implements CategoryRepository {
  static const _delay = Duration(milliseconds: 200);

  @override
  Future<List<Category>> tree() async {
    await Future<void>.delayed(_delay);
    return MockData.categoriesTree;
  }

  @override
  Future<Category> getBySlug(String slug) async {
    await Future<void>.delayed(_delay);
    final cat = MockData.categoryBySlug(slug);
    if (cat == null) throw StateError('Category not found: $slug');
    return cat;
  }
}

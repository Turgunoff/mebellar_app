import '../../core/network/woody_api_client.dart';
import '../models/category_model.dart';
import 'category_data_source.dart' show CategoryDataSource;

/// Calls `/catalog/categories` which
/// returns the same flat-row + embedded `subcategories` shape PostgREST
/// produced — `CategoryModel.fromJson` parses both transports unchanged.
class WoodyCategoryRepository extends CategoryDataSource {
  WoodyCategoryRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<List<CategoryModel>> list() async {
    final rows = await _api.get<List<dynamic>>('/catalog/categories');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList(growable: false);
  }
}

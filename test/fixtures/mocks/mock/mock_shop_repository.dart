import '../models/paginated.dart';
import '../models/shop.dart';
import '../repositories/shop_repository.dart';
import 'mock_data.dart';

class MockShopRepository implements ShopRepository {
  static const _delay = Duration(milliseconds: 200);

  @override
  Future<Paginated<Shop>> list({
    bool? featured,
    int page = 1,
    int perPage = 20,
  }) async {
    await Future<void>.delayed(_delay);
    var items = List<Shop>.from(MockData.shops);
    if (featured == true) {
      items = items.where((s) => s.isVerified).toList();
    }

    final total = items.length;
    final start = (page - 1) * perPage;
    final end = (start + perPage).clamp(0, total);
    final pageItems = start >= total ? <Shop>[] : items.sublist(start, end);

    return Paginated(
      items: pageItems,
      page: page,
      perPage: perPage,
      total: total,
      hasNext: end < total,
    );
  }

  @override
  Future<Shop> getBySlug(String slug) async {
    await Future<void>.delayed(_delay);
    final shop = MockData.shops.where((s) => s.slug == slug).firstOrNull;
    if (shop == null) throw StateError('Shop not found: $slug');
    return shop;
  }
}

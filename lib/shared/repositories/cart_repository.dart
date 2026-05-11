import 'package:dio/dio.dart';

import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/cart_item_model.dart';
import '../models/supabase_product_model.dart';

/// Cart storage contract.
///
/// Two complementary APIs live here so the Sprint 4 checkout flow (which
/// works on the rich [Cart]/[CartItem] graph including shop info) and the
/// Sprint-12 Hive+Supabase hybrid cart (which works on flat
/// [CartItemModel] snapshots) share one repository slot.
///
/// New code should prefer the snapshot API (`watchItems`, `addProduct`,
/// `updateProductQuantity`, `removeProduct`). The legacy [Cart]-shaped API
/// stays for the existing checkout pipeline.
abstract class CartRepository {
  // ── Legacy [Cart] API — used by CheckoutBloc and the Sprint 4 mock flow.

  Stream<Cart> watch();
  Cart get current;

  Future<Cart> fetch();
  Future<Cart> addItem(String productId, {int quantity = 1});
  Future<Cart> updateQuantity(String itemId, int quantity);
  Future<Cart> removeItem(String itemId);
  Future<Cart> clear();

  // ── Snapshot API — used by the new CartBloc / hybrid (Hive + Supabase).
  //
  // Default implementations route to the legacy API so older repositories
  // (Mock, Remote) keep working without forced overrides. The new
  // Hive/Supabase/Hybrid repositories override these to operate on the
  // snapshot rows directly.

  Stream<List<CartItemModel>> watchItems() =>
      const Stream<List<CartItemModel>>.empty();

  List<CartItemModel> get currentItems => const [];

  Future<List<CartItemModel>> fetchItems() async => const [];

  Future<void> addProduct(
    SupabaseProductModel product, {
    int quantity = 1,
  }) async {
    await addItem(product.id, quantity: quantity);
  }

  Future<void> updateProductQuantity(String productId, int newQuantity) async {
    await updateQuantity(productId, newQuantity);
  }

  Future<void> removeProduct(String productId) async {
    await removeItem(productId);
  }
}

/// Real backend implementation. Sprint 4 keeps the mock variant the default;
/// flip `AppConfig.useMocks` to false once the API endpoints land.
class RemoteCartRepository implements CartRepository {
  RemoteCartRepository(this._dio);

  final Dio _dio;
  Cart _cart = const Cart();

  @override
  Cart get current => _cart;

  @override
  Stream<Cart> watch() => Stream<Cart>.empty();

  @override
  Future<Cart> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/v1/cart');
    final items = (res.data?['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CartItem.fromJson)
        .toList();
    _cart = Cart(items: items);
    return _cart;
  }

  @override
  Future<Cart> addItem(String productId, {int quantity = 1}) async {
    await _dio.post<dynamic>(
      '/api/v1/cart/items',
      data: {'product_id': productId, 'quantity': quantity},
    );
    return fetch();
  }

  @override
  Future<Cart> updateQuantity(String itemId, int quantity) async {
    await _dio.patch<dynamic>(
      '/api/v1/cart/items/$itemId',
      data: {'quantity': quantity},
    );
    return fetch();
  }

  @override
  Future<Cart> removeItem(String itemId) async {
    await _dio.delete<dynamic>('/api/v1/cart/items/$itemId');
    return fetch();
  }

  @override
  Future<Cart> clear() async {
    await _dio.delete<dynamic>('/api/v1/cart');
    _cart = const Cart();
    return _cart;
  }

  // Snapshot API stubs — the legacy remote backend doesn't expose a
  // snapshot view. New CartBloc deployments use the Hybrid repository
  // instead, so these only matter if useMocks=false AND Supabase is unset
  // (currently impossible in production).

  @override
  Stream<List<CartItemModel>> watchItems() =>
      const Stream<List<CartItemModel>>.empty();

  @override
  List<CartItemModel> get currentItems => const [];

  @override
  Future<List<CartItemModel>> fetchItems() async => const [];

  @override
  Future<void> addProduct(
    SupabaseProductModel product, {
    int quantity = 1,
  }) async {
    await addItem(product.id, quantity: quantity);
  }

  @override
  Future<void> updateProductQuantity(String productId, int newQuantity) async {
    await updateQuantity(productId, newQuantity);
  }

  @override
  Future<void> removeProduct(String productId) async {
    await removeItem(productId);
  }
}

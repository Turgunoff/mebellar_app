
import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

/// Cart storage contract.
///
/// Two complementary APIs live here so the Sprint 4 checkout flow (which
/// works on the rich [Cart]/[CartItem] graph including shop info) and the
/// Sprint-12 Hive+backend hybrid cart (which works on flat
/// [CartItemModel] snapshots) share one repository slot.
///
/// New code should prefer the snapshot API (`watchItems`, `addProduct`,
/// `updateProductQuantity`, `removeProduct`). The legacy [Cart]-shaped API
/// stays for the existing checkout pipeline.
abstract class CartRepository {
  // ── Legacy [Cart]-shaped API (kept for compatibility).

  Stream<Cart> watch();
  Cart get current;

  Future<Cart> fetch();
  Future<Cart> addItem(String productId, {int quantity = 1});
  Future<Cart> updateQuantity(String itemId, int quantity);
  Future<Cart> removeItem(String itemId);
  Future<Cart> clear();

  // ── Snapshot API — used by the new CartBloc / hybrid (Hive + backend).
  //
  // Default implementations route to the legacy API so older repositories
  // (Mock, Remote) keep working without forced overrides. The new
  // Hive/backend/Hybrid repositories override these to operate on the
  // snapshot rows directly.

  Stream<List<CartItemModel>> watchItems() =>
      const Stream<List<CartItemModel>>.empty();

  List<CartItemModel> get currentItems => const [];

  Future<List<CartItemModel>> fetchItems() async => const [];

  Future<void> addProduct(
    ProductModel product, {
    int quantity = 1,
    String? selectedColor,
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

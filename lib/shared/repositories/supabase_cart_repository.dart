import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/cart_item_model.dart';
import '../models/multilingual_text.dart';
import '../models/product.dart';
import '../models/supabase_product_model.dart';
import 'cart_repository.dart';

/// Supabase-backed cart store for authenticated users.
///
/// Reads and writes to `public.cart_items`, which is protected by RLS so
/// each user can only access their own rows. Quantity is summed when the
/// same product is upserted twice (`addProduct` reads the existing row
/// first to decide between insert and increment).
class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository({required SupabaseClient supabase})
    : _supabase = supabase;

  final SupabaseClient _supabase;

  List<CartItemModel> _items = const [];
  Cart _legacyCart = const Cart();

  final _itemsController = StreamController<List<CartItemModel>>.broadcast();
  final _cartController = StreamController<Cart>.broadcast();

  String get _userId => _supabase.auth.currentUser!.id;

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setItems(List<CartItemModel> next) {
    _items = next;
    _legacyCart = Cart(items: next.map(_toCartItem).toList(growable: false));
    _itemsController.add(List<CartItemModel>.unmodifiable(_items));
    _cartController.add(_legacyCart);
  }

  CartItem _toCartItem(CartItemModel m) {
    return CartItem(
      id: m.id,
      product: Product(
        id: m.productId,
        slug: m.productId,
        name: MultilingualText(uz: m.productName),
        price: m.productPrice,
        primaryImage: m.productImage.isEmpty ? null : m.productImage,
        images: m.productImage.isEmpty ? const [] : [m.productImage],
      ),
      quantity: m.quantity,
    );
  }

  /// Drop the in-memory cache. Called from the hybrid layer on sign-out so
  /// the next user lands on a fresh state.
  void clearCache() {
    _setItems(const []);
  }

  // ── CartRepository — snapshot API ─────────────────────────────────────

  @override
  Stream<List<CartItemModel>> watchItems() => _itemsController.stream;

  @override
  List<CartItemModel> get currentItems =>
      List<CartItemModel>.unmodifiable(_items);

  @override
  Future<List<CartItemModel>> fetchItems() async {
    if (_supabase.auth.currentUser == null) {
      _setItems(const []);
      return const [];
    }
    final rows = await _supabase
        .from('cart_items')
        .select('id, product_id, quantity, product_snapshot, created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: true);
    final next = rows
        .whereType<Map<String, dynamic>>()
        .map(CartItemModel.fromJson)
        .toList(growable: false);
    _setItems(next);
    return currentItems;
  }

  @override
  Future<void> addProduct(
    SupabaseProductModel product, {
    int quantity = 1,
    String? selectedColor,
  }) async {
    final qty = quantity.clamp(1, 99);
    // Read the existing row first so we can sum quantities deterministically.
    final existing = await _supabase
        .from('cart_items')
        .select('id, quantity')
        .eq('user_id', _userId)
        .eq('product_id', product.id)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('cart_items').insert({
        'user_id': _userId,
        'product_id': product.id,
        'quantity': qty,
        'product_snapshot': CartItemModel.fromProduct(
          product,
          quantity: qty,
          selectedColor: selectedColor,
        ).toSnapshotJson(),
      });
    } else {
      final newQty = ((existing['quantity'] as num?)?.toInt() ?? 0) + qty;
      await _supabase
          .from('cart_items')
          .update({
            'quantity': newQty.clamp(1, 99),
            // Rewrite the snapshot so the latest colour pick wins.
            'product_snapshot': CartItemModel.fromProduct(
              product,
              quantity: newQty,
              selectedColor: selectedColor,
            ).toSnapshotJson(),
          })
          .eq('id', existing['id'] as Object);
    }

    await fetchItems();
  }

  @override
  Future<void> updateProductQuantity(String productId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeProduct(productId);
      return;
    }
    await _supabase
        .from('cart_items')
        .update({'quantity': newQuantity.clamp(1, 99)})
        .eq('user_id', _userId)
        .eq('product_id', productId);
    await fetchItems();
  }

  @override
  Future<void> removeProduct(String productId) async {
    await _supabase
        .from('cart_items')
        .delete()
        .eq('user_id', _userId)
        .eq('product_id', productId);
    await fetchItems();
  }

  // ── CartRepository — legacy [Cart] API ────────────────────────────────

  @override
  Stream<Cart> watch() => _cartController.stream;

  @override
  Cart get current => _legacyCart;

  @override
  Future<Cart> fetch() async {
    await fetchItems();
    return _legacyCart;
  }

  @override
  Future<Cart> addItem(String productId, {int quantity = 1}) async {
    // Falls back to the snapshot API by hydrating a minimal record. The new
    // CartBloc never reaches this — it always has a SupabaseProductModel in
    // hand and uses [addProduct] directly. Kept for legacy CheckoutBloc
    // compat.
    await updateProductQuantity(
      productId,
      ((_items
                  .firstWhere(
                    (it) => it.productId == productId,
                    orElse: () => CartItemModel(
                      id: productId,
                      productId: productId,
                      productName: '',
                      productImage: '',
                      productPrice: 0,
                      quantity: 0,
                    ),
                  )
                  .quantity) +
              quantity)
          .clamp(1, 99),
    );
    return _legacyCart;
  }

  @override
  Future<Cart> updateQuantity(String itemId, int quantity) async {
    // The legacy interface keys by `itemId` (cart row id). Resolve to a
    // productId by scanning the cached snapshot — the hybrid path uses the
    // snapshot API directly so this is only relevant during checkout
    // post-success cleanup.
    final match = _items.firstWhere(
      (it) => it.id == itemId,
      orElse: () => CartItemModel(
        id: itemId,
        productId: itemId,
        productName: '',
        productImage: '',
        productPrice: 0,
        quantity: 0,
      ),
    );
    await updateProductQuantity(match.productId, quantity);
    return _legacyCart;
  }

  @override
  Future<Cart> removeItem(String itemId) async {
    final match = _items.firstWhere(
      (it) => it.id == itemId,
      orElse: () => CartItemModel(
        id: itemId,
        productId: itemId,
        productName: '',
        productImage: '',
        productPrice: 0,
        quantity: 0,
      ),
    );
    await removeProduct(match.productId);
    return _legacyCart;
  }

  @override
  Future<Cart> clear() async {
    if (_supabase.auth.currentUser == null) {
      _setItems(const []);
      return _legacyCart;
    }
    await _supabase.from('cart_items').delete().eq('user_id', _userId);
    _setItems(const []);
    return _legacyCart;
  }

  Future<void> dispose() async {
    await _itemsController.close();
    await _cartController.close();
  }
}

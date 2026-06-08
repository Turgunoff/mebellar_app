import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/cart_item_model.dart';
import '../models/multilingual_text.dart';
import '../models/product.dart';
import '../models/product_model.dart';
import 'cart_repository.dart';

/// Local, Hive-backed cart for signed-out (guest) sessions.
///
/// Holds the same [CartItemModel] snapshot rows the backend cart uses, so the
/// guest cart merges into the server cart on login with a straight replay (see
/// [HybridCartRepository]). The whole list is persisted under a single box key
/// — the cart is tiny, so rewriting it on every mutation is cheaper than
/// per-row bookkeeping.
class HiveCartRepository implements CartRepository {
  HiveCartRepository({required Box box}) : _box = box {
    _items = _load();
  }

  final Box _box;
  static const String _key = 'items';

  List<CartItemModel> _items = const [];
  final _itemsController = StreamController<List<CartItemModel>>.broadcast();
  final _cartController = StreamController<Cart>.broadcast();

  List<CartItemModel> _load() {
    final raw = _box.get(_key);
    if (raw is! List) return const [];
    return raw
        .map((e) => CartItemModel.fromJson(_asStringMap(e)))
        .toList(growable: false);
  }

  Future<void> _save() async {
    await _box.put(_key, _items.map((e) => e.toHiveJson()).toList());
  }

  void _emit() {
    _itemsController.add(List<CartItemModel>.unmodifiable(_items));
    _cartController.add(_legacyCart);
  }

  Cart get _legacyCart =>
      Cart(items: _items.map(_toCartItem).toList(growable: false));

  CartItem _toCartItem(CartItemModel m) => CartItem(
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

  // ── Snapshot API ──────────────────────────────────────────────────────────

  @override
  Stream<List<CartItemModel>> watchItems() => _itemsController.stream;

  @override
  List<CartItemModel> get currentItems =>
      List<CartItemModel>.unmodifiable(_items);

  @override
  Future<List<CartItemModel>> fetchItems() async {
    _emit();
    return currentItems;
  }

  @override
  Future<void> addProduct(
    ProductModel product, {
    int quantity = 1,
    String? selectedColor,
  }) async {
    final qty = quantity.clamp(1, 99);
    final idx = _items.indexWhere((it) => it.productId == product.id);
    if (idx >= 0) {
      final existing = _items[idx];
      _items = List<CartItemModel>.of(_items)
        ..[idx] = existing.copyWith(
          quantity: (existing.quantity + qty).clamp(1, 99),
          selectedColor: selectedColor ?? existing.selectedColor,
        );
    } else {
      _items = [
        ..._items,
        CartItemModel.fromProduct(
          product,
          quantity: qty,
          selectedColor: selectedColor,
        ),
      ];
    }
    await _save();
    _emit();
  }

  @override
  Future<void> updateProductQuantity(String productId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeProduct(productId);
      return;
    }
    final qty = newQuantity.clamp(1, 99);
    _items = [
      for (final it in _items)
        if (it.productId == productId) it.copyWith(quantity: qty) else it,
    ];
    await _save();
    _emit();
  }

  @override
  Future<void> removeProduct(String productId) async {
    _items = _items.where((it) => it.productId != productId).toList();
    await _save();
    _emit();
  }

  // ── Legacy [Cart] API ─────────────────────────────────────────────────────
  // Only `clear()` is exercised on the guest path (checkout/cart-bloc); the
  // rest stay functional for interface completeness.

  @override
  Stream<Cart> watch() => _cartController.stream;

  @override
  Cart get current => _legacyCart;

  @override
  Future<Cart> fetch() async {
    _emit();
    return _legacyCart;
  }

  @override
  Future<Cart> addItem(String productId, {int quantity = 1}) async {
    // The snapshot `addProduct` is the real entry point — guests always add via
    // a full ProductModel, so a bare id can't reconstruct a snapshot here.
    return _legacyCart;
  }

  @override
  Future<Cart> updateQuantity(String itemId, int quantity) async {
    await updateProductQuantity(itemId, quantity);
    return _legacyCart;
  }

  @override
  Future<Cart> removeItem(String itemId) async {
    await removeProduct(itemId);
    return _legacyCart;
  }

  @override
  Future<Cart> clear() async {
    _items = const [];
    await _save();
    _emit();
    return _legacyCart;
  }

  Future<void> dispose() async {
    await _itemsController.close();
    await _cartController.close();
  }
}

/// Hive returns nested maps as `Map<dynamic, dynamic>`; deep-cast them to
/// `Map<String, dynamic>` so `CartItemModel.fromJson`'s typed `is` checks
/// (e.g. on `product_snapshot`) match instead of silently dropping the row.
Map<String, dynamic> _asStringMap(Object? raw) {
  if (raw is! Map) return const <String, dynamic>{};
  return raw.map(
    (k, v) => MapEntry(k.toString(), v is Map ? _asStringMap(v) : v),
  );
}

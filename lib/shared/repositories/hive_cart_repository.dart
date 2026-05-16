import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:woody_app/core/logging/talker.dart';

import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/cart_item_model.dart';
import '../models/multilingual_text.dart';
import '../models/product.dart';
import '../models/supabase_product_model.dart';
import 'cart_repository.dart';

/// Local Hive-backed cart store used for guest (unauthenticated) sessions.
///
/// Storage shape: a single `guest_cart` key holding `{productId: jsonString}`
/// where `jsonString` is a [CartItemModel] payload. Same map-of-snapshots
/// pattern as [HiveFavoritesRepository] so the two stores stay coherent.
class HiveCartRepository implements CartRepository {
  HiveCartRepository(this._box) {
    // Seed the broadcast stream with the persisted state so any subscriber
    // that listens after construction (e.g. CartBloc) receives an initial
    // snapshot without having to call `fetchItems` first.
    Future<void>.microtask(() => _emit());
  }

  final Box _box;

  static const String _storeKey = 'guest_cart';

  final _itemsController =
      StreamController<List<CartItemModel>>.broadcast();
  final _cartController = StreamController<Cart>.broadcast();

  Cart _legacyCart = const Cart();

  // ── Internal helpers ─────────────────────────────────────────────────────

  Map<String, String> _readStore() {
    final raw = _box.get(_storeKey);
    if (raw is Map) {
      return Map.fromEntries(
        raw.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
    }
    return {};
  }

  Future<void> _writeStore(Map<String, String> store) async {
    if (store.isEmpty) {
      await _box.delete(_storeKey);
    } else {
      await _box.put(_storeKey, store);
    }
    _emit();
  }

  void _emit() {
    final items = currentItems;
    _itemsController.add(items);
    _legacyCart = Cart(items: items.map(_toCartItem).toList(growable: false));
    _cartController.add(_legacyCart);
  }

  /// Convert a snapshot to the legacy [CartItem] type so the existing
  /// CheckoutBloc can keep grouping by shop. Shop info is unknown for
  /// snapshot rows, so the fallback Product carries `shop = null` — the
  /// checkout review step will collapse those into a single "Other" group.
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

  // ── Hive-only helpers used by the Hybrid layer for the sign-in sync ───

  /// Return a copy of every locally-stored cart row.
  List<CartItemModel> readAll() => currentItems;

  /// Wipe the local cart box. Called from the hybrid repository after a
  /// successful sync to Supabase on login.
  Future<void> clearLocal() async {
    await _box.delete(_storeKey);
    _emit();
  }

  // ── CartRepository — snapshot API ─────────────────────────────────────

  @override
  Stream<List<CartItemModel>> watchItems() => _itemsController.stream;

  @override
  List<CartItemModel> get currentItems {
    return _readStore().values
        .map((jsonStr) {
          try {
            final raw = jsonDecode(jsonStr) as Map<String, dynamic>;
            return CartItemModel.fromJson(raw);
          } catch (e, st) {
            talker.handle(e, st, 'HiveCart.currentItems: corrupt row');
            return null;
          }
        })
        .whereType<CartItemModel>()
        .toList(growable: false);
  }

  @override
  Future<List<CartItemModel>> fetchItems() async => currentItems;

  @override
  Future<void> addProduct(
    SupabaseProductModel product, {
    int quantity = 1,
  }) async {
    final store = _readStore();
    final existingJson = store[product.id];
    final qtyClamped = quantity.clamp(1, 99);

    if (existingJson != null) {
      try {
        final existing = CartItemModel.fromJson(
          jsonDecode(existingJson) as Map<String, dynamic>,
        );
        final next = existing.copyWith(
          quantity: (existing.quantity + qtyClamped).clamp(1, 99),
        );
        store[product.id] = jsonEncode(next.toHiveJson());
      } catch (e, st) {
        talker.handle(e, st, 'HiveCart.addProduct: re-seeding corrupt row');
        store[product.id] = jsonEncode(
          CartItemModel.fromProduct(product, quantity: qtyClamped)
              .toHiveJson(),
        );
      }
    } else {
      store[product.id] = jsonEncode(
        CartItemModel.fromProduct(product, quantity: qtyClamped).toHiveJson(),
      );
    }

    await _writeStore(store);
  }

  @override
  Future<void> updateProductQuantity(
    String productId,
    int newQuantity,
  ) async {
    final store = _readStore();
    final json = store[productId];
    if (json == null) return;
    if (newQuantity <= 0) {
      store.remove(productId);
    } else {
      try {
        final current = CartItemModel.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        store[productId] = jsonEncode(
          current.copyWith(quantity: newQuantity.clamp(1, 99)).toHiveJson(),
        );
      } catch (e, st) {
        talker.handle(e, st, 'HiveCart.updateProductQuantity: corrupt row');
        store.remove(productId);
      }
    }
    await _writeStore(store);
  }

  @override
  Future<void> removeProduct(String productId) async {
    final store = _readStore();
    store.remove(productId);
    await _writeStore(store);
  }

  // ── CartRepository — legacy [Cart] API ────────────────────────────────

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
    // Cannot synthesize a SupabaseProductModel from just an id without a
    // round-trip; callers should use [addProduct] directly. Preserve the
    // signature so older code paths don't crash, but no-op in the
    // guest-only repository.
    final store = _readStore();
    final json = store[productId];
    if (json == null) return _legacyCart;
    try {
      final current = CartItemModel.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      store[productId] = jsonEncode(
        current
            .copyWith(quantity: (current.quantity + quantity).clamp(1, 99))
            .toHiveJson(),
      );
      await _writeStore(store);
    } catch (e, st) {
      talker.handle(e, st, 'HiveCart.addItem: corrupt row');
    }
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
    await clearLocal();
    return _legacyCart;
  }

  Future<void> dispose() async {
    await _itemsController.close();
    await _cartController.close();
  }
}

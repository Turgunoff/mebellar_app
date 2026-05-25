import 'dart:async';

import 'package:woody_app/shared/models/cart.dart';
import 'package:woody_app/shared/models/cart_item.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';
import 'package:woody_app/shared/models/supabase_product_model.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';
import 'mock_data.dart';

/// In-memory cart used while the backend is not wired up. Items are looked up
/// by `productId` from [MockData.products] so adds are believable. The
/// repository broadcasts updates via [watch] so multiple BLoC instances stay
/// in sync (e.g. cart badge in the bottom nav vs cart screen body).
class MockCartRepository implements CartRepository {
  static const _delay = Duration(milliseconds: 200);

  final _controller = StreamController<Cart>.broadcast();
  Cart _cart = const Cart();
  int _idCounter = 0;

  @override
  Cart get current => _cart;

  @override
  Stream<Cart> watch() => _controller.stream;

  @override
  Future<Cart> fetch() async {
    await Future<void>.delayed(_delay);
    return _cart;
  }

  @override
  Future<Cart> addItem(String productId, {int quantity = 1}) async {
    await Future<void>.delayed(_delay);
    final product = MockData.products
        .where((p) => p.id == productId || p.slug == productId)
        .firstOrNull;
    if (product == null) {
      throw StateError('Mahsulot topilmadi: $productId');
    }

    final existingIndex =
        _cart.items.indexWhere((it) => it.product.id == product.id);
    final next = List<CartItem>.from(_cart.items);
    if (existingIndex >= 0) {
      final existing = next[existingIndex];
      final newQty = (existing.quantity + quantity).clamp(1, 99);
      next[existingIndex] = existing.copyWith(quantity: newQty);
    } else {
      _idCounter += 1;
      next.add(CartItem(
        id: 'cart-item-$_idCounter',
        product: product,
        quantity: quantity.clamp(1, 99),
      ));
    }
    _cart = Cart(items: next);
    _controller.add(_cart);
    return _cart;
  }

  @override
  Future<Cart> updateQuantity(String itemId, int quantity) async {
    await Future<void>.delayed(_delay);
    final idx = _cart.items.indexWhere((it) => it.id == itemId);
    if (idx < 0) return _cart;
    final next = List<CartItem>.from(_cart.items);
    if (quantity <= 0) {
      next.removeAt(idx);
    } else {
      next[idx] = next[idx].copyWith(quantity: quantity.clamp(1, 99));
    }
    _cart = Cart(items: next);
    _controller.add(_cart);
    return _cart;
  }

  @override
  Future<Cart> removeItem(String itemId) async {
    await Future<void>.delayed(_delay);
    final next = _cart.items.where((it) => it.id != itemId).toList();
    _cart = Cart(items: next);
    _controller.add(_cart);
    return _cart;
  }

  @override
  Future<Cart> clear() async {
    await Future<void>.delayed(_delay);
    _cart = const Cart();
    _controller.add(_cart);
    return _cart;
  }

  // ── Snapshot API — legacy mock proxies to the rich [Cart] state. The
  // Sprint 12 hybrid repository is what actually surfaces real snapshot
  // rows; Mock keeps these around so it still satisfies the interface
  // when AppConfig.useMocks=true and Supabase is unavailable.

  @override
  Stream<List<CartItemModel>> watchItems() =>
      _controller.stream.map(_toModels);

  @override
  List<CartItemModel> get currentItems => _toModels(_cart);

  @override
  Future<List<CartItemModel>> fetchItems() async {
    final cart = await fetch();
    return _toModels(cart);
  }

  @override
  Future<void> addProduct(
    SupabaseProductModel product, {
    int quantity = 1,
    String? selectedColor,
  }) async {
    await addItem(product.id, quantity: quantity);
  }

  @override
  Future<void> updateProductQuantity(
    String productId,
    int newQuantity,
  ) async {
    final match = _cart.items
        .where((it) => it.product.id == productId)
        .toList();
    if (match.isEmpty) return;
    await updateQuantity(match.first.id, newQuantity);
  }

  @override
  Future<void> removeProduct(String productId) async {
    final match = _cart.items
        .where((it) => it.product.id == productId)
        .toList();
    if (match.isEmpty) return;
    await removeItem(match.first.id);
  }

  List<CartItemModel> _toModels(Cart cart) {
    return cart.items.map((it) {
      return CartItemModel(
        id: it.id,
        productId: it.product.id,
        productName: it.product.name.get('uz'),
        productImage: it.product.heroImage,
        productPrice: it.product.price.toDouble(),
        quantity: it.quantity,
      );
    }).toList(growable: false);
  }
}

import 'dart:async';

import '../models/cart.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import 'cart_repository.dart';

/// Auth-aware cart that routes to a [local] (Hive, guest) or [remote] (backend,
/// signed-in) cart depending on session state, and merges the guest cart into
/// the server cart on login.
///
/// `watchItems()` re-streams whichever backend is currently active, so the
/// cart badge and screen update seamlessly across login/logout. On a
/// guest→signed-in transition the local rows are replayed into the server cart
/// (the backend upsert increments quantities) and the local cart is emptied.
class HybridCartRepository implements CartRepository {
  HybridCartRepository({
    required this.remote,
    required this.local,
    required bool Function() isSignedIn,
    required Stream<bool> authChanges,
  }) : _isSignedIn = isSignedIn {
    _lastAuthed = _isSignedIn();
    // Forward only the active backend's emissions so a stale cache from the
    // other side never leaks into the badge.
    _remoteSub = remote.watchItems().listen((items) {
      if (_isSignedIn()) _itemsController.add(items);
    });
    _localSub = local.watchItems().listen((items) {
      if (!_isSignedIn()) _itemsController.add(items);
    });
    _authSub = authChanges.listen(_onAuthChanged);
  }

  final CartRepository remote;
  final CartRepository local;
  final bool Function() _isSignedIn;

  bool _lastAuthed = false;
  final _itemsController = StreamController<List<CartItemModel>>.broadcast();
  StreamSubscription<List<CartItemModel>>? _remoteSub;
  StreamSubscription<List<CartItemModel>>? _localSub;
  StreamSubscription<bool>? _authSub;

  CartRepository get _active => _isSignedIn() ? remote : local;

  Future<void> _onAuthChanged(bool authed) async {
    // `changes` also fires on token refresh (authed→authed); only act on a
    // real signed-out ↔ signed-in transition.
    if (authed == _lastAuthed) return;
    _lastAuthed = authed;
    if (authed) {
      await _mergeGuestCart();
    } else {
      // Logout: stop mirroring the (now foreign) server cart and show the
      // local one. The server cart is left intact for the next login.
      await local.fetchItems();
    }
  }

  /// Replays the guest's local rows into the server cart, then empties the
  /// local cart. Best-effort per item so one unavailable product can't block
  /// the rest of the merge.
  Future<void> _mergeGuestCart() async {
    final pending = local.currentItems;
    for (final it in pending) {
      try {
        await remote.addProduct(
          _toProduct(it),
          quantity: it.quantity,
          selectedColor: it.selectedColor,
        );
      } catch (_) {
        // Skip an item that no longer adds (e.g. the product was removed).
      }
    }
    await local.clear();
    await remote.fetchItems();
  }

  // ── Snapshot API — routes to the active backend ───────────────────────────

  @override
  Stream<List<CartItemModel>> watchItems() => _itemsController.stream;

  @override
  List<CartItemModel> get currentItems => _active.currentItems;

  @override
  Future<List<CartItemModel>> fetchItems() => _active.fetchItems();

  @override
  Future<void> addProduct(
    ProductModel product, {
    int quantity = 1,
    String? selectedColor,
  }) => _active.addProduct(
    product,
    quantity: quantity,
    selectedColor: selectedColor,
  );

  @override
  Future<void> updateProductQuantity(String productId, int newQuantity) =>
      _active.updateProductQuantity(productId, newQuantity);

  @override
  Future<void> removeProduct(String productId) =>
      _active.removeProduct(productId);

  // ── Legacy [Cart] API — delegates to the active backend ───────────────────

  @override
  Stream<Cart> watch() => _active.watch();

  @override
  Cart get current => _active.current;

  @override
  Future<Cart> fetch() => _active.fetch();

  @override
  Future<Cart> addItem(String productId, {int quantity = 1}) =>
      _active.addItem(productId, quantity: quantity);

  @override
  Future<Cart> updateQuantity(String itemId, int quantity) =>
      _active.updateQuantity(itemId, quantity);

  @override
  Future<Cart> removeItem(String itemId) => _active.removeItem(itemId);

  @override
  Future<Cart> clear() => _active.clear();

  /// Minimal [ProductModel] for the merge replay — only `id`, `quantity`, and
  /// `selectedColor` reach the backend, so the other fields are placeholders.
  ProductModel _toProduct(CartItemModel it) => ProductModel(
    id: it.productId,
    categoryId: '',
    name: it.productName,
    price: it.productPrice,
    images: it.productImage.isEmpty ? const [] : [it.productImage],
    stock: 0,
    createdAt: DateTime.now(),
  );

  Future<void> dispose() async {
    await _remoteSub?.cancel();
    await _localSub?.cancel();
    await _authSub?.cancel();
    await _itemsController.close();
  }
}

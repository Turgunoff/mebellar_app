import 'dart:async';

import '../../core/network/api_error.dart';
import '../models/cart.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import 'cart_repository.dart';

/// Outcome of merging the guest's local cart into the server cart on login.
/// Surfaced via [HybridCartRepository.mergeEvents] so the UI can tell the user
/// when lines were dropped (e.g. "2 items are no longer available").
class CartMergeResult {
  const CartMergeResult({required this.merged, required this.dropped});

  /// Lines successfully replayed onto the server cart.
  final int merged;

  /// Lines permanently unmergeable (product removed / out of stock) — dropped
  /// from the local cart so they don't linger. Transient failures are NOT
  /// counted here: they're kept locally to retry on the next merge.
  final int dropped;
}

/// Per-line result of a single replay attempt during `_mergeGuestCart`.
enum _MergeOutcome {
  /// Added to the server cart — remove it from local.
  merged,

  /// Permanent backend rejection (product gone / invalid) — remove it from
  /// local and surface the drop to the user.
  dropped,

  /// Transient failure (5xx / rate-limit / auth / network) — keep it local so
  /// the next merge retries it.
  kept,
}

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
  final _mergeController = StreamController<CartMergeResult>.broadcast();
  StreamSubscription<List<CartItemModel>>? _remoteSub;
  StreamSubscription<List<CartItemModel>>? _localSub;
  StreamSubscription<bool>? _authSub;

  CartRepository get _active => _isSignedIn() ? remote : local;

  /// Emits once per guest→signed-in merge that touched any line, so the UI can
  /// notify the user of dropped (no-longer-available) items.
  Stream<CartMergeResult> get mergeEvents => _mergeController.stream;

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

  /// Replays the guest's local rows into the server cart on login. Each line is
  /// attempted in parallel; only lines that succeed (or are permanently
  /// unmergeable) are removed from the local cart, so a transient failure keeps
  /// the line for the next merge instead of silently losing it. A summary is
  /// pushed onto [mergeEvents] when any line merged or dropped, so the UI can
  /// surface "N items are no longer available".
  Future<void> _mergeGuestCart() async {
    final pending = local.currentItems;
    if (pending.isEmpty) return;

    final outcomes = await Future.wait(
      pending.map((it) async {
        try {
          await remote.addProduct(
            _toProduct(it),
            quantity: it.quantity,
            selectedColor: it.selectedColor,
          );
          return (_MergeOutcome.merged, it);
        } on ApiError catch (e) {
          return (
            _isPermanent(e) ? _MergeOutcome.dropped : _MergeOutcome.kept,
            it,
          );
        } catch (_) {
          // Network / unknown — treat as transient and keep the line.
          return (_MergeOutcome.kept, it);
        }
      }),
    );

    final keptAny = outcomes.any((o) => o.$1 == _MergeOutcome.kept);
    if (keptAny) {
      // Partial merge: drop only the lines that merged or are permanently gone,
      // leaving transient failures in place to retry.
      for (final (outcome, it) in outcomes) {
        if (outcome != _MergeOutcome.kept) {
          await local.removeProduct(it.productId);
        }
      }
    } else {
      // Nothing to retry — clear in one write rather than row-by-row.
      await local.clear();
    }

    await remote.fetchItems();

    final merged = outcomes.where((o) => o.$1 == _MergeOutcome.merged).length;
    final dropped = outcomes.where((o) => o.$1 == _MergeOutcome.dropped).length;
    if (merged > 0 || dropped > 0) {
      _mergeController.add(CartMergeResult(merged: merged, dropped: dropped));
    }
  }

  /// A 4xx (other than auth/rate-limit) means the line can never replay — the
  /// product was removed, is out of stock, or the request was invalid. 5xx /
  /// 401 / 429 / network errors are transient and worth retrying next merge.
  static bool _isPermanent(ApiError e) =>
      e.status >= 400 &&
      e.status < 500 &&
      !e.isUnauthorized &&
      !e.isRateLimited;

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

  /// [ProductModel] for the merge replay. Carries everything the Hive row
  /// kept (name/image/price/shop) so the server snapshot built from it stays
  /// as complete as the guest's local one — checkout groups lines by shopId.
  ProductModel _toProduct(CartItemModel it) => ProductModel(
    id: it.productId,
    categoryId: '',
    name: it.productName,
    price: it.productPrice,
    images: it.productImage.isEmpty ? const [] : [it.productImage],
    shopId: it.shopId,
    shopName: it.shopName,
    stock: 0,
    createdAt: DateTime.now(),
  );

  Future<void> dispose() async {
    await _remoteSub?.cancel();
    await _localSub?.cancel();
    await _authSub?.cancel();
    await _itemsController.close();
    await _mergeController.close();
  }
}

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:woody_app/core/logging/talker.dart';

import '../models/cart.dart';
import '../models/cart_item_model.dart';
import '../models/supabase_product_model.dart';
import 'cart_repository.dart';
import 'hive_cart_repository.dart';
import 'supabase_cart_repository.dart';

/// Cart repository that switches between [HiveCartRepository] (guest) and
/// [SupabaseCartRepository] (authenticated user) based on the current
/// Supabase auth state.
///
/// On sign-in we run [_syncHiveToSupabase] which upserts every locally-
/// stored cart row into `public.cart_items`, summing quantities when the
/// user already had the same product in their remote cart. The local Hive
/// box is wiped after a successful sync.
///
/// On sign-out the active delegate flips back to Hive and the remote
/// repository's in-memory cache is cleared, so the next user lands on a
/// fresh state.
class HybridCartRepository implements CartRepository {
  HybridCartRepository({
    required HiveCartRepository hive,
    required SupabaseCartRepository remote,
    required sb.SupabaseClient supabase,
  }) : _hive = hive,
       _remote = remote,
       _supabase = supabase {
    _init();
  }

  final HiveCartRepository _hive;
  final SupabaseCartRepository _remote;
  final sb.SupabaseClient _supabase;

  final _itemsController = StreamController<List<CartItemModel>>.broadcast();
  final _cartController = StreamController<Cart>.broadcast();

  StreamSubscription<List<CartItemModel>>? _itemsDelegateSub;
  StreamSubscription<Cart>? _cartDelegateSub;
  StreamSubscription<sb.AuthState>? _authSub;
  bool _syncing = false;

  bool get _isAuthenticated => _supabase.auth.currentSession != null;

  CartRepository get _delegate => _isAuthenticated ? _remote : _hive;

  void _init() {
    _reSubscribeToDelegate();
    _authSub = _supabase.auth.onAuthStateChange.listen((state) async {
      if (state.event == sb.AuthChangeEvent.signedIn && !_syncing) {
        _syncing = true;
        try {
          await _syncHiveToSupabase();
        } finally {
          _syncing = false;
        }
      } else if (state.event == sb.AuthChangeEvent.signedOut) {
        _remote.clearCache();
      }
      _reSubscribeToDelegate();
      // Re-fetch through whichever delegate is active so subscribers
      // receive a fresh snapshot for the new auth context.
      try {
        await _delegate.fetchItems();
      } catch (e, st) {
        talker.handle(e, st, 'HybridCart: post-auth refetch failed');
      }
    });
  }

  void _reSubscribeToDelegate() {
    _itemsDelegateSub?.cancel();
    _cartDelegateSub?.cancel();
    _itemsDelegateSub = _delegate.watchItems().listen(_itemsController.add);
    _cartDelegateSub = _delegate.watch().listen(_cartController.add);
    // Push the current snapshot immediately so late subscribers hydrate.
    _itemsController.add(_delegate.currentItems);
    _cartController.add(_delegate.current);
  }

  /// Reads every locally-stored cart row from Hive and merges them into
  /// `public.cart_items`. If the user already has a row for the same
  /// product, quantities are summed (clamped at 99). The local store is
  /// cleared after a successful sync so the next session starts clean.
  Future<void> _syncHiveToSupabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final localItems = _hive.readAll();
    if (localItems.isEmpty) {
      // Even with nothing to sync, hydrate the remote view so the cart
      // screen shows the user's existing rows immediately on login.
      await _remote.fetchItems();
      return;
    }

    // Pull whatever the user already has remotely so we can sum
    // quantities client-side (Postgres `on conflict do update` would also
    // work, but doing it here keeps the snapshot freshness predictable).
    await _remote.fetchItems();
    final remoteByProductId = <String, CartItemModel>{
      for (final it in _remote.currentItems) it.productId: it,
    };

    final rows = <Map<String, dynamic>>[];
    for (final local in localItems) {
      final remote = remoteByProductId[local.productId];
      final mergedQty = ((remote?.quantity ?? 0) + local.quantity).clamp(1, 99);
      rows.add({
        'user_id': user.id,
        'product_id': local.productId,
        'quantity': mergedQty,
        'product_snapshot': local.toSnapshotJson(),
      });
    }

    if (rows.isNotEmpty) {
      await _supabase
          .from('cart_items')
          .upsert(rows, onConflict: 'user_id,product_id');
    }

    await _hive.clearLocal();
    await _remote.fetchItems();
  }

  Future<void> dispose() async {
    await _itemsDelegateSub?.cancel();
    await _cartDelegateSub?.cancel();
    await _authSub?.cancel();
    await _itemsController.close();
    await _cartController.close();
  }

  // ── CartRepository — snapshot API (delegated) ──────────────────────────

  @override
  Stream<List<CartItemModel>> watchItems() => _itemsController.stream;

  @override
  List<CartItemModel> get currentItems => _delegate.currentItems;

  @override
  Future<List<CartItemModel>> fetchItems() => _delegate.fetchItems();

  @override
  Future<void> addProduct(
    SupabaseProductModel product, {
    int quantity = 1,
    String? selectedColor,
  }) {
    return _delegate.addProduct(
      product,
      quantity: quantity,
      selectedColor: selectedColor,
    );
  }

  @override
  Future<void> updateProductQuantity(String productId, int newQuantity) {
    return _delegate.updateProductQuantity(productId, newQuantity);
  }

  @override
  Future<void> removeProduct(String productId) {
    return _delegate.removeProduct(productId);
  }

  // ── CartRepository — legacy [Cart] API (delegated) ─────────────────────

  @override
  Stream<Cart> watch() => _cartController.stream;

  @override
  Cart get current => _delegate.current;

  @override
  Future<Cart> fetch() => _delegate.fetch();

  @override
  Future<Cart> addItem(String productId, {int quantity = 1}) =>
      _delegate.addItem(productId, quantity: quantity);

  @override
  Future<Cart> updateQuantity(String itemId, int quantity) =>
      _delegate.updateQuantity(itemId, quantity);

  @override
  Future<Cart> removeItem(String itemId) => _delegate.removeItem(itemId);

  @override
  Future<Cart> clear() => _delegate.clear();
}

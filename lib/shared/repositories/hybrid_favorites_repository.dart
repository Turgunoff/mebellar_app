import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/product.dart';
import 'favorites_repository.dart';
import 'hive_favorites_repository.dart';
import 'supabase_favorites_repository.dart';

/// Delegates to [SupabaseFavoritesRepository] for authenticated users and
/// to [HiveFavoritesRepository] for guests.
///
/// On sign-in it syncs every locally-stored product ID to the Supabase
/// `favorites` table (upsert), then clears the local Hive store.
/// On sign-out the active delegate silently switches back to Hive so the
/// user's remote data is never exposed on a shared device.
class HybridFavoritesRepository implements FavoritesRepository {
  HybridFavoritesRepository({
    required HiveFavoritesRepository hive,
    required SupabaseFavoritesRepository remote,
    required sb.SupabaseClient supabase,
  })  : _hive = hive,
        _remote = remote,
        _supabase = supabase {
    _init();
  }

  final HiveFavoritesRepository _hive;
  final SupabaseFavoritesRepository _remote;
  final sb.SupabaseClient _supabase;

  final _controller = StreamController<Set<String>>.broadcast();
  StreamSubscription<Set<String>>? _delegateSub;
  StreamSubscription<sb.AuthState>? _authSub;
  bool _syncing = false;

  bool get _isAuthenticated => _supabase.auth.currentSession != null;
  FavoritesRepository get _delegate => _isAuthenticated ? _remote : _hive;

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
    });
  }

  void _reSubscribeToDelegate() {
    _delegateSub?.cancel();
    _delegateSub = _delegate.watchIds().listen(_controller.add);
    // Immediately push the current snapshot so the FavoritesBloc hydrates.
    _controller.add(_delegate.currentIds);
  }

  /// Reads all locally-stored products from Hive and upserts them into the
  /// Supabase `favorites` table, then wipes the local store.
  Future<void> _syncHiveToSupabase() async {
    if (_supabase.auth.currentUser == null) return;
    final products = await _hive.list();
    if (products.isEmpty) return;

    final userId = _supabase.auth.currentUser!.id;
    final rows = products
        .map((p) => {
              'user_id': userId,
              'product_id': p.id,
              'product_snapshot': _toSnapshot(p),
            })
        .toList();

    await _supabase.from('favorites').upsert(
          rows,
          onConflict: 'user_id,product_id',
        );
    await _hive.clear();
  }

  Map<String, dynamic> _toSnapshot(Product p) => {
        'id': p.id,
        'slug': p.slug,
        'name': p.name.toJson(),
        'price': p.price,
        'old_price': p.oldPrice,
        'images': p.images,
        'primary_image': p.primaryImage,
        'category_slug': p.categorySlug,
        'stock': p.stock,
        'is_favorite': true,
      };

  Future<void> dispose() async {
    await _delegateSub?.cancel();
    await _authSub?.cancel();
    await _controller.close();
  }

  // ── FavoritesRepository ───────────────────────────────────────────────────

  @override
  Set<String> get currentIds => _delegate.currentIds;

  @override
  bool isFavorite(String productId) => _delegate.isFavorite(productId);

  @override
  Stream<Set<String>> watchIds() => _controller.stream;

  @override
  Future<List<Product>> list() => _delegate.list();

  @override
  Future<void> toggle(Product product) => _delegate.toggle(product);

  @override
  Future<void> remove(String productId) => _delegate.remove(productId);
}

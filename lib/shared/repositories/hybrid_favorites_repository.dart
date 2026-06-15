import 'dart:async';

import '../models/product.dart';
import 'favorites_repository.dart';
import 'hive_favorites_repository.dart';

/// Auth-aware favorites that route to a [local] (Hive, guest) or [remote]
/// (backend, signed-in) store depending on session state, and union the guest
/// list into the server account on login.
///
/// `watchIds()` re-streams whichever backend is currently active, so the heart
/// icons across the app update seamlessly across login/logout. On a
/// guest→signed-in transition the local rows are replayed into the server
/// account and the local store is emptied; [sessionChanges] then fires so the
/// bloc reloads the product list — only AFTER the merge so the tab can't show
/// a list that's missing the just-merged items.
class HybridFavoritesRepository implements FavoritesRepository {
  HybridFavoritesRepository({
    required this.remote,
    required this.local,
    required bool Function() isSignedIn,
    required Stream<bool> authChanges,
  }) : _isSignedIn = isSignedIn {
    _lastAuthed = _isSignedIn();
    // Forward only the active backend's emissions so a stale set from the
    // other side never leaks into the hearts.
    _remoteSub = remote.watchIds().listen((ids) {
      if (_isSignedIn()) _idsController.add(ids);
    });
    _localSub = local.watchIds().listen((ids) {
      if (!_isSignedIn()) _idsController.add(ids);
    });
    _authSub = authChanges.listen(_onAuthChanged);
  }

  final FavoritesRepository remote;
  final HiveFavoritesRepository local;
  final bool Function() _isSignedIn;

  bool _lastAuthed = false;
  final _idsController = StreamController<Set<String>>.broadcast();
  // Emitted AFTER a transition fully settles (merge complete on login, local
  // reset on logout). The bloc reloads its product list off this rather than
  // the raw token stream, which would race the merge.
  final _sessionController = StreamController<bool>.broadcast();
  StreamSubscription<Set<String>>? _remoteSub;
  StreamSubscription<Set<String>>? _localSub;
  StreamSubscription<bool>? _authSub;

  /// Fires once a signed-in/out transition has fully settled (the login merge
  /// has completed). The favorites bloc listens to this to reload products.
  Stream<bool> get sessionChanges => _sessionController.stream;

  FavoritesRepository get _active => _isSignedIn() ? remote : local;

  Future<void> _onAuthChanged(bool authed) async {
    // `changes` also fires on token refresh (authed→authed); only act on a
    // real signed-out ↔ signed-in transition.
    if (authed == _lastAuthed) return;
    _lastAuthed = authed;
    if (authed) {
      await _mergeGuestFavorites();
    } else {
      // Logout: re-emit the (now empty) local set; the server account is left
      // intact for the next login.
      await local.list();
    }
    if (!_sessionController.isClosed) _sessionController.add(authed);
  }

  /// Unions the guest's local favorites into the server account, then empties
  /// the local store. Already-favorited products are skipped — the merge is a
  /// union, not a toggle, and `remote.toggle` on an existing favorite would
  /// REMOVE it. Best-effort per item so one removed product can't block the
  /// rest.
  Future<void> _mergeGuestFavorites() async {
    final pending = await local.list();
    if (pending.isNotEmpty) {
      try {
        // Load the server set so we don't re-POST (or accidentally toggle off)
        // a product already favorited on the account.
        await remote.list();
      } catch (_) {}
      for (final product in pending) {
        if (remote.currentIds.contains(product.id)) continue;
        try {
          await remote.toggle(product);
        } catch (_) {}
      }
    }
    await local.clear();
    await remote.list();
  }

  @override
  Stream<Set<String>> watchIds() => _idsController.stream;

  @override
  Set<String> get currentIds => _active.currentIds;

  @override
  bool isFavorite(String productId) => _active.isFavorite(productId);

  @override
  Future<List<Product>> list() => _active.list();

  @override
  Future<void> toggle(Product product) => _active.toggle(product);

  @override
  Future<void> remove(String productId) => _active.remove(productId);

  Future<void> dispose() async {
    await _remoteSub?.cancel();
    await _localSub?.cancel();
    await _authSub?.cancel();
    await _idsController.close();
    await _sessionController.close();
    await local.dispose();
  }
}

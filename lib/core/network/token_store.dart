import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp.subtract(const Duration(seconds: 30)));
  }
}

/// Persists the Woody backend access + refresh tokens in
/// `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences on
/// Android). Secrets must never sit in Hive — Hive boxes are plain files.
///
/// Emits a non-replayed [Stream<TokenPair?>] so [AuthCubit] can react to
/// sign-in / sign-out / refresh-failure events without polling.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _kAccess = 'woody_access_token';
  static const _kRefresh = 'woody_refresh_token';
  static const _kExpiresAt = 'woody_expires_at';

  final FlutterSecureStorage _storage;
  final StreamController<TokenPair?> _changes =
      StreamController<TokenPair?>.broadcast();

  TokenPair? _cached;
  bool _hydrated = false;

  /// In-flight first read of secure storage. Memoised so a cold-start burst of
  /// authenticated requests (the interceptor reads tokens per request) funnels
  /// through a single storage round-trip instead of each firing its own — the
  /// same single-flight discipline the refresh path uses.
  Future<TokenPair?>? _hydration;

  Stream<TokenPair?> get changes => _changes.stream;
  TokenPair? get current => _cached;

  Future<TokenPair?> read() {
    if (_hydrated) return Future<TokenPair?>.value(_cached);
    return _hydration ??= _hydrate();
  }

  Future<TokenPair?> _hydrate() async {
    try {
      final access = await _storage.read(key: _kAccess);
      final refresh = await _storage.read(key: _kRefresh);
      final expiresAtStr = await _storage.read(key: _kExpiresAt);
      // A write()/clear() may have landed while we awaited storage; its value
      // is authoritative, so don't clobber it with what we just read.
      if (_hydrated) return _cached;
      _cached = (access == null || refresh == null)
          ? null
          : TokenPair(
              accessToken: access,
              refreshToken: refresh,
              expiresAt: expiresAtStr == null
                  ? null
                  : DateTime.tryParse(expiresAtStr),
            );
      _hydrated = true;
      return _cached;
    } finally {
      _hydration = null;
    }
  }

  Future<void> write(TokenPair pair) async {
    await _storage.write(key: _kAccess, value: pair.accessToken);
    await _storage.write(key: _kRefresh, value: pair.refreshToken);
    if (pair.expiresAt != null) {
      await _storage.write(
        key: _kExpiresAt,
        value: pair.expiresAt!.toIso8601String(),
      );
    } else {
      await _storage.delete(key: _kExpiresAt);
    }
    _cached = pair;
    _hydrated = true;
    _changes.add(pair);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kExpiresAt);
    // Only a real signed-in → signed-out transition is an event worth
    // broadcasting. A clear() on an already-empty store (a guest 401 dragging
    // the interceptor through _forceSignOut, a double sign-out) is a no-op:
    // re-emitting `null` here would re-fire every `changes` listener —
    // including NotificationsCubit's reload — which, since the reload hits
    // another guest 401, clears again and spins an infinite loop.
    final hadSession = _cached != null;
    _cached = null;
    _hydrated = true;
    if (hadSession) _changes.add(null);
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}

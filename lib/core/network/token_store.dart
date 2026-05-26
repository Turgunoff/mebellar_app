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

  Stream<TokenPair?> get changes => _changes.stream;
  TokenPair? get current => _cached;

  Future<TokenPair?> read() async {
    if (_hydrated) return _cached;
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    final expiresAtStr = await _storage.read(key: _kExpiresAt);
    _hydrated = true;
    if (access == null || refresh == null) {
      _cached = null;
      return null;
    }
    final expiresAt = expiresAtStr == null
        ? null
        : DateTime.tryParse(expiresAtStr);
    _cached = TokenPair(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt,
    );
    return _cached;
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
    _cached = null;
    _hydrated = true;
    _changes.add(null);
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}

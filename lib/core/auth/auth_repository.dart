import 'dart:async';

import '../../shared/models/me.dart';
import '../network/api_error.dart';
import '../network/jwt_utils.dart';
import '../network/token_store.dart';
import '../network/woody_api_client.dart';

/// HTTP-backed auth surface for `api.woody.uz`.
///
/// Replaces the Supabase-Auth-backed shim. The four primitives mirror the
/// backend's `/auth/*` routes: request → verify (mints tokens) → refresh →
/// logout. Tokens are written to [TokenStore]; [authStateChanges] reflects
/// the store's stream so widgets/cubits can rebuild on sign-in/out without
/// polling.
class AuthRepository {
  AuthRepository({
    required WoodyApiClient api,
    required TokenStore tokens,
  })  : _api = api,
        _tokens = tokens;

  final WoodyApiClient _api;
  final TokenStore _tokens;

  /// Stream of token-pair changes. `null` means signed out.
  Stream<TokenPair?> get authStateChanges => _tokens.changes;

  bool get isAuthenticated => _tokens.current != null;

  String? get currentUserId {
    final pair = _tokens.current;
    if (pair == null) return null;
    return jwtClaim(pair.accessToken, 'sub');
  }

  /// Triggers SMS delivery. Returns the cooldown (in seconds) the server
  /// expects to elapse before another /otp/request is accepted — the UI
  /// kicks off a countdown with this value.
  Future<int> requestOtp(String phone) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/auth/otp/request',
      body: {'phone': phone},
      anonymous: true,
    );
    final cooldown = body['cooldown_seconds'];
    return cooldown is int ? cooldown : 0;
  }

  /// Verifies the OTP and writes the resulting token pair to the store.
  /// The caller can then call [fetchMe] to decide whether the user needs
  /// the profile-step (no full_name yet) or can go straight to home.
  Future<TokenPair> verifyOtp(String phone, String code) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/auth/otp/verify',
      body: {'phone': phone, 'code': code},
      anonymous: true,
    );
    final pair = _parseTokens(body);
    await _tokens.write(pair);
    return pair;
  }

  /// Clears the local pair and tells the backend to invalidate the refresh
  /// jti. Always proceeds with local cleanup even if the network call fails
  /// — a stuck refresh token is preferable to a UI stuck on "signing out".
  Future<void> signOut() async {
    final pair = _tokens.current ?? await _tokens.read();
    final refresh = pair?.refreshToken;
    try {
      if (refresh != null) {
        await _api.post<dynamic>(
          '/auth/logout',
          body: {'refresh_token': refresh},
          anonymous: true,
        );
      }
    } on ApiError {
      // Best-effort: server reject doesn't block local sign-out.
    } finally {
      await _tokens.clear();
    }
  }

  Future<Me> fetchMe() async {
    final body = await _api.get<Map<String, dynamic>>('/me');
    return Me.fromJson(body);
  }

  Future<Me> updateProfile({
    String? fullName,
    String? preferredLanguage,
    String? avatarUrl,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName;
    if (preferredLanguage != null) {
      payload['preferred_language'] = preferredLanguage;
    }
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
    final body = await _api.patch<Map<String, dynamic>>(
      '/me',
      body: payload,
    );
    return Me.fromJson(body);
  }

  Future<void> dispose() async {
    // TokenStore + Dio dispose are owned by core_module — nothing local.
  }

  TokenPair _parseTokens(Map<String, dynamic> json) {
    final access = json['access_token'] as String?;
    final refresh = json['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw ApiError(
        status: 0,
        code: 'malformed_token_response',
        message: 'Token response missing access/refresh',
      );
    }
    final expiresIn = json['expires_in'];
    final expiresAt = expiresIn is int
        ? DateTime.now().add(Duration(seconds: expiresIn))
        : null;
    return TokenPair(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt,
    );
  }

}

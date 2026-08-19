import 'dart:async';

import '../../shared/models/me.dart';
import '../network/api_error.dart';
import '../network/jwt_utils.dart';
import '../network/token_store.dart';
import '../network/woody_api_client.dart';

/// HTTP-backed auth surface for `api.woody.uz`.
///
/// Replaces the legacy auth-backed shim. The four primitives mirror the
/// backend's `/auth/*` routes: request → verify (mints tokens) → refresh →
/// logout. Tokens are written to [TokenStore]; [authStateChanges] reflects
/// the store's stream so widgets/cubits can rebuild on sign-in/out without
/// polling.
class AuthRepository {
  AuthRepository({required WoodyApiClient api, required TokenStore tokens})
    : _api = api,
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

  /// The phone the user signed in with, read straight from the access-token
  /// `phone` claim. Lets the profile header paint the identity instantly,
  /// before the `/me` round-trip resolves.
  String? get currentUserPhone {
    final pair = _tokens.current;
    if (pair == null) return null;
    return jwtClaim(pair.accessToken, 'phone');
  }

  /// Triggers SMS delivery. Returns the cooldown (in seconds) the server
  /// expects to elapse before another /otp/request is accepted — the UI
  /// kicks off a countdown with this value.
  ///
  /// The OTP SMS follows the active UI language ([appLanguage]): uz/ru/en each
  /// have an approved Eskiz template, so the code arrives in the user's
  /// language. Any other / unknown language falls back to the English template
  /// (never uz — see [_smsLocale]). The resolved locale is sent as a
  /// per-request `localeOverride` so it wins over the live `Accept-Language`
  /// header. Every template ends with our app-signature hash, so Android's SMS
  /// Retriever can still zero-tap auto-fill the code. Backend error codes are
  /// translated client-side, so the SMS language is independent of error copy.
  Future<int> requestOtp(String phone, {String? appLanguage}) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/auth/otp/request',
      body: {'phone': phone},
      anonymous: true,
      localeOverride: _smsLocale(appLanguage),
    );
    final cooldown = body['cooldown_seconds'];
    return cooldown is int ? cooldown : 0;
  }

  /// Maps the active UI language to the OTP SMS locale. uz/ru/en each map to
  /// their own approved Eskiz template; anything else (incl. null) gets the
  /// English template — uz is never a sensible default for a non-uz speaker.
  static String _smsLocale(String? appLanguage) => switch (appLanguage) {
    'uz' => 'uz',
    'ru' => 'ru',
    _ => 'en',
  };

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
    String? email,
    String? preferredLanguage,
    String? avatarUrl,
    bool? promoPushEnabled,
    bool? orderPushEnabled,
    bool? sellerPromoDismissed,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName;
    if (email != null) payload['email'] = email;
    if (preferredLanguage != null) {
      payload['preferred_language'] = preferredLanguage;
    }
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
    if (promoPushEnabled != null) {
      payload['promo_push_enabled'] = promoPushEnabled;
    }
    if (orderPushEnabled != null) {
      payload['order_push_enabled'] = orderPushEnabled;
    }
    if (sellerPromoDismissed != null) {
      payload['seller_promo_dismissed'] = sellerPromoDismissed;
    }
    final body = await _api.patch<Map<String, dynamic>>('/me', body: payload);
    return Me.fromJson(body);
  }

  /// Persists the account-lifecycle UI flags on the seller row via
  /// `PATCH /seller/me/alerts`. Both are optional — only the provided flag is
  /// written server-side. This replaces the old app-local Hive bookkeeping so
  /// the state (approval-bonus screen seen, rejection banner dismissed) follows
  /// the account across reinstall / device change instead of replaying. A
  /// no-op (both null) returns without a network call.
  Future<void> setSellerAlertFlags({
    bool? bonusScreenSeen,
    bool? rejectionAlertDismissed,
  }) async {
    final payload = <String, dynamic>{};
    if (bonusScreenSeen != null) payload['bonus_screen_seen'] = bonusScreenSeen;
    if (rejectionAlertDismissed != null) {
      payload['rejection_alert_dismissed'] = rejectionAlertDismissed;
    }
    if (payload.isEmpty) return;
    await _api.patch<Map<String, dynamic>>('/seller/me/alerts', body: payload);
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

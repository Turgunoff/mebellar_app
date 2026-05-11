import 'dart:async';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../shared/models/me.dart';

class AuthRepository {
  AuthRepository(this._supabase, this._dio);

  final sb.SupabaseClient _supabase;
  final Dio _dio;

  Stream<sb.AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  bool get isAuthenticated => _supabase.auth.currentSession != null;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  bool get isEmailConfirmed =>
      _supabase.auth.currentUser?.emailConfirmedAt != null;

  Future<sb.AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String preferredLanguage,
  }) {
    return _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'preferred_language': preferredLanguage,
      },
    );
  }

  Future<sb.AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _supabase.auth.signOut();

  Future<void> resetPassword(String email) {
    return _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'mebellar://reset-password',
    );
  }

  Future<void> resendVerificationEmail(String email) {
    return _supabase.auth.resend(type: sb.OtpType.signup, email: email);
  }

  Future<Me> fetchMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/me');
    final body = response.data;
    if (body == null) {
      throw StateError('Empty /me response');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected /me payload');
    }
    return Me.fromJson(data);
  }

  Future<void> dispose() async {
    // SupabaseClient and Dio live in the root scope; nothing local to clean up.
  }
}

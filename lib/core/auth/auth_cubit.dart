import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../analytics/analytics_service.dart';

sealed class AppAuthState extends Equatable {
  const AppAuthState();
}

class AppAuthUnauthenticated extends AppAuthState {
  const AppAuthUnauthenticated();
  @override
  List<Object?> get props => const [];
}

class AppAuthAuthenticated extends AppAuthState {
  const AppAuthAuthenticated(this.userId);
  final String userId;
  @override
  List<Object?> get props => [userId];
}

/// Global auth cubit — single listener on the Supabase auth stream.
///
/// Registered as a root-scope singleton so it survives mode switches.
/// Widgets that need auth reactivity should use
/// `BlocBuilder<AuthCubit, AppAuthState>` instead of maintaining their own
/// `StreamSubscription<AuthState>`.
///
/// Also acts as the single source-of-truth for tagging analytics with the
/// current user id. `signedIn` events fire a `login` analytics event;
/// `signedOut` fires `logout`. Fresh sign-ups are emitted by the register
/// screen itself so the `sign_up` event carries the chosen method.
class AuthCubit extends Cubit<AppAuthState> {
  AuthCubit(this._supabase, {AnalyticsService? analytics})
      : _analytics = analytics,
        super(const AppAuthUnauthenticated()) {
    _init();
  }

  final supa.SupabaseClient? _supabase;
  final AnalyticsService? _analytics;
  StreamSubscription<supa.AuthState>? _sub;

  void _init() {
    final client = _supabase;
    if (client == null) return;

    final session = client.auth.currentSession;
    if (session != null) {
      emit(AppAuthAuthenticated(session.user.id));
      // Tag analytics with the restored user — fire-and-forget so the
      // cubit doesn't block on a network call at boot.
      _analytics?.setUserId(session.user.id);
    }

    _sub = client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final event = data.event;
      if (session != null) {
        emit(AppAuthAuthenticated(session.user.id));
        _analytics?.setUserId(session.user.id);
        // `signedIn` fires both for fresh logins and (in some Supabase
        // builds) for restored sessions; the analytics dashboard treats
        // multiple loggedIn events as a no-op for the same user, so we
        // can be permissive here.
        if (event == supa.AuthChangeEvent.signedIn) {
          _analytics?.loggedIn(method: 'email');
        }
      } else {
        emit(const AppAuthUnauthenticated());
        if (event == supa.AuthChangeEvent.signedOut) {
          _analytics?.loggedOut();
        }
        _analytics?.setUserId(null);
      }
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

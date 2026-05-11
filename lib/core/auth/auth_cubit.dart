import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

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
class AuthCubit extends Cubit<AppAuthState> {
  AuthCubit(this._supabase) : super(const AppAuthUnauthenticated()) {
    _init();
  }

  final supa.SupabaseClient? _supabase;
  StreamSubscription<supa.AuthState>? _sub;

  void _init() {
    final client = _supabase;
    if (client == null) return;

    final session = client.auth.currentSession;
    if (session != null) emit(AppAuthAuthenticated(session.user.id));

    _sub = client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        emit(AppAuthAuthenticated(session.user.id));
      } else {
        emit(const AppAuthUnauthenticated());
      }
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../analytics/analytics_service.dart';
import '../network/jwt_utils.dart';
import '../network/token_store.dart';
import '../realtime/woody_realtime_service.dart';
import '../services/facebook_analytics_service.dart';

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

/// Global auth cubit — single listener on the Woody token store.
///
/// Registered as a root-scope singleton so it survives mode switches. Widgets
/// that need auth reactivity should use `BlocBuilder<AuthCubit, AppAuthState>`
/// instead of maintaining their own subscriptions to [TokenStore.changes].
///
/// Also tags analytics with the current user id: sign-in fires `login`,
/// sign-out fires `logout`. Fresh sign-ups are emitted by the controller
/// itself so the `sign_up` event carries the chosen method.
class AuthCubit extends Cubit<AppAuthState> {
  AuthCubit({
    required this.tokens,
    this.analytics,
    this.realtime,
    FacebookAnalyticsService Function()? facebookAnalyticsLookup,
  }) : _facebookAnalyticsLookup = facebookAnalyticsLookup,
       super(const AppAuthUnauthenticated()) {
    _init();
  }

  final TokenStore tokens;
  final AnalyticsService? analytics;

  /// Only used to wipe Meta's Advanced Matching payload on sign-out. The
  /// signed-IN direction is driven by ProfileCubit, which is the one place
  /// that holds a resolved profile — a JWT only carries the user id.
  ///
  /// A lookup closure, not an instance: this cubit is an EAGER singleton in
  /// auth_module, which runs before catalog_module registers
  /// [FacebookAnalyticsService] — resolving at construction would capture
  /// null forever (same trap AppModeCubit documents for AnalyticsService).
  final FacebookAnalyticsService Function()? _facebookAnalyticsLookup;

  /// When provided, the cubit drives the WS lifecycle: opens on sign-in,
  /// closes on sign-out. Optional so unit tests don't need to wire a
  /// realtime stub.
  final WoodyRealtimeService? realtime;

  StreamSubscription<TokenPair?>? _sub;

  Future<void> _init() async {
    // Subscribe BEFORE hydration so any write that lands during the
    // secure_storage read isn't dropped — the broadcast stream does not
    // replay events to late subscribers.
    _sub = tokens.changes.listen((pair) => _apply(pair, emitLogin: true));
    final initial = await tokens.read();
    if (isClosed) return;
    _apply(initial, emitLogin: false);
  }

  void _apply(TokenPair? pair, {required bool emitLogin}) {
    if (pair == null) {
      emit(const AppAuthUnauthenticated());
      analytics?.setUserId(null);
      // Unconditional, even when Meta tracking is currently suppressed:
      // clearing is always the safe direction, and identity data must not
      // outlive the session that produced it.
      unawaited(
        _facebookAnalyticsLookup?.call().clearUserProfile() ??
            Future<void>.value(),
      );
      if (emitLogin) analytics?.loggedOut();
      unawaited(realtime?.stop());
      return;
    }
    final userId = jwtClaim(pair.accessToken, 'sub');
    if (userId == null) {
      // Malformed token in storage — defensive cleanup. The store will emit
      // null on the next tick and we'll transition into Unauthenticated.
      unawaited(tokens.clear());
      return;
    }
    emit(AppAuthAuthenticated(userId));
    analytics?.setUserId(userId);
    if (emitLogin) analytics?.loggedIn(method: 'phone_otp');
    unawaited(realtime?.start());
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

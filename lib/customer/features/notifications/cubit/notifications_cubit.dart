import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/app_mode.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/network/token_store.dart';
import '../../../../core/notifications/badge_sync_controller.dart';
import '../../../../core/realtime/woody_realtime_service.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/repositories/news_repository.dart';
import '../../../../shared/repositories/notifications_data_source.dart';

enum NotificationsStatus { initial, loading, ready, failure }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.items = const [],
    this.error,
  });

  final NotificationsStatus status;
  final List<NotificationModel> items;
  final String? error;

  /// Total unread across both surfaces. Prefer the audience-scoped getters
  /// below for anything user-facing — a buyer surface must never count or
  /// show seller-panel rows.
  int get unreadCount => items.where((n) => !n.isRead).length;

  /// Customer-surface rows only (buyer-facing + global). Seller-panel alerts
  /// (new order, product approved, verification, tariff, …) are excluded so
  /// they never leak into the customer inbox or its bell. Audience is decided
  /// by [NotificationModel.resolveTargetMode] — the same classifier the seller
  /// inbox uses for its half, and the payload `mode` the backend stamps.
  List<NotificationModel> get customerItems => items
      .where((n) => n.resolveTargetMode() == AppMode.customer)
      .toList(growable: false);

  /// Unread count on the customer surface — drives the home bell badge and the
  /// customer inbox's "mark all read" affordance.
  int get customerUnreadCount => items
      .where((n) => !n.isRead && n.resolveTargetMode() == AppMode.customer)
      .length;

  /// Unread count on the seller surface — drives the badge on the profile's
  /// "Sotuvchi paneliga o'tish" CTA, so an approved seller browsing in customer
  /// mode still learns the seller panel has unseen alerts.
  int get sellerUnreadCount => items
      .where((n) => !n.isRead && n.resolveTargetMode() == AppMode.seller)
      .length;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationModel>? items,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, items, error];
}

/// Inbox cubit. Surfaces the union of two sources:
///   * Personal notifications (`GET /notifications`) — scoped to the JWT user.
///     Skipped for guests (that endpoint 401s without a session).
///   * Public news (`GET /catalog/news`) — unauthenticated broadcast feed;
///     read-state lives in Hive so guests still get an inbox + badge.
///
/// Guests therefore see System / All content from news; order/personal rows
/// appear only after sign-in. Live updates: a `notification` event on
/// [WoodyRealtimeService] triggers a reload (the FCM foreground push does the
/// same); news has no live channel and refreshes on [load]. Re-loads on
/// sign-in/out via [AuthRepository].
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(
    this._repo, {
    WoodyRealtimeService? realtime,
    AuthRepository? auth,
    NewsDataSource? newsRepo,
  }) : _realtime = realtime,
       _auth = auth,
       _newsRepo = newsRepo,
       _wasAuthed = auth?.isAuthenticated ?? false,
       super(const NotificationsState()) {
    // Reload only on a real signed-in ↔ signed-out flip. The token store also
    // emits on a silent token *refresh* (authed → authed); reloading on that
    // would re-fire the personal fetch for no reason. (It used to also emit a
    // no-op `null` for a guest, which — paired with the guest 401 — span an
    // infinite reload loop; that's now fixed at the store + interceptor too.)
    _authSub = _auth?.authStateChanges.listen((pair) {
      final authed = pair != null;
      if (authed == _wasAuthed) return;
      _wasAuthed = authed;
      if (!authed) {
        emit(
          const NotificationsState(
            status: NotificationsStatus.ready,
            items: [],
          ),
        );
        if (sl.isRegistered<BadgeSyncController>()) {
          unawaited(sl<BadgeSyncController>().clearOnLogout());
        }
      }
      load();
    });
    _eventsSub = _realtime?.eventsOfType('notification').listen((_) => load());
  }

  final NotificationDataSource _repo;
  final NewsDataSource? _newsRepo;
  final WoodyRealtimeService? _realtime;
  final AuthRepository? _auth;

  /// Last-known auth state, so the [authStateChanges] listener can ignore
  /// emissions that don't flip signed-in ↔ signed-out (token refresh, no-op
  /// clear) and only reload on a genuine transition.
  bool _wasAuthed;

  StreamSubscription<TokenPair?>? _authSub;
  StreamSubscription<RealtimeEvent>? _eventsSub;

  /// Sorts the merged list newest-first and emits. Centralises the ordering
  /// so every code path that touches `state.items` gets the same shape.
  void _emitMerged(List<NotificationModel> items) {
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(status: NotificationsStatus.ready, items: items));
    _nudgeOsBadge();
  }

  void _nudgeOsBadge() {
    if (!sl.isRegistered<BadgeSyncController>()) return;
    unawaited(sl<BadgeSyncController>().refreshNotificationUnread());
  }

  Future<void> load() async {
    emit(state.copyWith(status: NotificationsStatus.loading, clearError: true));

    // Guest gate: `GET /notifications` 401s when signed out (it doesn't return
    // an empty list), so firing it for a guest is a doomed call — skip it
    // entirely and let public news carry the screen. When `_auth` is absent
    // (tests over the mock source) assume authed so existing fixtures keep
    // exercising the personal path. `isAuthenticated` reads the cached token,
    // so this never races a storage round-trip.
    final authed = _auth?.isAuthenticated ?? true;

    // Two independent sources, fetched concurrently but isolated: a failure in
    // one must NOT blank the whole screen. Public news always shows; personal
    // notifications layer on when authed and the call succeeds.
    final results = await Future.wait([
      // Fetch BOTH surfaces' rows — this cubit is root-scoped and shared by
      // the customer inbox AND the seller inbox (each filters its own audience
      // client-side via [NotificationsState.customerItems] / seller items). A
      // mode-scoped fetch here would starve the other mode.
      if (authed)
        _safeList(_repo.list)
      else
        Future<List<NotificationModel>?>.value(null),
      if (_newsRepo != null)
        _safeList(_newsRepo.list)
      else
        Future<List<NotificationModel>?>.value(null),
    ]);
    final personal = results[0];
    final news = results[1];

    // Hard error only when nothing usable came back: no source succeeded AND at
    // least one was actually attempted. A guest skips the personal fetch (not a
    // failure), so the screen then rests on news alone — only a news failure
    // with no personal source is a true all-failed case.
    final personalOk = authed && personal != null;
    final newsOk = _newsRepo != null && news != null;
    final attemptedAny = authed || _newsRepo != null;
    if (attemptedAny && !personalOk && !newsOk) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          error: 'notifications_load_failed',
        ),
      );
      return;
    }

    _emitMerged([...?personal, ...?news]);
  }

  /// Runs a list fetch, returning `null` on failure (so the caller can tell a
  /// failed source from an empty one) instead of letting the throw bubble up
  /// and tank the whole inbox.
  Future<List<NotificationModel>?> _safeList(
    Future<List<NotificationModel>> Function() fetch,
  ) async {
    try {
      return await fetch();
    } catch (_) {
      return null;
    }
  }

  /// Optimistically flips `isRead` then persists. Routes the write by kind:
  /// personal notifications hit the Woody REST endpoint (server-side
  /// `is_read` flip), news items hit Hive (per-device).
  Future<void> markRead(String id) async {
    final idx = state.items.indexWhere((n) => n.id == id);
    if (idx < 0 || state.items[idx].isRead) return;
    final previous = state.items;
    final target = previous[idx];
    final next = List<NotificationModel>.from(previous);
    next[idx] = target.copyWith(isRead: true);
    emit(state.copyWith(items: next));
    _nudgeOsBadge();
    try {
      if (target.kind == NotificationKind.news) {
        await _newsRepo?.markRead(id);
      } else {
        await _repo.markRead(id);
      }
    } catch (e) {
      emit(state.copyWith(items: previous, error: apiErrorMessage(e)));
    }
  }

  /// Marks every unread notification on [mode]'s surface read (default:
  /// customer). Scoped so "mark all read" on the customer inbox never clears
  /// the seller panel's unread, and vice-versa — the seller inbox passes
  /// `mode: 'seller'`. News is a customer-surface concern, so it's only marked
  /// when clearing the customer surface.
  Future<void> markAllRead({String mode = 'customer'}) async {
    final isCustomer = mode != AppMode.seller.name;
    bool onSurface(NotificationModel n) =>
        (n.resolveTargetMode() == AppMode.customer) == isCustomer;

    if (!state.items.any((n) => !n.isRead && onSurface(n))) return;

    final previous = state.items;
    final next = previous
        .map((n) => (!n.isRead && onSurface(n)) ? n.copyWith(isRead: true) : n)
        .toList(growable: false);
    emit(state.copyWith(items: next));
    _nudgeOsBadge();

    final visibleNewsIds = isCustomer
        ? previous
              .where((n) => n.kind == NotificationKind.news && !n.isRead)
              .map((n) => n.id)
        : const <String>[];

    // Personal table + local news set, persisted independently. A guest (or a
    // failing personal endpoint) must not roll back the news mark — so only
    // revert the optimistic update when EVERY write failed.
    final results = await Future.wait([
      _safeRun(() => _repo.markAllRead(mode: mode)),
      if (_newsRepo != null && isCustomer)
        _safeRun(() => _newsRepo.markAllRead(visibleNewsIds))
      else
        Future.value(true),
    ]);
    if (results.every((ok) => !ok)) {
      emit(state.copyWith(items: previous, error: 'mark_all_read_failed'));
    }
  }

  /// Runs a write, returning whether it succeeded — lets the caller keep an
  /// optimistic update alive when only one of several writes fails.
  Future<bool> _safeRun(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    await _eventsSub?.cancel();
    return super.close();
  }
}

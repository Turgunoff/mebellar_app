import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/app_mode.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/network/token_store.dart';
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

  int get unreadCount => items.where((n) => !n.isRead).length;

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
///   * Public news (`GET /catalog/news`) — broadcast, read-state in Hive.
///
/// Live updates: a `notification` event on [WoodyRealtimeService] triggers a
/// reload (the FCM foreground push does the same); news has no live channel and
/// refreshes on [load]. Re-loads on sign-in/out via [AuthRepository].
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(
    this._repo, {
    WoodyRealtimeService? realtime,
    AuthRepository? auth,
    NewsDataSource? newsRepo,
  }) : _realtime = realtime,
       _auth = auth,
       _newsRepo = newsRepo,
       super(const NotificationsState()) {
    _authSub = _auth?.authStateChanges.listen((_) => load());
    _eventsSub = _realtime?.eventsOfType('notification').listen((_) => load());
  }

  final NotificationDataSource _repo;
  final NewsDataSource? _newsRepo;
  final WoodyRealtimeService? _realtime;
  final AuthRepository? _auth;

  StreamSubscription<TokenPair?>? _authSub;
  StreamSubscription<RealtimeEvent>? _eventsSub;

  /// Sorts the merged list newest-first and emits. Centralises the ordering
  /// so every code path that touches `state.items` gets the same shape.
  void _emitMerged(List<NotificationModel> items) {
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(status: NotificationsStatus.ready, items: items));
  }

  Future<void> load() async {
    emit(state.copyWith(status: NotificationsStatus.loading, clearError: true));

    // Two independent sources, fetched concurrently but isolated: a failure in
    // one must NOT blank the whole screen. Public news always shows; personal
    // notifications layer on when the authed call succeeds. (`GET /notifications`
    // returns 401 for guests — not an empty list — so the personal fetch
    // legitimately fails when signed out; that's fine, news still renders.)
    final results = await Future.wait([
      // Customer surface only: the buyer's inbox + home bell must never show
      // seller-panel alerts (new order, product approved, …). The backend
      // filters on data->>'mode'; seller-audience rows are surfaced separately
      // by the profile's seller-panel badge ([SellerInboxBadgeCubit]).
      _safeList(() => _repo.list(mode: AppMode.customer.name)),
      if (_newsRepo != null)
        _safeList(_newsRepo.list)
      else
        Future<List<NotificationModel>?>.value(null),
    ]);
    final personal = results[0];
    final news = results[1];

    // Hard error only when BOTH sources fail (e.g. no connectivity) — then
    // there's genuinely nothing to show and the retry button is the right UX.
    if (personal == null && news == null) {
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

  Future<void> markAllRead() async {
    if (state.unreadCount == 0) return;
    final previous = state.items;
    final next = previous
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList(growable: false);
    emit(state.copyWith(items: next));

    final visibleNewsIds = previous
        .where((n) => n.kind == NotificationKind.news && !n.isRead)
        .map((n) => n.id);

    // Personal table + local news set, persisted independently. A guest (or a
    // failing personal endpoint) must not roll back the news mark — so only
    // revert the optimistic update when EVERY write failed.
    final results = await Future.wait([
      // Scope the bulk read to the customer surface so it never clears the
      // seller panel's unread (which the user sees only in seller mode).
      _safeRun(() => _repo.markAllRead(mode: AppMode.customer.name)),
      if (_newsRepo != null)
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

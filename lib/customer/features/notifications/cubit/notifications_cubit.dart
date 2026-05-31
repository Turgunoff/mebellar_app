import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/auth_repository.dart';
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
    try {
      // Personal list is empty for anonymous users (no auth.uid → RLS
      // returns nothing). News is fetched unconditionally.
      final results = await Future.wait([
        _repo.list(),
        if (_newsRepo != null)
          _newsRepo.list()
        else
          Future.value(<NotificationModel>[]),
      ]);
      final merged = [...results[0], ...results[1]];
      _emitMerged(merged);
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          error: e.toString(),
        ),
      );
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
      emit(state.copyWith(items: previous, error: e.toString()));
    }
  }

  Future<void> markAllRead() async {
    if (state.unreadCount == 0) return;
    final previous = state.items;
    final next = previous
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList(growable: false);
    emit(state.copyWith(items: next));
    try {
      // Two writes in parallel — one for the personal table, one for the
      // local news set. Either failing rolls the optimistic update back.
      final visibleNewsIds = previous
          .where((n) => n.kind == NotificationKind.news && !n.isRead)
          .map((n) => n.id);
      await Future.wait([
        _repo.markAllRead(),
        if (_newsRepo != null)
          _newsRepo.markAllRead(visibleNewsIds)
        else
          Future<void>.value(),
      ]);
    } catch (e) {
      emit(state.copyWith(items: previous, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    await _eventsSub?.cancel();
    return super.close();
  }
}

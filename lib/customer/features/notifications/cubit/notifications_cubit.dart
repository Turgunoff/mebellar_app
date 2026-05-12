import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logging/talker.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/repositories/news_repository.dart';
import '../../../../shared/repositories/supabase_notifications_repository.dart';

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

/// Inbox cubit. Surfaces the union of two streams:
///   * Personal notifications (`public.notifications`) — one row per user,
///     RLS scopes to auth.uid(). Empty when signed out.
///   * Public news (`public.news`) — broadcast rows visible to anonymous
///     and authenticated users alike. Read-state tracked locally in Hive.
///
/// Both sources push live updates over Supabase Realtime so the bell badge
/// stays in sync without manual refresh.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(
    this._repo, {
    SupabaseClient? supabase,
    NewsDataSource? newsRepo,
  })  : _supabase = supabase,
        _newsRepo = newsRepo,
        super(const NotificationsState()) {
    _subscribeToAuth();
    _openNewsChannel();
  }

  final NotificationDataSource _repo;
  final NewsDataSource? _newsRepo;
  final SupabaseClient? _supabase;

  RealtimeChannel? _personalChannel;
  RealtimeChannel? _newsChannel;
  StreamSubscription<AuthState>? _authSub;
  String? _subscribedUserId;

  void _subscribeToAuth() {
    final client = _supabase;
    if (client == null) return;
    final current = client.auth.currentUser?.id;
    if (current != null) _openPersonalChannel(current);
    _authSub = client.auth.onAuthStateChange.listen((data) {
      final newId = data.session?.user.id;
      if (newId == _subscribedUserId) return;
      _closePersonalChannel();
      if (newId != null) _openPersonalChannel(newId);
      // Reload to flush stale per-user rows after a sign-out / sign-in.
      load();
    });
  }

  void _openPersonalChannel(String userId) {
    final client = _supabase;
    if (client == null) return;
    _subscribedUserId = userId;
    _personalChannel = client
        .channel('public:notifications:user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _onPersonalInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _onPersonalUpdate,
        )
        .subscribe();
    talker.info('Realtime: subscribed to notifications for $userId');
  }

  void _closePersonalChannel() {
    final ch = _personalChannel;
    if (ch == null) return;
    _supabase?.removeChannel(ch);
    _personalChannel = null;
    _subscribedUserId = null;
  }

  /// News channel is opened once and stays alive across sign-in / sign-out
  /// transitions because broadcasts are not user-scoped.
  void _openNewsChannel() {
    final client = _supabase;
    if (client == null || _newsRepo == null) return;
    _newsChannel = client
        .channel('public:news')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'news',
          callback: _onNewsInsert,
        )
        .subscribe();
    talker.info('Realtime: subscribed to news');
  }

  void _onPersonalInsert(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      if (row.isEmpty) return;
      final incoming = NotificationModel.fromJson(row);
      if (state.items.any((n) => n.id == incoming.id)) return;
      _emitMerged([incoming, ...state.items]);
    } catch (e, st) {
      talker.handle(e, st, 'Realtime personal insert handler failed');
    }
  }

  void _onPersonalUpdate(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      if (row.isEmpty) return;
      final updated = NotificationModel.fromJson(row);
      final idx = state.items.indexWhere((n) => n.id == updated.id);
      if (idx < 0) return;
      final next = List<NotificationModel>.from(state.items);
      next[idx] = updated;
      _emitMerged(next);
    } catch (e, st) {
      talker.handle(e, st, 'Realtime personal update handler failed');
    }
  }

  void _onNewsInsert(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      if (row.isEmpty) return;
      // News rows skip the constructor-with-RLS pattern — build manually so
      // we can default `is_active` to true (Realtime ignores RLS filters).
      if (row['is_active'] == false) return;
      final id = row['id'] as String;
      if (state.items.any((n) => n.id == id)) return;
      final incoming = NotificationModel(
        id: id,
        userId: 'broadcast',
        title: (row['title'] as String?) ?? '',
        body: (row['body'] as String?) ?? '',
        kind: NotificationKind.news,
        referenceId: null,
        isRead: false,
        createdAt: DateTime.parse(row['published_at'] as String),
      );
      _emitMerged([incoming, ...state.items]);
    } catch (e, st) {
      talker.handle(e, st, 'Realtime news insert handler failed');
    }
  }

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
        if (_newsRepo != null) _newsRepo.list() else Future.value(<NotificationModel>[]),
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

  /// Optimistically flips `isRead` then persists. Routes the write to the
  /// correct backend based on kind: personal notifications hit Supabase
  /// (server-side `is_read` flip), news items hit Hive (per-device).
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
        if (_newsRepo != null) _newsRepo.markAllRead(visibleNewsIds)
        else Future<void>.value(),
      ]);
    } catch (e) {
      emit(state.copyWith(items: previous, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    _closePersonalChannel();
    final newsCh = _newsChannel;
    if (newsCh != null) {
      _supabase?.removeChannel(newsCh);
      _newsChannel = null;
    }
    return super.close();
  }
}

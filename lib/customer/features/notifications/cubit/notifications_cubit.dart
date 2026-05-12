import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logging/talker.dart';
import '../../../../shared/models/notification_model.dart';
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

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._repo, {SupabaseClient? supabase})
      : _supabase = supabase,
        super(const NotificationsState()) {
    _subscribeToAuth();
  }

  final NotificationDataSource _repo;
  final SupabaseClient? _supabase;

  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;
  String? _subscribedUserId;

  /// Re-subscribes whenever the auth state changes — sign-out tears the
  /// channel down (so we don't keep streaming for an anonymous user) and
  /// the next sign-in opens a fresh channel filtered by the new user id.
  void _subscribeToAuth() {
    final client = _supabase;
    if (client == null) return;
    final current = client.auth.currentUser?.id;
    if (current != null) _openRealtimeChannel(current);
    _authSub = client.auth.onAuthStateChange.listen((data) {
      final newId = data.session?.user.id;
      if (newId == _subscribedUserId) return;
      _closeRealtimeChannel();
      if (newId != null) _openRealtimeChannel(newId);
    });
  }

  /// Opens a Postgres-changes channel scoped to this user's notifications.
  /// The `filter` arg pushes the WHERE clause down to the realtime server
  /// so the client only receives rows that already pass RLS — no wasted
  /// bandwidth for other users' inserts.
  void _openRealtimeChannel(String userId) {
    final client = _supabase;
    if (client == null) return;
    _subscribedUserId = userId;
    _channel = client
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
          callback: _onRealtimeInsert,
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
          callback: _onRealtimeUpdate,
        )
        .subscribe();
    talker.info('Realtime: subscribed to notifications for $userId');
  }

  void _closeRealtimeChannel() {
    final ch = _channel;
    if (ch == null) return;
    _supabase?.removeChannel(ch);
    _channel = null;
    _subscribedUserId = null;
  }

  void _onRealtimeInsert(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      if (row.isEmpty) return;
      final incoming = NotificationModel.fromJson(row);
      // Guard against double-insert: if we already have this id (e.g. a
      // prior load() raced with the realtime callback), skip.
      if (state.items.any((n) => n.id == incoming.id)) return;
      // Prepend so the newest entry tops the inbox + bumps the badge.
      final next = [incoming, ...state.items];
      emit(state.copyWith(status: NotificationsStatus.ready, items: next));
    } catch (e, st) {
      talker.handle(e, st, 'Realtime insert handler failed');
    }
  }

  /// Catches `is_read` flips from another device (logged in twice). Without
  /// this, marking a notification read on phone A would leave phone B
  /// showing the badge until the user reopened the inbox.
  void _onRealtimeUpdate(PostgresChangePayload payload) {
    try {
      final row = payload.newRecord;
      if (row.isEmpty) return;
      final updated = NotificationModel.fromJson(row);
      final idx = state.items.indexWhere((n) => n.id == updated.id);
      if (idx < 0) return;
      final next = List<NotificationModel>.from(state.items);
      next[idx] = updated;
      emit(state.copyWith(items: next));
    } catch (e, st) {
      talker.handle(e, st, 'Realtime update handler failed');
    }
  }

  Future<void> load() async {
    emit(state.copyWith(status: NotificationsStatus.loading, clearError: true));
    try {
      final list = await _repo.list();
      emit(
        state.copyWith(status: NotificationsStatus.ready, items: list),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          error: e.toString(),
        ),
      );
    }
  }

  /// Optimistically flips `isRead` then persists. Roll back the local update
  /// if the remote write throws so the badge stays accurate.
  Future<void> markRead(String id) async {
    final idx = state.items.indexWhere((n) => n.id == id);
    if (idx < 0 || state.items[idx].isRead) return;
    final previous = state.items;
    final next = List<NotificationModel>.from(previous);
    next[idx] = next[idx].copyWith(isRead: true);
    emit(state.copyWith(items: next));
    try {
      await _repo.markRead(id);
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
      await _repo.markAllRead();
    } catch (e) {
      emit(state.copyWith(items: previous, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    _closeRealtimeChannel();
    return super.close();
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  NotificationsCubit(this._repo) : super(const NotificationsState());

  final NotificationDataSource _repo;

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
}

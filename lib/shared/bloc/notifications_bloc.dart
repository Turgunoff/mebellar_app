import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/app_notification.dart';
import '../repositories/notifications_repository.dart';

sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();
  @override
  List<Object?> get props => const [];
}

class NotificationsRequested extends NotificationsEvent {
  const NotificationsRequested();
}

class NotificationRead extends NotificationsEvent {
  const NotificationRead(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class NotificationsAllRead extends NotificationsEvent {
  const NotificationsAllRead({this.mode});
  final String? mode;
  @override
  List<Object?> get props => [mode];
}

class _NotificationsListChanged extends NotificationsEvent {
  const _NotificationsListChanged(this.list);
  final List<AppNotification> list;
  @override
  List<Object?> get props => [list];
}

enum NotificationsStatus { initial, loading, ready, failure }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.items = const [],
    this.error,
  });

  final NotificationsStatus status;
  final List<AppNotification> items;
  final String? error;

  int get unread => items.where((n) => !n.read).length;
  int unreadFor(String mode) =>
      items.where((n) => !n.read && n.kind.mode == mode).length;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? items,
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

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc(this._repo) : super(const NotificationsState()) {
    on<NotificationsRequested>(_onRequested);
    on<NotificationRead>(_onRead);
    on<NotificationsAllRead>(_onAllRead);
    on<_NotificationsListChanged>(
        (event, emit) => emit(state.copyWith(items: event.list)));

    _sub = _repo.watch().listen((list) => add(_NotificationsListChanged(list)));
  }

  final NotificationsRepository _repo;
  StreamSubscription<List<AppNotification>>? _sub;

  Future<void> _onRequested(
    NotificationsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(status: NotificationsStatus.loading, clearError: true));
    try {
      final list = await _repo.list();
      emit(state.copyWith(status: NotificationsStatus.ready, items: list));
    } catch (e) {
      emit(state.copyWith(
          status: NotificationsStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRead(
    NotificationRead event,
    Emitter<NotificationsState> emit,
  ) async {
    await _repo.markRead(event.id);
  }

  Future<void> _onAllRead(
    NotificationsAllRead event,
    Emitter<NotificationsState> emit,
  ) async {
    await _repo.markAllRead(mode: event.mode);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

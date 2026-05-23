import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/chat.dart';
import '../../repositories/chat_repository.dart';

enum ChatsListStatus { initial, loading, ready, failure }

class ChatsListState extends Equatable {
  const ChatsListState({
    this.status = ChatsListStatus.initial,
    this.chats = const [],
    this.error,
  });

  final ChatsListStatus status;
  final List<Chat> chats;
  final String? error;

  /// Total unread count across visible chats for [viewer] — feeds the
  /// "Suhbatlar" entry-point badge on the profile screen.
  int totalUnreadFor(ChatSenderRole viewer) =>
      chats.fold(0, (sum, c) => sum + c.unreadFor(viewer));

  ChatsListState copyWith({
    ChatsListStatus? status,
    List<Chat>? chats,
    String? error,
    bool clearError = false,
  }) {
    return ChatsListState(
      status: status ?? this.status,
      chats: chats ?? this.chats,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, chats, error];
}

/// Live list of the current user's chats. Subscribes to Supabase Realtime
/// so unread counters and `last_message_at` updates land without polling.
class ChatsListCubit extends Cubit<ChatsListState> {
  ChatsListCubit(this._repo) : super(const ChatsListState()) {
    _subscribe();
  }

  final ChatRepository _repo;
  StreamSubscription<List<Chat>>? _sub;

  void _subscribe() {
    emit(state.copyWith(status: ChatsListStatus.loading, clearError: true));
    // `myChatsStream` primes itself with a snapshot on subscribe, so we
    // don't need a separate initial `listMyChats` call — first emission
    // doubles as the loaded state.
    _sub = _repo.myChatsStream().listen(
      (chats) =>
          emit(state.copyWith(status: ChatsListStatus.ready, chats: chats)),
      onError: (Object e) => emit(
        state.copyWith(status: ChatsListStatus.failure, error: e.toString()),
      ),
    );
  }

  Future<void> refresh() async {
    try {
      final chats = await _repo.listMyChats();
      emit(state.copyWith(status: ChatsListStatus.ready, chats: chats));
    } catch (e) {
      emit(state.copyWith(
        status: ChatsListStatus.failure,
        error: e.toString(),
      ));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

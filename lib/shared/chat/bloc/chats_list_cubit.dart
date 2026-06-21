import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_error_messages.dart';
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

/// Live list of the current user's chats. Subscribes to Woody Realtime
/// so unread counters and `last_message_at` updates land without polling.
/// [_viewer] scopes the list to the active app surface so a buyer never
/// sees their incoming shop chats and vice versa.
class ChatsListCubit extends Cubit<ChatsListState> {
  ChatsListCubit(this._repo, this._viewer) : super(const ChatsListState()) {
    _subscribe();
  }

  final ChatRepository _repo;
  final ChatSenderRole _viewer;
  StreamSubscription<List<Chat>>? _sub;

  void _subscribe() {
    emit(state.copyWith(status: ChatsListStatus.loading, clearError: true));
    // `myChatsStream` primes itself with a snapshot on subscribe, so we
    // don't need a separate initial `listMyChats` call — first emission
    // doubles as the loaded state.
    _sub = _repo.myChatsStream(as: _viewer).listen(
      (chats) =>
          emit(state.copyWith(status: ChatsListStatus.ready, chats: chats)),
      onError: (Object e) => emit(
        state.copyWith(status: ChatsListStatus.failure, error: apiErrorMessage(e)),
      ),
    );
  }

  Future<void> refresh() async {
    try {
      final chats = await _repo.listMyChats(as: _viewer);
      emit(state.copyWith(status: ChatsListStatus.ready, chats: chats));
    } catch (e) {
      emit(state.copyWith(
        status: ChatsListStatus.failure,
        error: apiErrorMessage(e),
      ));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

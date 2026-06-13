import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/chat.dart';
import '../../repositories/chat_repository.dart';

/// Total unread-message count for [_viewer] across every conversation — feeds
/// the red badge on the profile "Suhbatlar" entry. Rides the same
/// realtime-wired `myChatsStream` the list screen uses, so the badge tracks
/// inbound messages and read-state changes live (the repo nudges the stream on
/// `markAsRead`). One lightweight count, recomputed on each list emission.
class TotalUnreadChatsCubit extends Cubit<int> {
  TotalUnreadChatsCubit(this._repo, this._viewer) : super(0) {
    _subscribe();
  }

  final ChatRepository _repo;
  final ChatSenderRole _viewer;
  StreamSubscription<List<Chat>>? _sub;

  void _subscribe() {
    _sub = _repo.myChatsStream().listen(
      (chats) =>
          emit(chats.fold<int>(0, (sum, c) => sum + c.unreadFor(_viewer))),
      // Keep the last good count on a transient stream error — a badge that
      // freezes is far better than one that throws or flashes to zero.
      onError: (_) {},
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

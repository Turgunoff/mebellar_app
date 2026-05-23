import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/chat.dart';
import '../../models/chat_message.dart';
import '../../repositories/chat_repository.dart';

enum ChatThreadStatus { initial, loading, ready, failure }

class ChatThreadState extends Equatable {
  const ChatThreadState({
    this.status = ChatThreadStatus.initial,
    this.chat,
    this.messages = const [],
    this.sending = false,
    this.error,
  });

  final ChatThreadStatus status;
  final Chat? chat;

  /// Chronological — oldest first. The UI uses `reverse: true` on the
  /// ListView and appends new messages to the tail.
  final List<ChatMessage> messages;

  /// True while a send is in flight; the composer disables its button
  /// to avoid double-sends on a slow connection.
  final bool sending;

  final String? error;

  ChatThreadState copyWith({
    ChatThreadStatus? status,
    Chat? chat,
    List<ChatMessage>? messages,
    bool? sending,
    String? error,
    bool clearError = false,
  }) {
    return ChatThreadState(
      status: status ?? this.status,
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, chat, messages, sending, error];
}

/// Single-thread cubit. Loads the chat + initial page of messages,
/// subscribes to new inserts via realtime, and exposes send/markAsRead.
class ChatThreadCubit extends Cubit<ChatThreadState> {
  ChatThreadCubit({
    required ChatRepository repo,
    required this.chatId,
    required this.viewer,
  })  : _repo = repo,
        super(const ChatThreadState());

  final ChatRepository _repo;
  final String chatId;

  /// Which side of the conversation the local user is on. Stamped on
  /// outgoing messages and used to align bubbles in the UI.
  final ChatSenderRole viewer;

  StreamSubscription<ChatMessage>? _sub;

  Future<void> load() async {
    emit(state.copyWith(status: ChatThreadStatus.loading, clearError: true));
    try {
      final chat = await _repo.getChat(chatId);
      final messages = await _repo.listMessages(chatId);
      emit(state.copyWith(
        status: ChatThreadStatus.ready,
        chat: chat,
        messages: messages,
      ));
      _subscribe();
      // Don't await — the read marker is fire-and-forget; UI doesn't
      // need to block on it and we don't want a slow RPC to delay the
      // thread becoming interactive.
      unawaited(markAsRead());
    } catch (e) {
      emit(state.copyWith(
        status: ChatThreadStatus.failure,
        error: e.toString(),
      ));
    }
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _repo.messagesStream(chatId).listen((msg) {
      // Realtime can deliver our own insert too — dedupe by id so the
      // optimistic add doesn't show twice.
      if (state.messages.any((m) => m.id == msg.id)) return;
      emit(state.copyWith(
        messages: [...state.messages, msg],
      ));
      // Auto-mark-read for messages from the other side while the
      // thread is on screen.
      if (msg.senderRole != viewer) {
        unawaited(markAsRead());
      }
    });
  }

  Future<void> sendText(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || state.sending) return;
    emit(state.copyWith(sending: true, clearError: true));
    try {
      final msg =
          await _repo.sendText(chatId: chatId, body: trimmed, as: viewer);
      // Realtime *might* deliver this before the await returns. The
      // dedupe in the subscription handles either order.
      if (!state.messages.any((m) => m.id == msg.id)) {
        emit(state.copyWith(
          sending: false,
          messages: [...state.messages, msg],
        ));
      } else {
        emit(state.copyWith(sending: false));
      }
    } catch (e) {
      emit(state.copyWith(sending: false, error: e.toString()));
    }
  }

  Future<void> sendImage({
    required Uint8List bytes,
    required String mimeType,
    String? caption,
  }) async {
    if (state.sending) return;
    emit(state.copyWith(sending: true, clearError: true));
    try {
      final msg = await _repo.sendImage(
        chatId: chatId,
        bytes: bytes,
        mimeType: mimeType,
        as: viewer,
        caption: caption,
      );
      if (!state.messages.any((m) => m.id == msg.id)) {
        emit(state.copyWith(
          sending: false,
          messages: [...state.messages, msg],
        ));
      } else {
        emit(state.copyWith(sending: false));
      }
    } catch (e) {
      emit(state.copyWith(sending: false, error: e.toString()));
    }
  }

  Future<void> markAsRead() async {
    try {
      await _repo.markAsRead(chatId);
    } catch (_) {
      // Silent — read receipts are non-critical. Keep the UI responsive
      // even if the RPC fails (e.g. brief network hiccup).
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

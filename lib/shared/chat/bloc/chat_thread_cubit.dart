import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_error_messages.dart';
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
    AnalyticsService? analytics,
  }) : _repo = repo,
       _analytics = analytics,
       super(const ChatThreadState());

  final ChatRepository _repo;
  final AnalyticsService? _analytics;
  final String chatId;

  /// Which side of the conversation the local user is on. Stamped on
  /// outgoing messages and used to align bubbles in the UI.
  final ChatSenderRole viewer;

  StreamSubscription<ChatMessage>? _sub;
  StreamSubscription<void>? _orderSub;

  /// Monotonic counter so two optimistic inserts in the same microsecond get
  /// distinct local ids.
  int _localSeq = 0;

  Future<void> load() async {
    emit(state.copyWith(status: ChatThreadStatus.loading, clearError: true));
    try {
      final chat = await _repo.getChat(chatId);
      final messages = await _repo.listMessages(chatId);
      emit(
        state.copyWith(
          status: ChatThreadStatus.ready,
          chat: chat,
          messages: messages,
        ),
      );
      _subscribe();
      _subscribeOrder();
      // Don't await — the read marker is fire-and-forget; UI doesn't
      // need to block on it and we don't want a slow RPC to delay the
      // thread becoming interactive.
      unawaited(markAsRead());
      unawaited(
        _analytics?.chatOpened(chatId: chatId, viewerRole: viewer.value),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ChatThreadStatus.failure,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _repo.messagesStream(chatId).listen((msg) {
      // Already holding this exact server row (it arrived twice) — ignore.
      if (state.messages.any((m) => m.id == msg.id)) return;

      // The realtime echo of a message we just sent carries a fresh server
      // id, NOT our optimistic local id, so an id check alone would let it
      // append as a twin while the POST is still in flight. Match it to the
      // oldest still-"sending" placeholder with the same sender + content and
      // swap it in place instead, so the bubble never shows twice. `_reconcile`
      // then no-ops when the POST finally returns the same row.
      final pendingIdx = state.messages.indexWhere(
        (m) =>
            m.status == ChatMessageStatus.sending &&
            m.localId != null &&
            m.senderRole == msg.senderRole &&
            m.body == msg.body &&
            m.attachmentUrl == msg.attachmentUrl,
      );
      if (pendingIdx != -1) {
        final next = [...state.messages];
        next[pendingIdx] = msg;
        emit(state.copyWith(messages: next));
        return;
      }

      emit(state.copyWith(messages: [...state.messages, msg]));
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
    // Optimistic: show the bubble instantly with a "sending" clock, then
    // reconcile to the server row (or flip to "failed") when the POST settles.
    final pending = _optimistic(body: trimmed);
    emit(
      state.copyWith(
        sending: true,
        clearError: true,
        messages: [...state.messages, pending],
      ),
    );
    try {
      final msg = await _repo.sendText(
        chatId: chatId,
        body: trimmed,
        as: viewer,
      );
      _reconcile(pending.localId!, msg);
      unawaited(
        _analytics?.chatMessageSent(
          chatId: chatId,
          viewerRole: viewer.value,
          hasImage: false,
        ),
      );
    } catch (e) {
      _failOptimistic(pending.localId!, e);
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
      // Realtime can race the response; dedupe by id either way.
      if (!state.messages.any((m) => m.id == msg.id)) {
        emit(
          state.copyWith(sending: false, messages: [...state.messages, msg]),
        );
      } else {
        emit(state.copyWith(sending: false));
      }
      unawaited(
        _analytics?.chatMessageSent(
          chatId: chatId,
          viewerRole: viewer.value,
          hasImage: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(sending: false, error: _sendErrorMessage(e)));
    }
  }

  /// Subscribes to order-level realtime so the status banner above the thread
  /// reflects a status move (e.g. "Tayyorlanmoqda" → "Yo'lda") the instant the
  /// observing party is notified — no re-entering the screen.
  void _subscribeOrder() {
    final orderId = state.chat?.orderId;
    if (orderId == null) return;
    _orderSub?.cancel();
    _orderSub = _repo.orderEventsStream(orderId).listen((_) async {
      try {
        final fresh = await _repo.getChat(chatId);
        if (!isClosed) emit(state.copyWith(chat: fresh));
      } catch (_) {
        // A transient refetch failure just leaves the banner as-is.
      }
    });
  }

  ChatMessage _optimistic({String? body, String? attachmentUrl}) {
    final localId =
        'local-${DateTime.now().microsecondsSinceEpoch}-'
        '${_localSeq++}';
    return ChatMessage(
      id: localId,
      localId: localId,
      chatId: chatId,
      // The local user's id isn't needed for rendering — alignment keys off
      // senderRole — so an empty sender id is fine for the placeholder.
      senderId: '',
      senderRole: viewer,
      body: body,
      attachmentUrl: attachmentUrl,
      createdAt: DateTime.now(),
      status: ChatMessageStatus.sending,
    );
  }

  /// Swaps the optimistic placeholder [localId] for the confirmed server
  /// [serverMsg]. If realtime already delivered the server row, drop the
  /// placeholder and keep the real one (no duplicate).
  void _reconcile(String localId, ChatMessage serverMsg) {
    final alreadyHasServer = state.messages.any((m) => m.id == serverMsg.id);
    final next = <ChatMessage>[];
    for (final m in state.messages) {
      if (m.localId == localId) {
        if (!alreadyHasServer) next.add(serverMsg);
        // else: drop the placeholder, the server copy is already present.
      } else {
        next.add(m);
      }
    }
    emit(state.copyWith(sending: false, messages: next));
  }

  void _failOptimistic(String localId, Object error) {
    final next = state.messages
        .map(
          (m) => m.localId == localId
              ? m.copyWith(status: ChatMessageStatus.failed)
              : m,
        )
        .toList();
    emit(
      state.copyWith(
        sending: false,
        messages: next,
        error: _sendErrorMessage(error),
      ),
    );
  }

  String _sendErrorMessage(Object e) {
    if (e is StateError && e.message == 'chat_image_unavailable') {
      return tr('chat.image_upload_failed');
    }
    return apiErrorMessage(e);
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
    await _orderSub?.cancel();
    return super.close();
  }
}

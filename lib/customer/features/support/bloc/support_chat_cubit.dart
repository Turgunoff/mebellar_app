import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/network/api_error_messages.dart';
import '../models/support_message.dart';
import '../repository/support_chat_repository.dart';

enum SupportChatStatus { initial, loading, ready, failure }

class SupportChatState extends Equatable {
  const SupportChatState({
    this.status = SupportChatStatus.initial,
    this.chatId,
    this.messages = const [],
    this.sending = false,
    this.error,
  });

  final SupportChatStatus status;
  final String? chatId;

  /// Chronological — oldest first. The UI uses `reverse: true` on the
  /// ListView and appends new messages to the tail.
  final List<SupportMessage> messages;

  /// True while a send is in flight; the composer disables itself to avoid
  /// double-sends on a slow connection.
  final bool sending;

  final String? error;

  SupportChatState copyWith({
    SupportChatStatus? status,
    String? chatId,
    List<SupportMessage>? messages,
    bool? sending,
    String? error,
    bool clearError = false,
  }) {
    return SupportChatState(
      status: status ?? this.status,
      chatId: chatId ?? this.chatId,
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, chatId, messages, sending, error];
}

/// Single-thread support cubit. Loads the thread + messages, subscribes to
/// admin replies + read receipts over realtime, and exposes send/markRead.
/// Mirrors `ChatThreadCubit` but for the single per-user support thread (no
/// order, no status banner, no client-supplied chat id).
class SupportChatCubit extends Cubit<SupportChatState> {
  SupportChatCubit({required SupportChatRepository repo})
    : _repo = repo,
      super(const SupportChatState());

  final SupportChatRepository _repo;

  StreamSubscription<SupportMessage>? _msgSub;
  StreamSubscription<void>? _readSub;

  /// Monotonic counter so two optimistic inserts in the same microsecond get
  /// distinct local ids.
  int _localSeq = 0;

  Future<void> load() async {
    emit(state.copyWith(status: SupportChatStatus.loading, clearError: true));
    try {
      final snap = await _repo.fetchChat();
      emit(
        state.copyWith(
          status: SupportChatStatus.ready,
          chatId: snap.chatId,
          messages: snap.messages,
        ),
      );
      _subscribe();
      // Fire-and-forget — the read marker shouldn't block the thread becoming
      // interactive. fetchChat already marks read server-side, but resend so a
      // race (message landing during load) is still cleared.
      unawaited(markRead());
    } catch (e) {
      emit(
        state.copyWith(
          status: SupportChatStatus.failure,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  void _subscribe() {
    _msgSub?.cancel();
    _msgSub = _repo.messagesStream().listen((msg) {
      // Already holding this exact server row (it arrived twice) — ignore.
      if (state.messages.any((m) => m.id == msg.id)) return;
      emit(state.copyWith(messages: [...state.messages, msg]));
      // The frame is an admin reply by contract; mark read while on screen.
      unawaited(markRead());
    });

    _readSub?.cancel();
    _readSub = _repo.readStream().listen((_) {
      // Admin read our messages — flip every still-unread outgoing bubble to
      // read so the tick goes ✓ → ✓✓.
      final now = DateTime.now();
      final next = state.messages
          .map(
            (m) => m.isMine && m.status == SupportMessageStatus.sent && !m.isRead
                ? m.copyWith(readAt: now)
                : m,
          )
          .toList();
      emit(state.copyWith(messages: next));
    });
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    final pending = _optimistic(
      messageType: SupportMessageType.text,
      textContent: trimmed,
    );
    emit(
      state.copyWith(
        sending: true,
        clearError: true,
        messages: [...state.messages, pending],
      ),
    );
    try {
      final msg = await _repo.sendText(trimmed);
      _reconcile(pending.localId!, msg);
    } catch (e) {
      _failOptimistic(pending.localId!, e);
    }
  }

  Future<void> sendImage({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (state.sending) return;
    emit(state.copyWith(sending: true, clearError: true));
    try {
      final msg = await _repo.sendImage(bytes: bytes, mimeType: mimeType);
      _appendServerRow(msg);
    } catch (e) {
      emit(state.copyWith(sending: false, error: _sendErrorMessage(e)));
    }
  }

  Future<void> sendAudio({
    required Uint8List bytes,
    required String contentType,
    int? durationMs,
  }) async {
    if (state.sending) return;
    emit(state.copyWith(sending: true, clearError: true));
    try {
      final msg = await _repo.sendAudio(
        bytes: bytes,
        contentType: contentType,
        durationMs: durationMs,
      );
      _appendServerRow(msg);
    } catch (e) {
      emit(state.copyWith(sending: false, error: _sendErrorMessage(e)));
    }
  }

  void _appendServerRow(SupportMessage msg) {
    // Realtime can race the response; dedupe by id either way.
    if (!state.messages.any((m) => m.id == msg.id)) {
      emit(state.copyWith(sending: false, messages: [...state.messages, msg]));
    } else {
      emit(state.copyWith(sending: false));
    }
  }

  SupportMessage _optimistic({
    required SupportMessageType messageType,
    String? textContent,
    String? fileUrl,
  }) {
    final localId =
        'local-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}';
    return SupportMessage(
      id: localId,
      localId: localId,
      chatId: state.chatId ?? '',
      senderId: '',
      senderType: SupportSenderType.user,
      messageType: messageType,
      textContent: textContent,
      fileUrl: fileUrl,
      createdAt: DateTime.now(),
      status: SupportMessageStatus.sending,
    );
  }

  /// Swaps the optimistic placeholder [localId] for the confirmed server row.
  void _reconcile(String localId, SupportMessage serverMsg) {
    final alreadyHasServer = state.messages.any((m) => m.id == serverMsg.id);
    final next = <SupportMessage>[];
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
              ? m.copyWith(status: SupportMessageStatus.failed)
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
    if (e is StateError && e.message == 'support_attachment_unavailable') {
      return tr('support.attachment_failed');
    }
    return apiErrorMessage(e);
  }

  Future<void> markRead() async {
    try {
      await _repo.markRead();
    } catch (_) {
      // Silent — read receipts are non-critical.
    }
  }

  /// Re-fetch the thread without a loading flicker — used when the screen
  /// resumes from background (a message the WS missed, delivered only as a
  /// push). Pending optimistic bubbles are preserved.
  Future<void> refresh() async {
    if (state.status != SupportChatStatus.ready) return;
    try {
      final snap = await _repo.fetchChat();
      if (isClosed) return;
      final serverIds = snap.messages.map((m) => m.id).toSet();
      final pending = state.messages.where(
        (m) => m.localId != null && !serverIds.contains(m.id),
      );
      emit(
        state.copyWith(
          chatId: snap.chatId,
          messages: [...snap.messages, ...pending],
        ),
      );
      unawaited(markRead());
    } catch (_) {
      // Transient refetch failure — leave the thread as-is.
    }
  }

  @override
  Future<void> close() async {
    await _msgSub?.cancel();
    await _readSub?.cancel();
    return super.close();
  }
}

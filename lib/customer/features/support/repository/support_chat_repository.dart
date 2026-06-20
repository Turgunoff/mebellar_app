import 'dart:async';
import 'dart:typed_data';

import '../models/support_message.dart';

/// Snapshot of the customer's single support thread — the resolved chat id
/// plus its messages (chronological, oldest first).
typedef SupportChatSnapshot = ({String chatId, List<SupportMessage> messages});

/// Repository abstraction for the customer support chat so screens and blocs
/// can be exercised against a mock without a live backend. Single thread per
/// user — the backend auto-creates it, so the client never supplies a chat id.
abstract class SupportChatRepository {
  /// Load (auto-creating server-side) the customer's support thread plus its
  /// messages. Marks admin messages read server-side as a side effect.
  Future<SupportChatSnapshot> fetchChat();

  /// Send a text-only message. Returns the persisted server row.
  Future<SupportMessage> sendText(String text);

  /// Upload [bytes] as an image attachment and post the message.
  Future<SupportMessage> sendImage({
    required Uint8List bytes,
    required String mimeType,
  });

  /// Upload [bytes] as a voice note and post the message. [contentType] is the
  /// audio MIME (mobile records AAC-LC in an .m4a → `audio/mp4`).
  Future<SupportMessage> sendAudio({
    required Uint8List bytes,
    required String contentType,
    int? durationMs,
  });

  /// Mark admin messages read + zero the customer's unread counter.
  Future<void> markRead();

  /// Read-only unread count for the profile badge — hits `GET /support/unread`,
  /// which (unlike [fetchChat]) does NOT mark anything read. Used to seed the
  /// badge at boot and re-seed on resume (catching pushes received while away).
  Future<int> fetchUnreadCount();

  /// Live stream of new admin replies (emitted only on an admin message).
  Stream<SupportMessage> messagesStream();

  /// Fires locally whenever [markRead] succeeds, so the global unread badge can
  /// reset to 0 without the thread screen reaching up into the badge cubit
  /// (mirrors how the chat repo nudges its list stream on read).
  Stream<void> localReadStream();

  /// Live stream that fires when the admin read the user's messages, so the
  /// outgoing read-receipt ticks flip ✓ → ✓✓.
  Stream<void> readStream();
}

/// In-memory fallback used by tests and offline builds. Models exactly what
/// the live implementation does so blocs/UI work the same against either.
class MockSupportChatRepository implements SupportChatRepository {
  MockSupportChatRepository({this.chatId = 'mock-support-1'});

  final String chatId;
  final List<SupportMessage> _messages = [];
  final _newMessageCtrl = StreamController<SupportMessage>.broadcast();
  final _readCtrl = StreamController<void>.broadcast();
  final _localReadCtrl = StreamController<void>.broadcast();

  /// Settable so tests can seed a non-zero unread count for the badge cubit.
  int unreadCount = 0;

  int _seq = 0;

  @override
  Future<SupportChatSnapshot> fetchChat() async =>
      (chatId: chatId, messages: List<SupportMessage>.unmodifiable(_messages));

  @override
  Future<SupportMessage> sendText(String text) async {
    final msg = _build(
      messageType: SupportMessageType.text,
      textContent: text,
    );
    _messages.add(msg);
    return msg;
  }

  @override
  Future<SupportMessage> sendImage({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final msg = _build(
      messageType: SupportMessageType.image,
      fileUrl: 'https://example.com/mock-support-image.png',
    );
    _messages.add(msg);
    return msg;
  }

  @override
  Future<SupportMessage> sendAudio({
    required Uint8List bytes,
    required String contentType,
    int? durationMs,
  }) async {
    final msg = _build(
      messageType: SupportMessageType.audio,
      fileUrl: 'https://example.com/mock-support-audio.m4a',
    );
    _messages.add(msg);
    return msg;
  }

  @override
  Future<void> markRead() async {
    unreadCount = 0;
    _localReadCtrl.add(null);
  }

  @override
  Future<int> fetchUnreadCount() async => unreadCount;

  @override
  Stream<SupportMessage> messagesStream() => _newMessageCtrl.stream;

  @override
  Stream<void> localReadStream() => _localReadCtrl.stream;

  @override
  Stream<void> readStream() => _readCtrl.stream;

  /// Test helper: simulate an inbound admin reply (bumps the server-side unread
  /// count so a re-seed via [fetchUnreadCount] stays consistent).
  void emitAdminMessage(SupportMessage message) {
    _messages.add(message);
    unreadCount += 1;
    _newMessageCtrl.add(message);
  }

  /// Test helper: simulate the admin reading the user's messages.
  void emitRead() => _readCtrl.add(null);

  SupportMessage _build({
    required SupportMessageType messageType,
    String? textContent,
    String? fileUrl,
  }) {
    return SupportMessage(
      id: 'mock-msg-${_seq++}',
      chatId: chatId,
      senderId: 'mock-user',
      senderType: SupportSenderType.user,
      messageType: messageType,
      textContent: textContent,
      fileUrl: fileUrl,
      createdAt: DateTime.now(),
    );
  }
}

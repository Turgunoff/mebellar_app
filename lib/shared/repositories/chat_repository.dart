import 'dart:async';
import 'dart:typed_data';

import '../models/chat.dart';
import '../models/chat_message.dart';

/// Repository abstraction so screens and blocs can be exercised against a
/// mock without depending on a live backend. Two-sided: the same calls
/// serve customer and seller surfaces; the active role is supplied where
/// the wire format actually needs it (e.g. `sender_role` on insert).
abstract class ChatRepository {
  /// Returns the existing chat for [orderId], or creates one when the
  /// caller is the order's customer and no chat exists yet. Sellers can
  /// only *fetch* — they never trigger lazy creation; if the customer
  /// hasn't opened a thread, there's nothing to fetch.
  Future<Chat> openChatForOrder({required String orderId});

  /// Chats visible to the current user, newest first by last_message_at
  /// then created_at. A single account can be both a buyer and a shop
  /// owner, so [as] scopes the list to the active app surface — customer
  /// mode lists only the user's buyer chats, seller mode only the user's
  /// shop chats. Omitting [as] returns both sides (kept for callers that
  /// don't carry a viewer role).
  Future<List<Chat>> listMyChats({ChatSenderRole? as});

  Future<Chat> getChat(String chatId);

  /// Messages in chronological order. [before] paginates backwards in
  /// time — pass the oldest currently visible message's `createdAt`.
  Future<List<ChatMessage>> listMessages(
    String chatId, {
    int limit = 50,
    DateTime? before,
  });

  /// Send a text-only message. The caller's [as] role is stamped on the
  /// row so the trigger can tally the right unread counter.
  Future<ChatMessage> sendText({
    required String chatId,
    required String body,
    required ChatSenderRole as,
  });

  /// Send a message with an image attachment. [bytes] are uploaded to
  /// the `chat-attachments` storage bucket; the resulting public URL is
  /// stored on the message row. An optional [caption] is allowed.
  Future<ChatMessage> sendImage({
    required String chatId,
    required Uint8List bytes,
    required String mimeType,
    required ChatSenderRole as,
    String? caption,
  });

  /// Mark all unread messages from the *other* side as read and zero
  /// the caller's unread counter. Backed by the `mark_chat_read` RPC so
  /// the change is atomic.
  Future<void> markAsRead(String chatId);

  /// Live stream of *new* messages on the thread. Emits when another
  /// row lands in `chat_messages` for [chatId] via Woody Realtime.
  Stream<ChatMessage> messagesStream(String chatId);

  /// Fires when something about [orderId] changed (status moved, cancelled)
  /// and the linked chat's status banner may be stale. The thread cubit
  /// re-fetches the chat on each tick so the banner reflects the new status
  /// without a manual refresh. Driven by the `notification` realtime feed
  /// (the backend emits no dedicated order event yet).
  Stream<void> orderEventsStream(String orderId);

  /// Live stream of the current user's chats — emits the full list
  /// whenever any participating chat row changes (last_message_at,
  /// unread counts). Used by the list screen to badge in real time.
  /// [as] scopes the list to the active app surface, exactly like
  /// [listMyChats]; each re-fetch carries the same role.
  Stream<List<Chat>> myChatsStream({ChatSenderRole? as});

  /// Belt-and-suspenders refresh signal for the chat list. The realtime
  /// socket is the primary path, but a foreground FCM push for a new message
  /// can arrive when the socket is momentarily down (backgrounded, network
  /// blip). Calling this nudges [myChatsStream] to re-fetch so the list
  /// reorders + re-badges even on the degraded path. No-op when there are no
  /// active list subscribers.
  void nudgeFromPush();
}

/// In-memory fallback used by integration tests and the offline
/// developer build. Models exactly what the live implementation
/// does so blocs/UI work the same against either.
class MockChatRepository implements ChatRepository {
  MockChatRepository();

  final List<Chat> _chats = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final _newMessageCtrls = <String, StreamController<ChatMessage>>{};
  final _orderEventCtrls = <String, StreamController<void>>{};
  final _chatsListCtrl = StreamController<List<Chat>>.broadcast();

  @override
  Future<Chat> openChatForOrder({required String orderId}) async {
    final existing = _chats.where((c) => c.orderId == orderId).toList();
    if (existing.isNotEmpty) return existing.first;
    final chat = Chat(
      id: 'mock-${_chats.length + 1}',
      orderId: orderId,
      customerId: 'mock-customer',
      shopId: 'mock-shop',
      shopName: 'Mock Shop',
      customerName: 'Mock Customer',
      createdAt: DateTime.now(),
    );
    _chats.add(chat);
    _messages[chat.id] = [];
    _chatsListCtrl.add(List.unmodifiable(_chats));
    return chat;
  }

  @override
  Future<List<Chat>> listMyChats({ChatSenderRole? as}) async =>
      List.unmodifiable(_chats);

  @override
  Future<Chat> getChat(String chatId) async =>
      _chats.firstWhere((c) => c.id == chatId);

  @override
  Future<List<ChatMessage>> listMessages(
    String chatId, {
    int limit = 50,
    DateTime? before,
  }) async {
    final all = _messages[chatId] ?? const <ChatMessage>[];
    final filtered = before == null
        ? all
        : all.where((m) => m.createdAt.isBefore(before)).toList();
    return filtered.length > limit
        ? filtered.sublist(filtered.length - limit)
        : List.unmodifiable(filtered);
  }

  @override
  Future<ChatMessage> sendText({
    required String chatId,
    required String body,
    required ChatSenderRole as,
  }) async {
    final msg = ChatMessage(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'mock-user',
      senderRole: as,
      body: body,
      createdAt: DateTime.now(),
    );
    (_messages[chatId] ??= []).add(msg);
    _newMessageCtrls[chatId]?.add(msg);
    return msg;
  }

  @override
  Future<ChatMessage> sendImage({
    required String chatId,
    required Uint8List bytes,
    required String mimeType,
    required ChatSenderRole as,
    String? caption,
  }) async {
    final msg = ChatMessage(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'mock-user',
      senderRole: as,
      body: caption,
      attachmentUrl: 'https://example.com/mock-image.png',
      createdAt: DateTime.now(),
    );
    (_messages[chatId] ??= []).add(msg);
    _newMessageCtrls[chatId]?.add(msg);
    return msg;
  }

  @override
  Future<void> markAsRead(String chatId) async {}

  @override
  Stream<ChatMessage> messagesStream(String chatId) {
    final ctrl = _newMessageCtrls.putIfAbsent(
      chatId,
      () => StreamController<ChatMessage>.broadcast(),
    );
    return ctrl.stream;
  }

  @override
  Stream<void> orderEventsStream(String orderId) => _orderEventCtrls
      .putIfAbsent(orderId, () => StreamController<void>.broadcast())
      .stream;

  @override
  Stream<List<Chat>> myChatsStream({ChatSenderRole? as}) =>
      _chatsListCtrl.stream;

  @override
  void nudgeFromPush() => _chatsListCtrl.add(List.unmodifiable(_chats));
}

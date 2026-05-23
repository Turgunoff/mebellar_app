import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat.dart';
import '../models/chat_message.dart';

/// Repository abstraction so screens and blocs can be exercised against a
/// mock without depending on a live Supabase. Two-sided: the same calls
/// serve customer and seller surfaces; the active role is supplied where
/// the wire format actually needs it (e.g. `sender_role` on insert).
abstract class ChatRepository {
  /// Returns the existing chat for [orderId], or creates one when the
  /// caller is the order's customer and no chat exists yet. Sellers can
  /// only *fetch* — they never trigger lazy creation; if the customer
  /// hasn't opened a thread, there's nothing to fetch.
  Future<Chat> openChatForOrder({required String orderId});

  /// Chats visible to the current user (customer or seller), newest
  /// first by last_message_at then created_at.
  Future<List<Chat>> listMyChats();

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
  /// row lands in `chat_messages` for [chatId] via Supabase Realtime.
  Stream<ChatMessage> messagesStream(String chatId);

  /// Live stream of the current user's chats — emits the full list
  /// whenever any participating chat row changes (last_message_at,
  /// unread counts). Used by the list screen to badge in real time.
  Stream<List<Chat>> myChatsStream();
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  final SupabaseClient _supabase;

  // Embed the shop, customer profile, and order so the chat list +
  // thread can render names, avatars, and the status banner in one
  // round-trip. All are nullable — RLS may hide them for non-participants
  // and we degrade gracefully when a join misses.
  //
  // The `customer` join names the FK constraint explicitly because
  // `chats.customer_id` is FK'd to both `auth.users` and `profiles`
  // (the second was added so PostgREST can embed `profiles`). Naming
  // the constraint disambiguates which edge to traverse.
  static const _chatSelect =
      '*, shop:shops(id, name, logo_url), '
      'customer:profiles!chats_customer_id_profiles_fkey(id, full_name), '
      'order:orders!order_id(id, status, cancellation_reason)';

  String get _uid {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Chat actions require an authenticated user');
    }
    return id;
  }

  @override
  Future<Chat> openChatForOrder({required String orderId}) async {
    // Fast path: chat already exists. Single round-trip; PostgREST's
    // `maybeSingle` returns null cleanly when there's no row.
    final existing = await _supabase
        .from('chats')
        .select(_chatSelect)
        .eq('order_id', orderId)
        .maybeSingle();
    if (existing != null) return Chat.fromJson(existing);

    // Slow path: derive the shop from the order's items. We rely on
    // the project's one-shop-per-order convention — multi-shop orders
    // would split into multiple per-shop orders before reaching here,
    // and the UNIQUE(order_id) constraint would catch any drift.
    final shopRows = await _supabase
        .from('order_items')
        .select('products(shop_id)')
        .eq('order_id', orderId);
    final shopIds = <String>{};
    for (final row in (shopRows as List)) {
      final shopId =
          (row['products'] as Map<String, dynamic>?)?['shop_id'] as String?;
      if (shopId != null) shopIds.add(shopId);
    }
    if (shopIds.isEmpty) {
      throw StateError('Order $orderId has no shop — cannot open chat');
    }
    if (shopIds.length > 1) {
      // Defensive: if this fires in production we know the order flow
      // produced a multi-shop order somehow. We could pick the first or
      // throw — throwing is louder and easier to debug than a silently
      // routed message reaching only one of the sellers.
      throw StateError('Order $orderId spans multiple shops');
    }

    final inserted = await _supabase
        .from('chats')
        .insert({
          'order_id': orderId,
          'customer_id': _uid,
          'shop_id': shopIds.first,
        })
        .select(_chatSelect)
        .single();
    return Chat.fromJson(inserted);
  }

  @override
  Future<List<Chat>> listMyChats() async {
    // RLS filters server-side: the row is visible iff the caller is the
    // customer OR owns the shop. No explicit `or(...)` needed here.
    final rows = await _supabase
        .from('chats')
        .select(_chatSelect)
        .order('last_message_at', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(Chat.fromJson)
        .toList(growable: false);
  }

  @override
  Future<Chat> getChat(String chatId) async {
    final row = await _supabase
        .from('chats')
        .select(_chatSelect)
        .eq('id', chatId)
        .single();
    return Chat.fromJson(row);
  }

  @override
  Future<List<ChatMessage>> listMessages(
    String chatId, {
    int limit = 50,
    DateTime? before,
  }) async {
    var q = _supabase.from('chat_messages').select().eq('chat_id', chatId);
    if (before != null) {
      q = q.lt('created_at', before.toIso8601String());
    }
    final rows = await q.order('created_at', ascending: false).limit(limit);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        // Chronological (oldest first) so the UI can append-to-bottom.
        .toList()
        .reversed
        .toList(growable: false);
  }

  @override
  Future<ChatMessage> sendText({
    required String chatId,
    required String body,
    required ChatSenderRole as,
  }) async {
    final inserted = await _supabase
        .from('chat_messages')
        .insert({
          'chat_id': chatId,
          'sender_id': _uid,
          'sender_role': as.value,
          'body': body,
        })
        .select()
        .single();
    return ChatMessage.fromJson(inserted);
  }

  @override
  Future<ChatMessage> sendImage({
    required String chatId,
    required Uint8List bytes,
    required String mimeType,
    required ChatSenderRole as,
    String? caption,
  }) async {
    // Path convention `<chat_id>/<timestamp>-<rand>.<ext>` — the first
    // segment is read by the storage RLS policy to confirm the uploader
    // is a participant of that chat.
    final ext = _extensionFor(mimeType);
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}-${_uid.substring(0, 8)}.$ext';
    final path = '$chatId/$filename';

    await _supabase.storage.from('chat-attachments').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );
    final url = _supabase.storage.from('chat-attachments').getPublicUrl(path);

    final inserted = await _supabase
        .from('chat_messages')
        .insert({
          'chat_id': chatId,
          'sender_id': _uid,
          'sender_role': as.value,
          'attachment_url': url,
          if (caption != null && caption.trim().isNotEmpty) 'body': caption,
        })
        .select()
        .single();
    return ChatMessage.fromJson(inserted);
  }

  @override
  Future<void> markAsRead(String chatId) async {
    await _supabase.rpc('mark_chat_read', params: {'p_chat_id': chatId});
  }

  @override
  Stream<ChatMessage> messagesStream(String chatId) {
    // Realtime publication includes `chat_messages` so insert events
    // arrive within ~100ms over a stable connection.
    final controller = StreamController<ChatMessage>(sync: true);
    final channel = _supabase.channel('chat:$chatId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            try {
              controller.add(ChatMessage.fromJson(row));
            } catch (e) {
              controller.addError(e);
            }
          },
        )
        .subscribe();
    controller.onCancel = () async {
      await _supabase.removeChannel(channel);
    };
    return controller.stream;
  }

  @override
  Stream<List<Chat>> myChatsStream() {
    // Every change to the `chats` table re-emits the full list — the
    // server-side `chats_read` policy keeps it scoped to the caller, so
    // we get unread badges and last-message bumps without polling.
    final controller = StreamController<List<Chat>>();
    final channel = _supabase.channel('chats:list:$_uid');

    Future<void> refresh() async {
      try {
        controller.add(await listMyChats());
      } catch (e) {
        controller.addError(e);
      }
    }

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => refresh(),
        )
        .subscribe();

    // Prime the stream with the current snapshot.
    refresh();
    controller.onCancel = () async {
      await _supabase.removeChannel(channel);
    };
    return controller.stream;
  }

  static String _extensionFor(String mime) {
    return switch (mime) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'bin',
    };
  }
}

/// In-memory fallback used by integration tests and the no-Supabase
/// developer build. Models exactly what the Supabase implementation
/// does so blocs/UI work the same against either.
class MockChatRepository implements ChatRepository {
  MockChatRepository();

  final List<Chat> _chats = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final _newMessageCtrls = <String, StreamController<ChatMessage>>{};
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
  Future<List<Chat>> listMyChats() async => List.unmodifiable(_chats);

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
  Stream<List<Chat>> myChatsStream() => _chatsListCtrl.stream;
}

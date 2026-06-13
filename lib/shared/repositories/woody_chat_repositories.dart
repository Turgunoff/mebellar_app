import 'dart:async';
import 'dart:typed_data';

import '../../core/network/woody_api_client.dart';
import '../../core/realtime/woody_realtime_service.dart';
import '../models/app_notification.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../models/order_status.dart';
import 'chat_repository.dart';
import 'notifications_repository.dart';

/// REST-backed chat repository. Calls `/chats/*` endpoints on api.woody.uz.
///
/// Image attachments arrive in Phase 7 once the R2 presigned-PUT flow lands
/// — for now `sendImage` throws so the UI can fall back to a "feature
/// unavailable" message rather than silently failing.
///
/// Realtime: the backend publishes a `chat_message` frame to the *recipient*
/// over the Woody WebSocket the instant a message is inserted, carrying the
/// full row. [messagesStream] lifts that frame into a [ChatMessage] for the
/// open thread; [myChatsStream] re-fetches the list on each frame so unread
/// badges + ordering + last-message previews update live. When no realtime
/// service is wired (tests / no-backend builds) the streams degrade to a
/// single on-demand snapshot, exactly as before.
class WoodyChatRepository implements ChatRepository {
  WoodyChatRepository({
    required WoodyApiClient api,
    WoodyRealtimeService? realtime,
  }) : _api = api,
       _realtime = realtime;

  final WoodyApiClient _api;

  /// Live event source. Null in builds/tests without a configured backend.
  final WoodyRealtimeService? _realtime;

  /// Ticks whenever the signed-in user's chat list may have changed: a
  /// realtime `chat_message` frame, or an FCM foreground push that beat the
  /// socket ([nudgeFromPush]). Broadcast so every open list screen shares one
  /// upstream WS subscription.
  final _listDirty = StreamController<void>.broadcast();

  /// One shared subscription bridging the WS `chat_message` feed onto
  /// [_listDirty]; opened lazily the first time a list stream is requested.
  StreamSubscription<RealtimeEvent>? _wsListSub;

  @override
  Future<Chat> openChatForOrder({required String orderId}) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/chats',
      body: {'order_id': orderId},
    );
    return _rowToChat(body);
  }

  @override
  Future<List<Chat>> listMyChats() async {
    final rows = await _api.get<List<dynamic>>('/chats');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_rowToChat)
        .toList(growable: false);
  }

  @override
  Future<Chat> getChat(String chatId) async {
    // No dedicated single-chat endpoint; fall back to listing and finding it.
    final list = await listMyChats();
    return list.firstWhere(
      (c) => c.id == chatId,
      orElse: () => throw StateError('Chat $chatId not found'),
    );
  }

  @override
  Future<List<ChatMessage>> listMessages(
    String chatId, {
    int limit = 50,
    DateTime? before,
  }) async {
    final rows = await _api.get<List<dynamic>>(
      '/chats/$chatId/messages',
      query: {'limit': limit},
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_rowToMessage)
        .toList(growable: false);
  }

  @override
  Future<ChatMessage> sendText({
    required String chatId,
    required String body,
    required ChatSenderRole as,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/chats/$chatId/messages',
      body: {'body': body},
    );
    return _rowToMessage(response);
  }

  @override
  Future<ChatMessage> sendImage({
    required String chatId,
    required Uint8List bytes,
    required String mimeType,
    required ChatSenderRole as,
    String? caption,
  }) {
    // Storage uploads land in Phase 7. Surface a clear failure instead of
    // silently swallowing the image.
    throw UnimplementedError(
      'Image attachments arrive with the R2 storage migration (Phase 7).',
    );
  }

  @override
  Future<void> markAsRead(String chatId) async {
    await _api.post<dynamic>('/chats/$chatId/read');
  }

  @override
  Stream<ChatMessage> messagesStream(String chatId) {
    final realtime = _realtime;
    // No socket (tests / no-backend build) → empty stream; the thread still
    // shows its initial page, it just won't live-append.
    if (realtime == null) return const Stream.empty();
    // The backend publishes `chat_message` to the recipient only, with the
    // full row. Filter to this thread and lift it into a ChatMessage — the
    // thread cubit dedupes against its own optimistic insert by id.
    return realtime
        .eventsOfType('chat_message')
        .where((e) => e.data['chat_id'] == chatId)
        .map((e) => _messageFromEvent(e.data))
        .where((m) => m != null)
        .cast<ChatMessage>();
  }

  @override
  Stream<List<Chat>> myChatsStream() {
    late final StreamController<List<Chat>> out;
    StreamSubscription<void>? dirtySub;

    Future<void> pull({required bool initial}) async {
      try {
        if (!out.isClosed) out.add(await listMyChats());
      } catch (e, st) {
        // Surface a genuine first-load failure to the cubit; on a later
        // realtime re-fetch keep the last good list instead of tearing the
        // screen down over a transient blip.
        if (initial && !out.isClosed) out.addError(e, st);
      }
    }

    out = StreamController<List<Chat>>(
      // Subscribe to the dirty signal BEFORE the first fetch so a frame that
      // lands mid-fetch (broadcast streams don't buffer) still triggers a
      // follow-up pull.
      onListen: () {
        _wireListRefresh();
        dirtySub = _listDirty.stream.listen((_) => pull(initial: false));
        pull(initial: true);
      },
      onCancel: () async {
        await dirtySub?.cancel();
        dirtySub = null;
      },
    );
    return out.stream;
  }

  @override
  void nudgeFromPush() {
    if (!_listDirty.isClosed) _listDirty.add(null);
  }

  /// Opens the single WS→list bridge on first use. Idempotent.
  void _wireListRefresh() {
    final realtime = _realtime;
    if (realtime == null || _wsListSub != null) return;
    _wsListSub = realtime.eventsOfType('chat_message').listen((_) {
      if (!_listDirty.isClosed) _listDirty.add(null);
    });
  }

  ChatMessage? _messageFromEvent(Map<String, dynamic> data) {
    try {
      return _rowToMessage(data);
    } catch (_) {
      // A forward-compat field shift must not crash the live thread; the
      // message still lands on the next reload.
      return null;
    }
  }

  /// Tears down the realtime bridge. The repo is app-lifetime in production,
  /// so this is mainly for tests and a clean DI-scope dispose if ever wired.
  Future<void> dispose() async {
    await _wsListSub?.cancel();
    _wsListSub = null;
    await _listDirty.close();
  }

  Chat _rowToChat(Map<String, dynamic> row) {
    return Chat(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      customerId: row['customer_id'] as String,
      shopId: row['shop_id'] as String,
      customerName: row['customer_name'] as String?,
      shopName: row['shop_name'] as String?,
      shopLogoUrl: row['shop_logo_url'] as String?,
      lastMessageAt: row['last_message_at'] is String
          ? DateTime.parse(row['last_message_at'] as String)
          : null,
      lastMessagePreview: row['last_message_preview'] as String?,
      customerUnreadCount: (row['customer_unread_count'] as num?)?.toInt() ?? 0,
      sellerUnreadCount: (row['seller_unread_count'] as num?)?.toInt() ?? 0,
      orderStatus: row['order_status'] is String
          ? OrderStatus.fromCode(row['order_status'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  ChatMessage _rowToMessage(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as String,
      chatId: row['chat_id'] as String,
      senderId: row['sender_id'] as String,
      senderRole: row['sender_role'] == 'seller'
          ? ChatSenderRole.seller
          : ChatSenderRole.customer,
      body: row['body'] as String?,
      attachmentUrl: row['attachment_url'] as String?,
      readAt: row['read_at'] is String
          ? DateTime.parse(row['read_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

/// REST-backed notifications inbox. Implements only the read paths the
/// existing UI needs; the simulator hook is a no-op since real pushes hit
/// the device through FCM and Phase 6 streams them in via WebSocket.
class WoodyNotificationsRepository implements NotificationsRepository {
  WoodyNotificationsRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;
  List<AppNotification> _current = const [];
  final _controller = StreamController<List<AppNotification>>.broadcast();
  final _unreadController = StreamController<int>.broadcast();

  @override
  Stream<List<AppNotification>> watch() => _controller.stream;

  @override
  List<AppNotification> get current => List.unmodifiable(_current);

  @override
  Future<List<AppNotification>> list() async {
    final body = await _api.get<Map<String, dynamic>>('/notifications');
    final rows = body['rows'] as List<dynamic>? ?? const [];
    _current = rows
        .whereType<Map<String, dynamic>>()
        .map(_rowToNotification)
        .toList(growable: false);
    _controller.add(_current);
    _unreadController.add(_unreadFromCurrent());
    return _current;
  }

  @override
  int unreadCount({String? mode}) => _unreadFromCurrent();

  @override
  Stream<int> watchUnread({String? mode}) => _unreadController.stream;

  @override
  Future<void> markRead(String id) async {
    await _api.patch<dynamic>('/notifications/$id/read');
    _current = _current
        .map((n) => n.id == id ? n.copyWith(read: true) : n)
        .toList(growable: false);
    _controller.add(_current);
    _unreadController.add(_unreadFromCurrent());
  }

  @override
  Future<void> markAllRead({String? mode}) async {
    await _api.post<dynamic>('/notifications/read-all');
    _current = _current
        .map((n) => n.copyWith(read: true))
        .toList(growable: false);
    _controller.add(_current);
    _unreadController.add(0);
  }

  @override
  Future<void> clear() async {
    // Backend has no "delete all" endpoint yet — clear locally so the UI
    // empties out, and the next refresh resyncs from the server.
    _current = const [];
    _controller.add(_current);
    _unreadController.add(0);
  }

  @override
  Future<AppNotification> simulateIncoming(AppNotification notification) async {
    // Real pushes hit the device through FCM + Phase 6 WebSocket — the
    // simulator path is a local-only injection used by the debug screen.
    _current = [notification, ..._current];
    _controller.add(_current);
    _unreadController.add(_unreadFromCurrent());
    return notification;
  }

  int _unreadFromCurrent() => _current.where((n) => !n.read).length;

  AppNotification _rowToNotification(Map<String, dynamic> row) {
    final data = row['data'];
    final route = data is Map && data['route'] is String
        ? data['route'] as String
        : '/';
    return AppNotification(
      id: row['id'] as String,
      kind: NotificationKind.fromCode(row['type'] as String?),
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      route: route,
      read: row['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

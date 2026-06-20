import 'dart:async';
import 'dart:typed_data';

import '../../../../core/network/woody_api_client.dart';
import '../../../../core/realtime/woody_realtime_service.dart';
import '../../../../core/storage/r2_upload_client.dart';
import '../models/support_message.dart';
import 'support_chat_repository.dart';

/// REST-backed customer support chat. Talks to the `/support/*` endpoints on
/// api.woody.uz (single thread per signed-in user — the backend auto-creates
/// and resolves the thread, so the client never supplies a chat id).
///
/// Attachments use the dedicated support upload flow (NOT `/storage/upload-url`):
///   1. `POST /support/upload {content_type, ext}` -> `{upload_url, file_url}`
///   2. PUT the raw bytes to `upload_url` with `Content-Type: <content_type>`
///      (no auth header)
///   3. `POST /support/message {message_type, file_url}`
///
/// Realtime: the backend publishes a `support_message` frame (admin replies
/// only) and a `support_read` frame (admin read the user's messages) over the
/// Woody WebSocket. Both are filtered to this thread by chat id. When no
/// realtime service is wired (tests / no-backend builds) the streams degrade
/// to empty, exactly like the chat repo.
class WoodySupportChatRepository implements SupportChatRepository {
  WoodySupportChatRepository({
    required WoodyApiClient api,
    WoodyRealtimeService? realtime,
    R2UploadClient? uploads,
  }) : _api = api,
       _realtime = realtime,
       _uploads = uploads;

  final WoodyApiClient _api;

  /// Live event source. Null in builds/tests without a configured backend.
  final WoodyRealtimeService? _realtime;

  /// Raw-PUT uploader for attachments. Null in tests / no-backend builds, where
  /// sendImage/sendAudio report the feature unavailable.
  final R2UploadClient? _uploads;

  /// The resolved chat id, captured on the first [fetchChat]. Used to filter
  /// realtime frames to this user's thread.
  String? _chatId;

  /// Local "I just read the thread" signal so the global unread badge can reset
  /// without the thread screen touching the badge cubit. Broadcast + never
  /// closed — this repo is an app-lifetime singleton.
  final _localReadCtrl = StreamController<void>.broadcast();

  @override
  Future<SupportChatSnapshot> fetchChat() async {
    final body = await _api.get<Map<String, dynamic>>('/support/chat');
    final chat = body['chat'] as Map<String, dynamic>?;
    final chatId = (chat?['id'] as String?) ?? '';
    _chatId = chatId;
    final rows = (body['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SupportMessage.fromJson)
        .toList(growable: false);
    return (chatId: chatId, messages: rows);
  }

  @override
  Future<SupportMessage> sendText(String text) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/support/message',
      body: {'message_type': 'text', 'text_content': text},
    );
    return SupportMessage.fromJson(response);
  }

  @override
  Future<SupportMessage> sendImage({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final fileUrl = await _upload(
      bytes: bytes,
      contentType: mimeType,
      ext: _imageExtFor(mimeType),
    );
    final response = await _api.post<Map<String, dynamic>>(
      '/support/message',
      body: {'message_type': 'image', 'file_url': fileUrl},
    );
    return SupportMessage.fromJson(response);
  }

  @override
  Future<SupportMessage> sendAudio({
    required Uint8List bytes,
    required String contentType,
    int? durationMs,
  }) async {
    final fileUrl = await _upload(
      bytes: bytes,
      contentType: contentType,
      ext: _audioExtFor(contentType),
    );
    final response = await _api.post<Map<String, dynamic>>(
      '/support/message',
      body: {'message_type': 'audio', 'file_url': fileUrl},
    );
    return SupportMessage.fromJson(response);
  }

  /// Three-step upload: ask the backend for a presigned PUT + the canonical
  /// file_url, PUT the bytes straight to R2 (no auth header — the URL signs
  /// the request), then return the file_url for the message POST.
  Future<String> _upload({
    required Uint8List bytes,
    required String contentType,
    required String ext,
  }) async {
    final uploads = _uploads;
    if (uploads == null) {
      throw StateError('support_attachment_unavailable');
    }
    final presigned = await _api.post<Map<String, dynamic>>(
      '/support/upload',
      body: {'content_type': contentType, 'ext': ext},
    );
    final uploadUrl = presigned['upload_url'];
    final fileUrl = presigned['file_url'];
    if (uploadUrl is! String ||
        uploadUrl.isEmpty ||
        fileUrl is! String ||
        fileUrl.isEmpty) {
      throw StateError('support_attachment_unavailable');
    }
    await uploads.putToPresignedUrl(
      url: uploadUrl,
      bytes: bytes,
      contentType: contentType,
    );
    return fileUrl;
  }

  @override
  Future<void> markRead() async {
    await _api.post<dynamic>('/support/read');
    // Nudge the badge to zero once the server has cleared the unread counter.
    _localReadCtrl.add(null);
  }

  @override
  Future<int> fetchUnreadCount() async {
    final body = await _api.get<Map<String, dynamic>>('/support/unread');
    final raw = body['unread'];
    return raw is int ? raw : (raw is num ? raw.toInt() : 0);
  }

  @override
  Stream<void> localReadStream() => _localReadCtrl.stream;

  @override
  Stream<SupportMessage> messagesStream() {
    final realtime = _realtime;
    if (realtime == null) return const Stream.empty();
    return realtime
        .eventsOfType('support_message')
        .where((e) => _chatId == null || e.data['chat_id'] == _chatId)
        .map((e) => _messageFromEvent(e.data))
        .where((m) => m != null)
        .cast<SupportMessage>();
  }

  @override
  Stream<void> readStream() {
    final realtime = _realtime;
    if (realtime == null) return const Stream.empty();
    return realtime
        .eventsOfType('support_read')
        .where((e) => _chatId == null || e.data['chat_id'] == _chatId)
        .map((_) {});
  }

  SupportMessage? _messageFromEvent(Map<String, dynamic> data) {
    try {
      return SupportMessage.fromJson(data);
    } catch (_) {
      // A forward-compat field shift must not crash the live thread; the
      // message still lands on the next reload.
      return null;
    }
  }

  // Allowlist mirrors the backend contract.
  static String _imageExtFor(String mimeType) => switch (mimeType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };

  static String _audioExtFor(String contentType) => switch (contentType) {
    'audio/aac' => 'aac',
    'audio/mpeg' => 'mp3',
    'audio/ogg' => 'ogg',
    'audio/wav' => 'wav',
    // audio/mp4 + audio/x-m4a both map to the m4a container we record.
    _ => 'm4a',
  };
}

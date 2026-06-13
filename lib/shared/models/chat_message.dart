import 'package:equatable/equatable.dart';

import 'chat.dart';

/// Delivery lifecycle of an outgoing message. Server-loaded / inbound
/// messages are always [sent]; an optimistic local insert starts as
/// [sending] and reconciles to [sent] (server ack) or [failed] (the send
/// threw). Drives the status glyph on the bubble — clock → tick → retry.
enum ChatMessageStatus { sending, sent, failed }

/// A single message inside a chat thread. Either [body] or [attachmentUrl]
/// is non-null (the DB CHECK guarantees this); both can be present when
/// a user sends an image with a caption.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderRole,
    this.body,
    this.attachmentUrl,
    this.readAt,
    required this.createdAt,
    this.status = ChatMessageStatus.sent,
    this.localId,
  });

  final String id;
  final String chatId;
  final String senderId;
  final ChatSenderRole senderRole;
  final String? body;
  final String? attachmentUrl;
  final DateTime? readAt;
  final DateTime createdAt;

  /// Send lifecycle — [ChatMessageStatus.sent] for anything from the server.
  final ChatMessageStatus status;

  /// Client-generated correlation id for an optimistic insert, used to swap
  /// the placeholder for the server row when the POST returns. Null on
  /// server-sourced messages.
  final String? localId;

  bool get hasText => body != null && body!.trim().isNotEmpty;
  bool get hasImage => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isRead => readAt != null;
  bool get isSending => status == ChatMessageStatus.sending;
  bool get isFailed => status == ChatMessageStatus.failed;

  /// True when the *viewer* is the sender — drives bubble alignment
  /// (right vs left) and tick-mark visibility (read receipts only show
  /// on outgoing messages).
  bool isMine(ChatSenderRole viewer) => senderRole == viewer;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: ChatSenderRole.fromValue(json['sender_role'] as String),
      body: json['body'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      readAt: _parseDate(json['read_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ChatMessage copyWith({
    String? id,
    DateTime? readAt,
    ChatMessageStatus? status,
    String? attachmentUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId,
      senderId: senderId,
      senderRole: senderRole,
      body: body,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      status: status ?? this.status,
      localId: localId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    chatId,
    senderId,
    senderRole,
    body,
    attachmentUrl,
    readAt,
    createdAt,
    status,
    localId,
  ];
}

DateTime? _parseDate(Object? raw) {
  if (raw is String) return DateTime.parse(raw);
  return null;
}

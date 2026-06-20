import 'package:equatable/equatable.dart';

/// Delivery lifecycle of an outgoing support message. Server-loaded /
/// inbound messages are always [sent]; an optimistic local insert starts as
/// [sending] and reconciles to [sent] (server ack) or [failed] (the send
/// threw). Drives the status glyph on the bubble — clock → tick → retry.
enum SupportMessageStatus { sending, sent, failed }

/// Who authored a support message. The customer viewer is always the `user`
/// side; `admin` is the support agent on the other end.
enum SupportSenderType {
  user('user'),
  admin('admin');

  const SupportSenderType(this.value);
  final String value;

  static SupportSenderType fromValue(String? v) =>
      v == 'admin' ? SupportSenderType.admin : SupportSenderType.user;
}

/// What a support message carries.
enum SupportMessageType {
  text('text'),
  image('image'),
  audio('audio');

  const SupportMessageType(this.value);
  final String value;

  static SupportMessageType fromValue(String? v) => switch (v) {
    'image' => SupportMessageType.image,
    'audio' => SupportMessageType.audio,
    _ => SupportMessageType.text,
  };
}

/// A single message in the customer's single support thread. The backend
/// shape is `SupportMessageRow` (see the locked contract):
/// `{ id, chat_id, sender_id, sender_type, message_type, text_content,
///    file_url, read_at, created_at }`.
class SupportMessage extends Equatable {
  const SupportMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderType,
    required this.messageType,
    this.textContent,
    this.fileUrl,
    this.readAt,
    required this.createdAt,
    this.status = SupportMessageStatus.sent,
    this.localId,
  });

  final String id;
  final String chatId;
  final String senderId;
  final SupportSenderType senderType;
  final SupportMessageType messageType;
  final String? textContent;
  final String? fileUrl;
  final DateTime? readAt;
  final DateTime createdAt;

  /// Send lifecycle — [SupportMessageStatus.sent] for anything from the server.
  final SupportMessageStatus status;

  /// Client-generated correlation id for an optimistic insert, used to swap
  /// the placeholder for the server row when the POST returns. Null on
  /// server-sourced messages.
  final String? localId;

  bool get hasText =>
      textContent != null && textContent!.trim().isNotEmpty;
  bool get hasImage =>
      messageType == SupportMessageType.image &&
      fileUrl != null &&
      fileUrl!.isNotEmpty;
  bool get hasAudio =>
      messageType == SupportMessageType.audio &&
      fileUrl != null &&
      fileUrl!.isNotEmpty;
  bool get isRead => readAt != null;
  bool get isSending => status == SupportMessageStatus.sending;
  bool get isFailed => status == SupportMessageStatus.failed;

  /// True when the *customer viewer* sent it — drives bubble alignment
  /// (right vs left) and tick-mark visibility (read receipts only show
  /// on outgoing messages).
  bool get isMine => senderType == SupportSenderType.user;

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: (json['sender_id'] as String?) ?? '',
      senderType: SupportSenderType.fromValue(json['sender_type'] as String?),
      messageType: SupportMessageType.fromValue(
        json['message_type'] as String?,
      ),
      textContent: json['text_content'] as String?,
      fileUrl: json['file_url'] as String?,
      readAt: _parseDate(json['read_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  SupportMessage copyWith({
    String? id,
    DateTime? readAt,
    SupportMessageStatus? status,
    String? fileUrl,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      chatId: chatId,
      senderId: senderId,
      senderType: senderType,
      messageType: messageType,
      textContent: textContent,
      fileUrl: fileUrl ?? this.fileUrl,
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
    senderType,
    messageType,
    textContent,
    fileUrl,
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

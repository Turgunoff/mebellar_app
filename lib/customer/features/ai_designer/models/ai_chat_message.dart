import 'package:hive/hive.dart';

/// One turn in the AI interior-designer conversation. Persisted to Hive so the
/// thread reopens instantly on the next launch (zero-loading UX).
///
/// Recommended products are intentionally NOT part of the Hive record — they
/// are kept only in memory (keyed by message id in the cubit). A stored
/// product reference would go stale (price / stock / availability), and the
/// AI re-recommends on each new exchange anyway, so persisting just the
/// text/isUser/imageUrl/timestamp keeps the cache honest.
class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
    this.logId,
    this.userRating,
  });

  final String id;
  final String text;
  final bool isUser;
  final String? imageUrl;
  final DateTime timestamp;

  /// The persisted backend chat-log row id for an AI reply (null for user
  /// turns, or when the backend's log write failed). Drives the 👍/👎 rating
  /// row — no log id, no rating affordance.
  final String? logId;

  /// The user's verdict on this AI reply: "liked" / "disliked" / null. Set
  /// optimistically on tap and PATCHed to the backend; persisted so the choice
  /// survives a relaunch.
  final String? userRating;

  AiChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    String? imageUrl,
    DateTime? timestamp,
    String? logId,
    String? userRating,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      logId: logId ?? this.logId,
      userRating: userRating ?? this.userRating,
    );
  }
}

/// Hand-written adapter — the repo runs no codegen (no hive_generator /
/// build_runner). typeId 1 is the first id used in the app; keep it stable.
class AiChatMessageAdapter extends TypeAdapter<AiChatMessage> {
  @override
  final int typeId = 1;

  @override
  AiChatMessage read(BinaryReader reader) {
    final id = reader.readString();
    final text = reader.readString();
    final isUser = reader.readBool();
    // imageUrl is nullable: a leading bool flag tells us whether a string
    // follows, so we never read a phantom field for a text-only message.
    final hasImage = reader.readBool();
    final imageUrl = hasImage ? reader.readString() : null;
    final millis = reader.readInt();
    // BACKWARD COMPATIBILITY: records written before logId/userRating existed
    // have no bytes past the timestamp. A reader on an old record sees zero
    // remaining bytes, so guard the new fields — reading them would otherwise
    // throw a RangeError and lose the whole conversation. New records carry
    // both as the usual leading-bool + optional-string nullable protocol.
    String? logId;
    String? userRating;
    if (reader.availableBytes > 0) {
      final hasLogId = reader.readBool();
      logId = hasLogId ? reader.readString() : null;
      final hasRating = reader.readBool();
      userRating = hasRating ? reader.readString() : null;
    }
    return AiChatMessage(
      id: id,
      text: text,
      isUser: isUser,
      imageUrl: imageUrl,
      timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
      logId: logId,
      userRating: userRating,
    );
  }

  @override
  void write(BinaryWriter writer, AiChatMessage obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.text);
    writer.writeBool(obj.isUser);
    final imageUrl = obj.imageUrl;
    writer.writeBool(imageUrl != null);
    if (imageUrl != null) writer.writeString(imageUrl);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
    final logId = obj.logId;
    writer.writeBool(logId != null);
    if (logId != null) writer.writeString(logId);
    final userRating = obj.userRating;
    writer.writeBool(userRating != null);
    if (userRating != null) writer.writeString(userRating);
  }
}

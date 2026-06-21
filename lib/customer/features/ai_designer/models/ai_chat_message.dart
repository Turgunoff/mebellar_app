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
  });

  final String id;
  final String text;
  final bool isUser;
  final String? imageUrl;
  final DateTime timestamp;

  AiChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    String? imageUrl,
    DateTime? timestamp,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
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
    return AiChatMessage(
      id: id,
      text: text,
      isUser: isUser,
      imageUrl: imageUrl,
      timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
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
  }
}

import 'dart:typed_data';

// ignore: implementation_imports — the Impl classes are the only way to drive
// a BinaryWriter/BinaryReader by hand in a unit test, which is exactly what the
// backward-compatibility check needs (an old-format record has fewer bytes than
// the current adapter writes).
import 'package:hive/src/binary/binary_reader_impl.dart';
// ignore: implementation_imports
import 'package:hive/src/binary/binary_writer_impl.dart';
// ignore: implementation_imports
import 'package:hive/src/registry/type_registry_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/ai_designer/models/ai_chat_message.dart';

/// Writes the PRE-CHANGE record layout: id, text, isUser, the imageUrl
/// nullable pair, then the timestamp millis — and STOPS there, exactly as the
/// adapter did before logId/userRating were added. The reader must treat the
/// missing trailing fields as null instead of throwing a RangeError.
Uint8List _writeOldFormat(AiChatMessage obj) {
  final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl);
  writer.writeString(obj.id);
  writer.writeString(obj.text);
  writer.writeBool(obj.isUser);
  final imageUrl = obj.imageUrl;
  writer.writeBool(imageUrl != null);
  if (imageUrl != null) writer.writeString(imageUrl);
  writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
  return writer.toBytes();
}

void main() {
  final adapter = AiChatMessageAdapter();

  test('reads an OLD-format record (no logId/userRating bytes) as nulls', () {
    final old = AiChatMessage(
      id: 'm1',
      text: 'salom',
      isUser: false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    final bytes = _writeOldFormat(old);

    final reader = BinaryReaderImpl(bytes, TypeRegistryImpl.nullImpl);
    final decoded = adapter.read(reader);

    expect(decoded.id, 'm1');
    expect(decoded.text, 'salom');
    expect(decoded.isUser, isFalse);
    expect(decoded.imageUrl, isNull);
    expect(
      decoded.logId,
      isNull,
      reason: 'an old record carries no logId bytes',
    );
    expect(
      decoded.userRating,
      isNull,
      reason: 'an old record carries no userRating bytes',
    );
  });

  test('round-trips the new logId + userRating fields', () {
    final original = AiChatMessage(
      id: 'm2',
      text: 'javob',
      isUser: false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000001234),
      logId: 'log-7',
      userRating: 'liked',
    );

    final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl);
    adapter.write(writer, original);
    final reader = BinaryReaderImpl(writer.toBytes(), TypeRegistryImpl.nullImpl);
    final decoded = adapter.read(reader);

    expect(decoded.id, 'm2');
    expect(decoded.text, 'javob');
    expect(decoded.logId, 'log-7');
    expect(decoded.userRating, 'liked');
  });

  test('round-trips a new record whose logId/userRating are null', () {
    final original = AiChatMessage(
      id: 'm3',
      text: 'savol',
      isUser: true,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000002000),
    );

    final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl);
    adapter.write(writer, original);
    final reader = BinaryReaderImpl(writer.toBytes(), TypeRegistryImpl.nullImpl);
    final decoded = adapter.read(reader);

    expect(decoded.logId, isNull);
    expect(decoded.userRating, isNull);
  });
}

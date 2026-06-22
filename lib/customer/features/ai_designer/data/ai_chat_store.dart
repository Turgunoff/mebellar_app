import 'package:hive/hive.dart';

import '../../../../core/storage/hive_boxes.dart';
import '../models/ai_chat_message.dart';

/// Thin Hive-backed local store for the AI designer conversation. The box is
/// opened (and its adapter registered) at bootstrap in `hive_boxes.dart`, so
/// every call here just reaches the already-open typed box synchronously.
class AiChatStore {
  Box<AiChatMessage> get _box =>
      Hive.box<AiChatMessage>(HiveBoxes.aiChatHistory);

  /// Persisted messages, oldest first.
  List<AiChatMessage> load() {
    final items = _box.values.toList(growable: false);
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return items;
  }

  Future<void> append(AiChatMessage message) => _box.put(message.id, message);

  /// Replaces the whole cached thread with [messages] (server-authoritative
  /// restore after login): clears the box, then writes the fresh set keyed by
  /// id. The box only ever holds the current user's data because [clear] runs
  /// on logout, so this never mixes two users' conversations.
  Future<void> replaceAll(List<AiChatMessage> messages) async {
    await _box.clear();
    await _box.putAll({for (final m in messages) m.id: m});
  }

  Future<void> clear() => _box.clear();
}

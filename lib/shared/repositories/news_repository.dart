import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';

/// Source for the public broadcast feed. Reads from `public.news` (anyone
/// can SELECT) and tracks per-device read-state in a Hive set so the inbox
/// badge works for anonymous users too.
abstract class NewsDataSource {
  /// Fetches active news, newest first, mapped into the unified
  /// [NotificationModel] shape so the inbox cubit can merge them with
  /// personal notifications without branching the UI.
  Future<List<NotificationModel>> list();

  /// Records that the user has seen [newsId]. Idempotent — a second mark
  /// for the same id is a no-op.
  Future<void> markRead(String newsId);

  /// Marks every currently visible news id as read. Called by "mark all
  /// read" in the inbox header.
  Future<void> markAllRead(Iterable<String> visibleIds);
}

class SupabaseNewsRepository implements NewsDataSource {
  SupabaseNewsRepository({
    required SupabaseClient supabase,
    required Box readsBox,
  })  : _supabase = supabase,
        _readsBox = readsBox;

  final SupabaseClient _supabase;
  final Box _readsBox;

  static const _readIdsKey = 'read_ids';

  Set<String> _readIds() {
    final raw = _readsBox.get(_readIdsKey);
    if (raw is List) return raw.cast<String>().toSet();
    return <String>{};
  }

  Future<void> _saveReadIds(Set<String> ids) async {
    await _readsBox.put(_readIdsKey, ids.toList(growable: false));
  }

  @override
  Future<List<NotificationModel>> list() async {
    final data = await _supabase
        .from('news')
        .select('id, title, body, data, published_at')
        .eq('is_active', true)
        .order('published_at', ascending: false);
    final readIds = _readIds();
    return (data as List).whereType<Map<String, dynamic>>().map((row) {
      final id = row['id'] as String;
      return NotificationModel(
        id: id,
        // Synthetic user id distinguishes broadcast rows from personal ones
        // in any consumer that inspects the field. The cubit doesn't care.
        userId: 'broadcast',
        title: (row['title'] as String?) ?? '',
        body: (row['body'] as String?) ?? '',
        kind: NotificationKind.news,
        referenceId: null,
        isRead: readIds.contains(id),
        createdAt: DateTime.parse(row['published_at'] as String),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> markRead(String newsId) async {
    final ids = _readIds();
    if (ids.add(newsId)) await _saveReadIds(ids);
  }

  @override
  Future<void> markAllRead(Iterable<String> visibleIds) async {
    final ids = _readIds();
    final before = ids.length;
    ids.addAll(visibleIds);
    if (ids.length != before) await _saveReadIds(ids);
  }
}

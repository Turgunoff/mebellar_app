import 'package:hive/hive.dart';

import '../../../../core/storage/hive_boxes.dart';

/// Client-side daily cap on AI-designer room-photo uploads.
///
/// This is the instant-feedback half of the rate limit — it blocks the upload
/// before any bytes leave the device so a user who hit the cap gets told
/// immediately instead of after a wasted upload. The backend enforces the same
/// cap server-side (the authoritative guard against a tampered client); see
/// `AI_DESIGNER_DAILY_IMAGE_LIMIT` in woody_backend.
///
/// State is two keys in the shared `settings` Hive box: the day stamp and that
/// day's count. A new day (stamp mismatch) reads as zero, so no cleanup is
/// needed — the next increment overwrites the stale day.
class AiImageQuota {
  AiImageQuota({Box? box, this.dailyLimit = 10})
    : _box = box ?? Hive.box(HiveBoxes.settings);

  final Box _box;
  final int dailyLimit;

  static const _dateKey = 'ai_img_quota_date';
  static const _countKey = 'ai_img_quota_count';

  static String _today() {
    final n = DateTime.now();
    // Local-day granularity is fine for a soft UX cap; the server window is the
    // hard limit.
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Photos already uploaded today (0 once the day rolls over).
  int get usedToday =>
      _box.get(_dateKey) == _today() ? (_box.get(_countKey) as int? ?? 0) : 0;

  /// False once today's count reached [dailyLimit].
  bool get canUpload => usedToday < dailyLimit;

  /// Record one successful upload against today's quota.
  Future<void> increment() async {
    final today = _today();
    final next = (_box.get(_dateKey) == today ? usedToday : 0) + 1;
    await _box.put(_dateKey, today);
    await _box.put(_countKey, next);
  }
}

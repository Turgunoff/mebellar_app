import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key holding the last launcher-badge count. Shared by the
/// live app ([AppBadgeService]) and the FCM background isolate
/// ([incrementAppBadgeFromBackground]): a push that lands while the process is
/// dead carries the count forward from where the live app left it. Backed by
/// SharedPreferences (not Hive) so the lightweight background isolate can read
/// it without opening Hive, mirroring the `pending_payment` marker.
const String _kBadgeCountKey = 'app_badge_count';

/// Probe result cache for [AppBadgePlus.isSupported]. Launcher support is a
/// device-constant, so probe once per isolate instead of round-tripping the
/// platform channel on every unread change. Null until first resolved; stays
/// null if the probe ever throws so a later write can retry it.
bool? _badgeSupported;

/// Writes [count] to the launcher icon and persists it. Fully guarded — returns
/// silently on any platform error or unsupported launcher. The single place
/// that talks to `app_badge_plus`, shared by [AppBadgeService] and the
/// background-isolate helper so the crash-proofing lives in exactly one spot.
Future<void> _writeBadge(int count) async {
  final value = count < 0 ? 0 : count;

  // Persist first: even if the OS call below throws on this launcher, the
  // stored tally must stay the source of truth the background isolate reads.
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBadgeCountKey, value);
  } catch (_) {
    // SharedPreferences unavailable (e.g. a plugin-less test isolate) — the
    // badge is best-effort, never a hard dependency.
  }

  try {
    // app_badge_plus treats 0 as "remove the badge". isSupported() is false on
    // stock Android launchers (no count API — the notification dot stands in),
    // true on iOS and OEM launchers (Samsung/Xiaomi/Huawei/…).
    _badgeSupported ??= await AppBadgePlus.isSupported();
    if (_badgeSupported ?? false) {
      await AppBadgePlus.updateBadge(value);
    }
  } catch (_) {
    // Launcher incompatibility (or a flaky OEM provider) must never crash the
    // caller — least of all the FCM background isolate, where an escaping
    // throw would surface as a dropped-message error.
  }
}

/// Reads the persisted badge count, forcing a disk reload first. The FCM
/// background isolate may hold a stale in-memory SharedPreferences snapshot
/// taken before the live app last wrote, so a plain `getInt` could increment
/// from an old base — `reload()` pulls the latest value the live app stored.
Future<int> _readBadge() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getInt(_kBadgeCountKey) ?? 0;
  } catch (_) {
    return 0;
  }
}

/// Increments the persisted launcher-badge tally by one and pushes it to the
/// icon. Called from the FCM background isolate
/// ([firebaseMessagingBackgroundHandler]), where the app process is dead and no
/// app state / DI / cubits exist — the only things reachable are
/// SharedPreferences and the platform badge channel. The live app reconciles
/// this naive tally to the true unread count on next resume (see
/// `BadgeSyncController`), so any drift (a push for an already-read item, a
/// count read on another device) self-heals when the user reopens the app.
///
/// Fallback path — prefer [setAppBadgeFromBackground] when the push carries the
/// backend's authoritative `unread_count` (no blind tally needed then).
Future<void> incrementAppBadgeFromBackground() async {
  await _writeBadge(await _readBadge() + 1);
}

/// Writes the authoritative launcher-badge [count] from the FCM background
/// isolate. Used when the push payload carries the backend's `unread_count`
/// (the true server-side unread total): setting the exact value beats the naive
/// +1 in [incrementAppBadgeFromBackground] because it can't drift — a read on
/// another device or an already-read item is already reflected in the number
/// the server computed. Same crash-proofing as every other badge write.
Future<void> setAppBadgeFromBackground(int count) async {
  await _writeBadge(count);
}

/// Test-only: clears the cached [AppBadgePlus.isSupported] probe result so each
/// test can stub a fresh launcher-support verdict (the cache is a top-level,
/// isolate-global, so without this a `supported` test would poison an
/// `unsupported` one and vice-versa).
@visibleForTesting
void resetAppBadgeSupportCacheForTest() => _badgeSupported = null;

/// Crash-proof launcher-badge writer for the live app. Registered as a root
/// singleton and the only collaborator (alongside the background helper above)
/// that talks to `app_badge_plus` — swap the package here and nothing else
/// changes. Every call mirrors the count into SharedPreferences so the
/// background isolate carries it forward.
class AppBadgeService {
  /// Sets the launcher badge to [count]; values `<= 0` clear it.
  Future<void> setCount(int count) => _writeBadge(count);

  /// Clears the launcher badge and resets the stored tally to zero.
  Future<void> clear() => _writeBadge(0);
}

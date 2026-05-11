import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Thin wrapper over the root-scope Hive `cache` box. Repositories use it as
/// a write-through cache so the offline banner has something to render
/// against when the API is unreachable. Keys are namespaced by repository
/// so we can selectively invalidate (e.g. clear cart cache on logout).
class CacheStore {
  CacheStore(this._box);

  final Box _box;

  static const _ttlSuffix = '__ts';

  void putJson(
    String key,
    Object? value, {
    Duration ttl = const Duration(hours: 6),
  }) {
    if (value == null) {
      _box.delete(key);
      _box.delete('$key$_ttlSuffix');
      return;
    }
    _box.put(key, jsonEncode(value));
    _box.put('$key$_ttlSuffix',
        DateTime.now().add(ttl).toIso8601String());
  }

  /// Returns the cached value if it still satisfies the TTL — otherwise
  /// `null`. We don't throw on parse errors; bad cache lines are silently
  /// dropped so a corrupted box can't brick the screen.
  T? getJson<T>(String key, T Function(dynamic decoded) parse) {
    final raw = _box.get(key);
    if (raw is! String) return null;
    final tsRaw = _box.get('$key$_ttlSuffix');
    if (tsRaw is String) {
      final expires = DateTime.tryParse(tsRaw);
      if (expires == null || DateTime.now().isAfter(expires)) {
        _box.delete(key);
        _box.delete('$key$_ttlSuffix');
        return null;
      }
    }
    try {
      return parse(jsonDecode(raw));
    } catch (_) {
      _box.delete(key);
      _box.delete('$key$_ttlSuffix');
      return null;
    }
  }

  void invalidate(String prefix) {
    final keys = _box.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList();
    for (final k in keys) {
      _box.delete(k);
    }
  }
}

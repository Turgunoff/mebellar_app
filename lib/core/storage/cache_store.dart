import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:woody_app/core/logging/app_logger.dart';

/// Thin wrapper over the root-scope Hive `cache` box. Repositories use it as
/// a write-through cache so the offline banner has something to render
/// against when the API is unreachable. Keys are namespaced by repository
/// so we can selectively invalidate (e.g. clear cart cache on logout).
class CacheStore {
  CacheStore(this._box, {String Function()? localeOf}) : _localeOf = localeOf;

  final Box _box;

  /// Every payload cached here arrives pre-localised by the backend
  /// (`Accept-Language`), so the same logical key holds different bytes per
  /// language. Scoping the key by the active language is the cache-side
  /// equivalent of HTTP `Vary: Accept-Language` — without it, a cold start
  /// right after a language switch would paint the previous language from
  /// Hive. Null (tests) leaves keys unscoped.
  final String Function()? _localeOf;

  static const _ttlSuffix = '__ts';

  String _scoped(String key) {
    final lang = _localeOf?.call();
    return (lang == null || lang.isEmpty) ? key : '$key@$lang';
  }

  void putJson(
    String key,
    Object? value, {
    Duration ttl = const Duration(hours: 6),
  }) {
    final k = _scoped(key);
    if (value == null) {
      _box.delete(k);
      _box.delete('$k$_ttlSuffix');
      return;
    }
    _box.put(k, jsonEncode(value));
    _box.put('$k$_ttlSuffix',
        DateTime.now().add(ttl).toIso8601String());
  }

  /// Returns the cached value if it still satisfies the TTL — otherwise
  /// `null`. We don't throw on parse errors; bad cache lines are silently
  /// dropped so a corrupted box can't brick the screen.
  T? getJson<T>(String key, T Function(dynamic decoded) parse) {
    final k = _scoped(key);
    final raw = _box.get(k);
    if (raw is! String) return null;
    final tsRaw = _box.get('$k$_ttlSuffix');
    if (tsRaw is String) {
      final expires = DateTime.tryParse(tsRaw);
      if (expires == null || DateTime.now().isAfter(expires)) {
        _box.delete(k);
        _box.delete('$k$_ttlSuffix');
        return null;
      }
    }
    try {
      return parse(jsonDecode(raw));
    } catch (e, st) {
      appLog.handle(e, st, 'CacheStore: corrupt entry "$k"');
      _box.delete(k);
      _box.delete('$k$_ttlSuffix');
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

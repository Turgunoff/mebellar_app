import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_translations.dart';

/// Controls the active locale across the entire app. Wraps the value in a
/// `ValueNotifier<Locale>` so `MaterialApp.router(locale: ...)` rebuilds
/// when the user changes language. Persists the choice to the Hive
/// `settings` box so the next launch reuses it.
class AppLocaleController extends ValueNotifier<Locale> {
  AppLocaleController._(super.value, this._box);

  final Box _box;
  static const _settingsKey = 'app_locale';

  /// Read the persisted locale (or fallback) from the settings box.
  factory AppLocaleController.fromBox(Box settingsBox) {
    final raw = settingsBox.get(_settingsKey) as String?;
    final initial = _parseLocale(raw) ?? AppTranslations.fallbackLocale;
    return AppLocaleController._(initial, settingsBox);
  }

  /// Convenience constructor for tests/widget previews — uses an in-memory
  /// stand-in instead of the settings box.
  factory AppLocaleController.inMemory({Locale? initial}) {
    final box = _InMemoryBox();
    return AppLocaleController._(
      initial ?? AppTranslations.fallbackLocale,
      box,
    );
  }

  /// Resolves the active locale + persists it. Falls back to the existing
  /// value when [next] is not in the supported set so we never end up
  /// without a bundle.
  Future<void> setLocale(Locale next) async {
    final supported = AppTranslations.supportedLocales.any(
      (l) => l.languageCode == next.languageCode,
    );
    if (!supported) return;
    if (next == value) return;
    value = next;
    await _box.put(_settingsKey, next.languageCode);
  }

  static Locale? _parseLocale(String? code) {
    if (code == null || code.isEmpty) return null;
    return AppTranslations.supportedLocales.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => AppTranslations.fallbackLocale,
    );
  }
}

/// Resolves the [AppLocaleController] from the root scope of the DI when
/// available, otherwise creates an ephemeral in-memory one. Helpers like
/// the language picker use this so widgets don't need a `BuildContext`.
AppLocaleController? maybeAppLocaleController() {
  // Lazy import — the DI module imports us, so we look it up by name.
  // Resolved via a setter to avoid a hard dependency cycle.
  return _resolver?.call();
}

typedef LocaleControllerResolver = AppLocaleController? Function();
LocaleControllerResolver? _resolver;
void registerAppLocaleControllerResolver(LocaleControllerResolver fn) {
  _resolver = fn;
}

/// Minimal Hive `Box` stub for tests where opening a real box is overkill.
class _InMemoryBox implements Box {
  final Map<dynamic, dynamic> _data = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<int> add(dynamic value) async {
    final key = _data.length;
    _data[key] = value;
    return key;
  }

  @override
  Future<Iterable<int>> addAll(Iterable<dynamic> values) async {
    final keys = <int>[];
    for (final v in values) {
      keys.add(await add(v));
    }
    return keys;
  }

  @override
  Future<int> clear() async {
    final n = _data.length;
    _data.clear();
    return n;
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> compact() async {}

  @override
  bool containsKey(dynamic key) => _data.containsKey(key);

  @override
  Future<void> delete(dynamic key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final k in keys) {
      _data.remove(k);
    }
  }

  @override
  Future<void> deleteAt(int index) async {
    final key = _data.keys.elementAt(index);
    _data.remove(key);
  }

  @override
  Future<void> deleteFromDisk() async {}

  @override
  Future<void> flush() async {}

  @override
  dynamic getAt(int index) => _data.values.elementAt(index);

  @override
  bool get isEmpty => _data.isEmpty;

  @override
  bool get isNotEmpty => _data.isNotEmpty;

  @override
  bool get isOpen => true;

  @override
  dynamic keyAt(int index) => _data.keys.elementAt(index);

  @override
  Iterable<dynamic> get keys => _data.keys;

  @override
  bool get lazy => false;

  @override
  int get length => _data.length;

  @override
  String get name => 'in-memory-locale';

  @override
  String? get path => null;

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async {
    _data.addAll(entries);
  }

  @override
  Future<void> putAt(int index, dynamic value) async {
    final key = _data.keys.elementAt(index);
    _data[key] = value;
  }

  @override
  Map<dynamic, dynamic> toMap() => Map.from(_data);

  @override
  Iterable<dynamic> get values => _data.values;

  @override
  Iterable<dynamic> valuesBetween({dynamic startKey, dynamic endKey}) =>
      _data.values;

  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();
}

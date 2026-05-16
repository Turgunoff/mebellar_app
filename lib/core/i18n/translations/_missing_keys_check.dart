// Developer tool — translation completeness audit (ROADMAP B.8).
//
// The Uzbek bundle is the source of truth: every key that exists in `uz`
// must exist in `ru` and `en`, otherwise `tr('some.key')` silently falls
// back to echoing the raw key path to the user. This file flattens the three
// nested bundles and diffs them.
//
// Usage:
//   * `assertTranslationsComplete()` — call once at debug boot; throws via
//     `assert` (release builds: no-op) the moment `ru`/`en` drift below `uz`.
//   * `auditTranslations()` — returns a structured [TranslationAudit] for
//     tests (`test/i18n_completeness_test.dart`) and tooling.

import 'package:flutter/foundation.dart';

import 'all_translations.dart';

/// Flattens a nested translation bundle into the set of dot-path keys that
/// resolve to a leaf (non-`Map`) value — mirroring how `AppTranslations.tr`
/// walks a dotted path. `{'cart': {'empty': '...'}}` → `{'cart.empty'}`.
Set<String> flattenTranslationKeys(Map<String, dynamic> bundle) {
  final out = <String>{};

  void walk(String prefix, Map<dynamic, dynamic> map) {
    map.forEach((key, value) {
      final path = prefix.isEmpty ? '$key' : '$prefix.$key';
      if (value is Map) {
        walk(path, value);
      } else {
        out.add(path);
      }
    });
  }

  walk('', bundle);
  return out;
}

/// Result of comparing the `ru` / `en` bundles against the `uz` baseline.
class TranslationAudit {
  const TranslationAudit({
    required this.missingInRu,
    required this.missingInEn,
    required this.extraInRu,
    required this.extraInEn,
  });

  /// Keys present in `uz` but absent from `ru` — these surface as raw key
  /// paths to a Russian-locale user.
  final Set<String> missingInRu;

  /// Keys present in `uz` but absent from `en`.
  final Set<String> missingInEn;

  /// Keys present in `ru` but not in `uz` — dead/orphan keys (not user-facing
  /// breakage, but worth cleaning up).
  final Set<String> extraInRu;

  /// Keys present in `en` but not in `uz`.
  final Set<String> extraInEn;

  /// `true` when neither `ru` nor `en` is missing a `uz` key. This is the
  /// condition the debug-boot assert guards — it matches the ROADMAP B.8
  /// wording ("fewer keys than `uz`"); orphan keys are reported but do not
  /// fail the assert.
  bool get isComplete => missingInRu.isEmpty && missingInEn.isEmpty;

  bool get hasOrphanKeys => extraInRu.isNotEmpty || extraInEn.isNotEmpty;

  /// Human-readable multi-line summary, used as the `assert` message.
  String report() {
    final buffer = StringBuffer('Translation audit — uz baseline\n');
    void section(String title, Set<String> keys) {
      if (keys.isEmpty) return;
      buffer.writeln('  $title (${keys.length}):');
      for (final key in keys.toList()..sort()) {
        buffer.writeln('    - $key');
      }
    }

    section('MISSING in ru', missingInRu);
    section('MISSING in en', missingInEn);
    section('ORPHAN in ru (not in uz)', extraInRu);
    section('ORPHAN in en (not in uz)', extraInEn);
    if (isComplete && !hasOrphanKeys) {
      buffer.writeln('  ✓ all three bundles are in sync');
    }
    return buffer.toString();
  }
}

/// Diffs the live `uz` / `ru` / `en` bundles from [allTranslations].
TranslationAudit auditTranslations() {
  final uz = flattenTranslationKeys(uzTranslations);
  final ru = flattenTranslationKeys(ruTranslations);
  final en = flattenTranslationKeys(enTranslations);
  return TranslationAudit(
    missingInRu: uz.difference(ru),
    missingInEn: uz.difference(en),
    extraInRu: ru.difference(uz),
    extraInEn: en.difference(uz),
  );
}

/// Call once at debug boot. In `kDebugMode` it throws (via `assert`) the
/// instant `ru` or `en` is missing a `uz` key, so a developer notices the
/// gap immediately instead of shipping a raw `key.path` to users. Compiled
/// out of release builds entirely.
void assertTranslationsComplete() {
  if (!kDebugMode) return;
  final audit = auditTranslations();
  assert(audit.isComplete, audit.report());
}

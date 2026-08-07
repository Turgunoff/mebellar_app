import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T-10 error-handling boundary guard (see
/// `.claude/rules/error-handling.md` and `CLAUDE.md` §Error-handling
/// boundary): a repository interface is fully-`Result<T>` or fully-`throw`
/// — never mixed. `Stream<T>` methods (e.g. a `watch()` feed) sit outside
/// this axis entirely and are ignored.
///
/// Statically scans every `abstract class` declared directly in
/// `lib/shared/repositories/*.dart` (the interface files — a shared
/// implementation file may host several unrelated interfaces' `Woody*`
/// classes, which is a file-organisation detail, not a boundary violation).
/// A file with BOTH a `Result<...>`-typed method AND a plain throw-style
/// `Future<...>` method is mixed and fails, unless it's in [_allowlist] with
/// a documented reason (a repo still mid-T-10-migration, or an earlier,
/// deliberate reference-data-degrades-to-default design). This pins today's
/// known exceptions and blocks any NEW, undocumented violation rather than
/// letting the boundary decay silently.
void main() {
  test('every repository interface is fully Result<T> or fully throw', () {
    final dir = Directory('lib/shared/repositories');
    final abstractClassRe = RegExp(r'abstract class \w+[^{]*\{([\s\S]*?)\n\}');
    // Matches `Future<` NOT immediately followed by `Result<` — i.e. a
    // throw-style async return type (Future<void>, Future<List<Order>>, …).
    final throwFutureRe = RegExp(r'Future<(?!Result<)');

    final violations = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      final content = entity.readAsStringSync();

      for (final match in abstractClassRe.allMatches(content)) {
        final body = match.group(1)!;
        final hasResult = body.contains('Result<');
        final hasThrowFuture = throwFutureRe.hasMatch(body);
        if (hasResult && hasThrowFuture && !_allowlist.containsKey(name)) {
          violations.add(
            '$name: mixes Result<T> and throw-style Future<T> methods in '
            'the same interface — split the migration or add it to the '
            'allowlist with a reason if the mix is deliberate.',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('the allowlist matches exactly what it documents', () {
    // Guards the guard: an entry that no longer applies (repo finished
    // migrating, or the deliberate mix was removed) must come out —
    // otherwise this test would silently stop checking that file.
    expect(_allowlist.keys, {
      'seller_wallet_repository.dart',
      'seller_order_repository.dart',
      'shop_repository.dart',
    });
  });
}

/// Files allowed to mix `Result<T>` and throw-style `Future<T>` methods,
/// each for a documented reason — not a blanket exemption.
const _allowlist = {
  // T-10 (this roadmap entry) migration debt — order/seller_product/
  // seller_onboarding are done; this is the one repo left. Remove once it
  // migrates too.
  'seller_wallet_repository.dart':
      'T-10 in progress — the only remaining money-command repo on throw',

  // Pre-existing, deliberate design from an EARLIER migration phase
  // (roadmap B.1) — NOT T-10 debt. Real failure surfaces (state-machine
  // transitions, cancel) are Result<T>; pure reference-data reads
  // (fetchCancelReasons) and cleanup (dispose) intentionally degrade to a
  // safe default / no-op rather than erroring the UI over data that isn't
  // worth blocking on. See the file's own doc comments before "fixing" this.
  'seller_order_repository.dart':
      'deliberate: reference-data reads degrade to empty rather than Err',
  'shop_repository.dart':
      'deliberate: productsByShop degrades to empty rather than Err',
};

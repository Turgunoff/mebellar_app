---
description: Check uz/ru/en translation bundles are in sync; flag missing or orphan keys.
---

Run the i18n completeness audit. The `uz` bundle is the source of truth — every
key in `uz` must also exist in `ru` and `en`, otherwise `tr('some.key')`
silently echoes the raw path to the user. The same audit runs at debug boot
via `assertTranslationsComplete()`, but this command lets you run it on demand
(e.g. before committing a translation change).

Single step:

```
flutter test test/core/i18n/i18n_completeness_test.dart --reporter=compact
```

If it passes, report `✓ uz/ru/en in sync` and stop.

If it fails, the assertion message lists:

- `MISSING in ru` / `MISSING in en` — keys present in `uz` but absent
  from `ru` / `en`. These are user-facing breakage and must be fixed.
- `ORPHAN in ru` / `ORPHAN in en` — keys present in `ru` / `en` but not
  in `uz`. Dead translations; clean up if obvious, otherwise just flag.

For each missing key:

1. Find which namespace it belongs to via the dotted path
   (`cart.empty` → `lib/core/i18n/translations/cart_translations.dart`).
2. Add the key to the matching `*Ru` / `*En` map in the same file.
3. For short, mechanical strings ("Save" → "Сохранить" / "Save"), translate
   directly.
4. For copy that needs the user's tone (marketing, error wording, legal),
   add a `// TODO(i18n): review` comment on the line so it's easy to grep.
5. Re-run the test until it passes.

Do NOT modify `uz` to match `ru` / `en` — the direction is always
`uz → (ru, en)`.

Report the result as:

```
✓ i18n: all three bundles in sync   (N keys total)
```

or, on failure:

```
✗ i18n: M missing in ru, K missing in en
  → fixed: <list of keys>
  → review: <list of keys marked TODO(i18n)>
```

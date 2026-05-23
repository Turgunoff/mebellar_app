---
description: Fast pre-commit sanity — dart analyze + flutter test on the touched paths.
---

Run a quick health check before committing or pushing. Two steps:

1. **Static analysis** — run `dart analyze lib/`. Fail fast if any
   errors are reported. Warnings are OK but mention how many.
2. **Tests** — figure out what changed via `git status --short` and
   `git diff --name-only`:
   - If changed files are under `lib/customer/features/search/`, run
     `flutter test test/customer/features/search/`. Same pattern for
     other features (product_list, chat, etc.).
   - If the change touches `lib/shared/` or `lib/core/`, run the full
     `flutter test` since shared code can break anything.
   - If git is clean and there's nothing to test, just analyze and skip.

Report the result as a compact summary:

```
✓ analyze: 0 errors, N warnings
✓ tests:   K/K passed (PATH)
```

If anything fails, print the failing output and stop. Do NOT auto-fix
test failures — show me the diff so I can decide whether the test or
the code is wrong.

# Rule card — testing

> Distilled invariants for agents and `/review`. Authoritative narrative
> is `CLAUDE.md` (§Testing). `CLAUDE.md` wins.

- `test/` **mirrors** `lib/` paths. A test for
  `lib/customer/features/search/...` lives at `test/customer/features/search/...`.
- **Bloc/Cubit tests** use `bloc_test` + `mocktail`. Mock the **abstract
  repository interface** (each repo ships a `Woody*Repository` + in-memory
  mock) — not `WoodyApiClient` directly.
- **`registerFallbackValue` is mandatory** for any non-nullable type
  matched with `any()`:
  `setUpAll(() => registerFallbackValue(<Fake>()))`. Missing it is the most
  common cause of confusing mocktail failures.
- **Strict state expectations.** Adding a new emitted state to a bloc means
  updating the matching `expect: [...]` in order — don't loosen the matcher
  to hide a real change.
- **Widget tests** pump the widget inside the right theme/token providers
  so `PremiumTokens.of(context)` / `AuthTokens.of(context)` resolve. Verify
  render + interaction, not pixels.
- Inject a **Noop/fake `AnalyticsService`** — a test must never hit
  Firebase.
- **Never `skip` to go green.** If a test fails, decide whether the test or
  the code is wrong and say which.
- Scoped run: `flutter test test/<path>`. Full `flutter test` when
  `lib/shared/` or `lib/core/` changed (cross-cutting).
- **There is no CI** (removed 2026-09-17) — `flutter test` +
  `dart analyze lib/ test/` on your machine is the only gate. Baseline as of
  2026-09-18: **142 test files, 937 passing**, analyzer clean except one known
  `use_null_aware_elements` info. A red suite is never "the pipeline's problem."
- **The 5 golden tests are machine-bound.** `cart_screen_golden_test.dart`
  compares rendered pixels, so it only passes on an SDK/font stack matching the
  one the `.png` baselines were generated on. On a different Flutter version it
  fails with a small percentage diff (e.g. *"Pixel test failed, 1.02%, 4918px
  diff"*) while every other test is green — that is an environment mismatch,
  **not** a regression, and the fix is never `--update-goldens` on the odd
  machine (that just moves the breakage to the other one). A real failure names
  an expectation; a golden failure names a pixel count.
- `test/architecture/result_boundary_test.dart` is a **static guard**, not a
  behaviour test — it reads repository source and fails on a mixed
  `Result<T>`/`throw` interface. Keep its allowlist honest.
- **`Shell subprocess crashed with SIGTERM (-15)` is a flake, not your bug.**
  It shows up as `Failed to load "<some_test>.dart"` on a random file, and a
  different file each run. `flutter_tools` terminates a suite that takes too
  long to *load*, and on a busy machine (an Android emulator, a Gradle daemon,
  a parallel build) loading crosses that threshold. Re-run the named file on
  its own to confirm, then re-run the suite with `--concurrency=2`. Don't
  "fix" the test — nothing is wrong with it. A real failure names an
  expectation, not a signal number.

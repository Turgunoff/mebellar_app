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

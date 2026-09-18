# Rule card — error handling (`Result<T>` boundary)

> Distilled invariants for agents and `/review`. Authoritative narrative is
> `CLAUDE.md` (§Error-handling boundary). `CLAUDE.md` wins on conflict.

The app runs a **deliberate hybrid**: some repositories return `Result<T>`
(`lib/core/result/result.dart`), others `throw`. The split is drawn by **risk**,
on purpose — it is NOT a half-finished migration. This card keeps it from
decaying back into "whichever paradigm the last edit happened to reach for."

## The boundary — a repository is fully-`Result` OR fully-`throw`, never mixed

**`Result<T>` (mandatory)** — user-initiated *commands* where a swallowed error
is a business problem and the caller MUST handle failure explicitly:

- money / orders: `payment`, `checkout`, `order`, `seller_wallet`
- seller mutations: `seller_product`, `seller_onboarding`, `tariff`,
  `seller_services`, `verification`, `reviews` (submit)
- shop config writes: `shop`, `shop_settings`

**`throw` + global handler (allowed)** — read-heavy browsing whose only failure
UX is a generic "couldn't load, retry", plus all local persistence:

- reads: `product_data_source`, `category`, `banner`, `news`, `notifications`,
  `chat` reads, `profile_orders`
- local: `hive_cart`, `hive_favorites`, `cart`, `favorites`, cache / data-source
  layers

## Rules

- **No file mixes both.** A repo interface + its `Woody*` impl + its in-memory
  mock either ALL return `Future<Result<T>>` or none do. A mixed file is the
  exact smell this card exists to kill.
- **New network repo?** Command / money / mutation → `Result<T>`. Passive read
  or local store → `throw`. When it's genuinely ambiguous, ask which side of the
  boundary it's on — don't coin-flip.
- **`Result` methods** wrap the body in `runCatching(...)` (funnels a thrown
  `Failure` into an `Err`); callers use `fold(ok:, err:)` — never
  `.valueOrNull!` / `.failureOrNull!` to smuggle back to throwing.
- **`throw` methods** let a typed `Failure` (or a mapped exception) propagate to
  the bloc/cubit, which surfaces the same `Failure.message` UX a `Result` err
  would. Behaviour parity across the boundary is the point.

## Known debt — one repo left

**Done** (via `runCatching` + the shared `apiErrorToFailure` bridge in
`core/network/api_error_messages.dart`): `payment`, `checkout`, `order`,
`seller_product`, `seller_onboarding`.

**Remaining:** `seller_wallet` — the last money-command repo still fully on
`throw` (~10 methods: deposit / withdrawal / top-up). It stays **fully `throw`**
until its turn (never mixed); new code there SHOULD be written `Result`-first so
the migration shrinks.

## The guard test

`test/architecture/result_boundary_test.dart` statically scans every
`abstract class` in `lib/shared/repositories/` and fails on a file mixing
`Result<T>` with throw-style `Future<T>`. `Stream<T>` methods are ignored (a
`watch()` feed is off this axis). A second test pins the allowlist keys exactly,
so an exemption that no longer applies can't silently switch the guard off.

Allowlisted today — only the first is debt:

| File | Why |
|---|---|
| `seller_wallet_repository.dart` | migration debt (above) — remove the entry when it migrates |
| `seller_order_repository.dart` | **deliberate:** state transitions are `Result`; reference-data reads (`fetchCancelReasons`) and `dispose` degrade to a safe default rather than erroring the UI |
| `shop_repository.dart` | **deliberate**, same earlier design decision |

> Since there is no CI (removed 2026-09-17), this guard only runs when **you**
> run `flutter test`. Run it before committing repository changes.

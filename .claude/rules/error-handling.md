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

## Known debt — migrating incrementally (do not treat as "done")

These **command** repos belong on the `Result<T>` side but are still fully
`throw` today; they are being migrated one repo at a time, each with tests,
highest-risk first:

`order` → `seller_wallet` → `seller_product` → `seller_onboarding`

Done (via `runCatching` + the shared `apiErrorToFailure` bridge in
`core/network/api_error_messages.dart`):
- `payment` — `checkoutUrl` → `Result<CheckoutLink>`
- `checkout` — `quote` → `Result<CheckoutQuote>`, `placeOrder` → `Result<String>`

Until a repo's turn comes it stays **fully `throw`** (never mixed). New code in
these repos SHOULD be written `Result`-first so the eventual migration shrinks.
A guard test (`test/architecture/result_boundary_test.dart`) will pin this once
added — allowlisting the repos above as known debt, blocking NEW violations.

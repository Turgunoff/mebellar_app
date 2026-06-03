# Rule card — architecture

> Distilled invariants for agents and `/review`. Authoritative narrative
> is `CLAUDE.md` (§Two-mode shell, §State management). `CLAUDE.md` wins.

## Two-mode shell

- One binary, two modes (customer / seller), resolved from Hive at boot
  with a security guard that demotes to customer if the cached
  seller-approval flag is false.
- `switchAppMode(...)` flips the persisted mode, swaps the GetIt scope,
  and `Phoenix.rebirth`s the subtree.
- **Customer cubits are not registered in the seller scope and vice
  versa.** Cross-mode code lives in `lib/shared/`. The shared chat module
  works in both modes via `viewer: ChatSenderRole.customer | .seller`.
- Customer router = `GoRouter`; seller router = `StatefulShellRoute` (5
  tabs). Adding a seller bottom-tab touches `seller_router.dart` — confirm
  before doing so.

## State management

- **Bloc** for event-driven flows (search, cart, orders); **Cubit** for
  single-input commands (profile, checkout, mode).
- Repositories are **abstract interfaces** with a `Woody*Repository` impl
  (over `WoodyApiClient`) + an in-memory mock for tests. There is **no**
  raw `Dio`/`Remote*` layer.
- DI via **GetIt** (`lib/core/di/service_locator.dart`). Registration
  **order matters** — e.g. `AppModeCubit` uses a lookup closure
  (`() => sl<AnalyticsService>()`) because it's built before
  catalog_module registers analytics.

## Analytics & Crashlytics

- `AnalyticsService` injected via constructor (optional `AnalyticsService?`).
  Always `unawaited(_analytics?.foo(...))` — analytics must never throw or
  block the UI. Firebase predefined event names where they exist; custom
  snake_case otherwise.
- Crashlytics is initialised in `main.dart` before `_bootstrapAndRun`;
  collection only when `!kDebugMode`. Don't reintroduce Sentry (conflicts
  on `FlutterError.onError`).

---
description: Scaffold a new feature folder with stub bloc/cubit, screen, DI registration, route, and i18n namespace.
argument-hint: [feature_name] [customer|seller] [bloc|cubit]
---

Scaffold a new feature following the existing layered convention
(`lib/<mode>/features/<name>/{bloc|cubit, screens}` + repo in
`lib/shared/repositories/` + i18n namespace + scope-module DI
registration + GoRoute). `$ARGUMENTS` may contain `<name> <mode> <state>`
in any order — parse what's there, ask for the rest.

## Step 1 — gather inputs

If not already supplied, ask me for:

1. **Feature name** — snake_case, used for folder + class prefix
   (e.g. `wishlist` → `WishlistBloc`, `WishlistScreen`).
2. **Mode** — `customer` or `seller`. Customer features live under
   `lib/customer/features/`, seller features under `lib/seller/features/`.
3. **State management** — `bloc` (multi-event flows: list + filter +
   pagination, optimistic updates) or `cubit` (single command: form
   submit, fetch-and-render).
4. **Repository?** — `yes` if the feature owns data the rest of the
   app doesn't already expose (a new Supabase table, a new domain).
   `no` if it composes existing repos.
5. **Route path** — what URL it should be reachable at (e.g.
   `/wishlist`). For seller, also ask whether it's a new bottom-tab
   (uses `StatefulShellRoute`, more involved — confirm before touching
   `seller_router.dart`) or a pushed screen.

If a Supabase migration is needed, **stop and tell me to run
`/new-migration` first** — schema must exist before the repo is
written.

## Step 2 — create the folder structure

```
lib/<mode>/features/<name>/
├── <bloc|cubit>/<name>_<bloc|cubit>.dart
└── screens/<name>_screen.dart
```

Only create `widgets/` if I confirm I'll need feature-local widgets
(don't pre-create empty folders).

## Step 3 — write the stub state holder

**For `bloc`**, follow the `FavoritesBloc` shape
(`lib/customer/features/favorites/bloc/favorites_bloc.dart`):

- `sealed class <Name>Event extends Equatable` with `const props` getter
- A `<Name>Requested` initial event + one or two domain events
- `enum <Name>Status { initial, loading, ready, failure }`
- `class <Name>State extends Equatable` with `status`, domain fields,
  `error`, and `copyWith({…, bool clearError = false})`
- `class <Name>Bloc extends Bloc<<Name>Event, <Name>State>` —
  constructor takes the repo, registers handlers, optionally subscribes
  to a stream and cancels in `close()`.
- Optimistic state changes (where applicable) roll back on `catch`.

**For `cubit`**, follow the `ProfileCubit` shape
(`lib/customer/features/profile/cubit/profile_cubit.dart`):

- `class <Name>State extends Equatable` with explicit fields (no Status
  enum required for single-command flows; use `isLoading: bool`).
- `class <Name>Cubit extends Cubit<<Name>State>` with one or two
  `Future<void>` methods that `emit(...)` after the work.
- Errors caught via `try/catch` → `talker.handle(e, st, 'context')`
  → emit a degraded state. Never let exceptions escape.

Both shapes: analytics is an **optional** `AnalyticsService?` named
constructor param, invoked via `unawaited(_analytics?.…)`.

## Step 4 — repository (only if Step 1 said yes)

Create two files in `lib/shared/repositories/`:

1. `<name>_repository.dart` — `abstract class <Name>Repository` declaring
   the methods the bloc/cubit will call. Plain Dart types in / out,
   no Supabase types in the signature.
2. `supabase_<name>_repository.dart` — `class Supabase<Name>Repository
   implements <Name>Repository` with `SupabaseClient _supabase` injected
   via the constructor.

If the feature is offline-capable (cart/favorites pattern), also create
a `Hybrid<Name>Repository` that composes Hive + Supabase — but only if
I explicitly ask. Most features don't need it.

## Step 5 — DI registration

- **Repository** (if any) → `lib/core/di/catalog_module.dart`,
  inside `registerCatalogModule(sl)`. Use `sl.registerLazySingleton<
  <Name>Repository>(() => Supabase<Name>Repository(supabase:
  sl<SupabaseClient>()))`. Wrap in `if (sl.isRegistered<SupabaseClient>())`
  if the repo is Supabase-only.
- **Bloc/Cubit** → `lib/core/di/scope_module.dart`, inside
  `registerCustomerScope(sl)` OR `registerSellerScope(sl)` (NEVER
  both — modes are mutually exclusive). Default to:
  ```dart
  sl.registerLazySingleton<<Name>Bloc>(
    () => <Name>Bloc(sl<<Name>Repository>())..add(const <Name>Requested()),
    dispose: (bloc) => bloc.close(),
  );
  ```
  Use `registerFactory` instead of `registerLazySingleton` only if each
  screen should get a fresh instance (e.g. forms, detail screens) —
  confirm with me before choosing factory.

## Step 6 — route

Add a `GoRoute` to `lib/customer/router.dart` (customer mode) or
`lib/seller/seller_router.dart` (seller mode). For a singleton bloc
already registered in scope:

```dart
GoRoute(
  path: '<route-from-step-1>',
  builder: (context, state) => BlocProvider.value(
    value: sl<<Name>Bloc>(),
    child: const <Name>Screen(),
  ),
),
```

For a factory cubit:

```dart
GoRoute(
  path: '<route>',
  builder: (context, state) => BlocProvider(
    create: (_) => sl<<Name>Cubit>()..load(),
    child: const <Name>Screen(),
  ),
),
```

For seller, if it's a new bottom-tab, **stop** and confirm — the
`StatefulShellRoute` branches in `seller_router.dart` require careful
edits and I'll want to review the diff before you touch them.

## Step 7 — i18n namespace

1. Create `lib/core/i18n/translations/<name>_translations.dart` with
   three top-level maps `<name>Uz`, `<name>Ru`, `<name>En` containing
   the obvious starter keys (`title`, `empty`, `loading`, `error`).
   Translate uz → ru/en directly for short mechanical strings.
2. Wire it into `lib/core/i18n/translations/all_translations.dart`:
   add the import and a `'<name>': <name>{Uz,Ru,En},` entry to **all
   three** bundle maps. Forgetting one trips the boot-time guard
   (`_missing_keys_check.dart`).

## Step 8 — write the screen stub

Minimal `<name>_screen.dart` following the customer-side convention:

- `StatelessWidget` (or `StatefulWidget` if it needs local state).
- Reads tokens via `PremiumTokens.of(context)` (customer) — **never**
  hardcode colours. For seller-mode local widgets follow whatever the
  feature's design partner uses (`kInk`/`kDivider`/`kTerracotta`
  constants are common).
- Wires the bloc via `BlocBuilder<<Name>Bloc, <Name>State>` or
  `context.read<<Name>Cubit>()`.
- Uses `tr('<name>.title')` for the AppBar label.
- Renders `BrandLoadingIndicator()` for the loading state, an error
  panel for failures.

## Step 9 — verify

Run `dart analyze lib/` and report:

- 0 errors → print `✓ scaffold ready` plus a summary table:
  ```
  files created:
    lib/<mode>/features/<name>/<bloc|cubit>/<name>_<...>.dart
    lib/<mode>/features/<name>/screens/<name>_screen.dart
    lib/shared/repositories/<name>_repository.dart           (if Step 4)
    lib/shared/repositories/supabase_<name>_repository.dart  (if Step 4)
    lib/core/i18n/translations/<name>_translations.dart
  files edited:
    lib/core/di/catalog_module.dart                          (if Step 4)
    lib/core/di/scope_module.dart
    lib/customer/router.dart  OR  lib/seller/seller_router.dart
    lib/core/i18n/translations/all_translations.dart
  ```
- Any errors → print them and stop. Do NOT auto-fix without showing
  me the diff first.

Do NOT auto-write tests, auto-translate marketing copy, or add the
feature to the bottom-nav. Those are separate decisions.

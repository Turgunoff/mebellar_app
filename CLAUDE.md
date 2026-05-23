# Mebellar — project brain

Furniture marketplace for Uzbekistan. Flutter mobile app with two
distinct modes (customer + seller) inside one binary, backed by
Supabase. Package name `com.mebellar.app`, internal Dart package name
`woody_app`.

## Tech stack

- **Flutter** (Dart SDK `^3.11.5`) — single binary, customer + seller modes
- **Supabase** — Postgres + Auth + Storage + Realtime; the only backend
- **Firebase** — Messaging (FCM), Crashlytics, Analytics; **no Firebase Auth** (Supabase owns auth)
- **Hive** — local storage (settings, cart, favourites, news-reads cache)
- **GetIt** — service locator for DI
- **flutter_bloc** — Bloc + Cubit state management
- **go_router** — customer + seller routers (seller uses StatefulShellRoute)
- **flutter_phoenix** — restart subtree on customer↔seller mode swap

## Folder layout

```
lib/
├── auth/                        passwordless email-OTP bottom-sheet flow
├── config/                      AppConfig, RemoteConfig, AppMode
├── core/
│   ├── analytics/               AnalyticsService (abstract + Firebase + Noop)
│   ├── auth/                    AuthCubit, AppModeCubit
│   ├── di/                      service_locator + module registration
│   ├── i18n/                    AppTranslations (Dart bundles, no .arb)
│   ├── logging/                 Talker + CrashlyticsTalkerObserver
│   ├── notifications/           PushService (FCM bootstrap)
│   ├── realtime/                Supabase Realtime channel helper
│   └── theme/                   AppColors, AppFonts, customer/seller themes
├── customer/
│   ├── customer_app.dart        MaterialApp.router for customer
│   ├── router.dart              GoRouter (FirebaseAnalyticsObserver attached)
│   └── features/                home, search, catalog, product_list,
│                                product_detail, cart, checkout, orders,
│                                favorites, profile, categories, chats,
│                                notifications, reviews
├── seller/
│   ├── seller_app.dart          MaterialApp.router for seller
│   ├── seller_router.dart       StatefulShellRoute, 5 tabs
│   └── features/                dashboard, products, orders, analytics,
│                                profile, settings, onboarding, verification,
│                                reviews, tariff, notifications
└── shared/
    ├── chat/                    SHARED chat module (used by both modes)
    │   ├── bloc/                ChatsListCubit, ChatThreadCubit
    │   ├── screens/             ChatsListScreen, ChatThreadScreen
    │   └── widgets/             MessageBubble, ChatComposer, etc.
    ├── models/                  Product, Order, Chat, Category, etc.
    ├── repositories/            Supabase + remote-REST fallback pairs
    └── widgets/                 cross-mode UI primitives
```

## Build & run

**Env file is mandatory** — `String.fromEnvironment` reads from
`--dart-define-from-file`, and `AppConfig.assertConfigured()` throws at
boot if any required key is empty. A build without env crashes
before the splash even paints.

```bash
# Dev (USB device, hot reload)
flutter run --dart-define-from-file=env/prod.json

# Release AAB for Play Console (preferred path)
./tools/build_release.sh
# Equivalent to:
#   flutter build appbundle --release \
#     --dart-define-from-file=env/prod.json \
#     --obfuscate --split-debug-info=build/symbols
# AAB lands at: build/app/outputs/bundle/release/app-release.aab
# Symbols saved at: build/symbols/   (do NOT commit — gitignored)

# Quick release APK for sideloading
flutter build apk --release --dart-define-from-file=env/prod.json
adb install build/app/outputs/flutter-apk/app-release.apk

# Tests + analysis
flutter test
dart analyze lib/
```

Env keys live in `env/prod.json` (gitignored) — copy from `env/example.json`.
Required: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `YANDEX_GEOCODER_API_KEY`.
The Sentry DSN was removed when Crashlytics replaced Sentry — do not re-add it.

## Architecture conventions

### Two-mode shell

The app boots into a mode (customer or seller) resolved from Hive at
startup, with a security guard that demotes to customer if the cached
seller-approval flag is false. `switchAppMode(...)` flips the persisted
mode, swaps the GetIt scope, and `Phoenix.rebirth`s the subtree.
Customer cubits are not registered in the seller scope and vice versa.
The shared chat module works in both modes by passing `viewer:
ChatSenderRole.customer | .seller`.

### State management

Bloc for events-driven flows (search, cart, orders), Cubit for
single-input commands (profile, checkout, mode). Repositories are
abstract interfaces with Supabase + sometimes mock/REST implementations
(`RepositoryResolver` picks at startup based on `AppConfig.hasSupabase`).

### Theme tokens — never hardcode colours

The app has light and dark mode. **All surface / text / border /
field-fill colours come from token classes**, not const literals:

- `PremiumTokens.of(context)` — customer screens (home, search, chat, profile)
- `AuthTokens.of(context)` — auth bottom sheet (email/OTP/profile steps)
- `kInk`, `kDivider` etc. — seller-mode local tokens in
  `seller/features/orders/widgets/order_details/order_details_kit.dart`

Brand accents (`PremiumTokens.accent`, `kTerracotta`, both
`#C27A5F`) are constants — they don't flip in dark mode.

### Localisation

Translations live as Dart `Map<String, dynamic>` bundles under
`lib/core/i18n/translations/`. No `.arb` files. Add a new key:

1. Add to all three language bundles (`*Uz`, `*Ru`, `*En`) — uz is the baseline
2. `tr('namespace.key')` from anywhere — context-free
3. The `_missing_keys_check.dart` guard throws at boot in debug mode if ru/en
   are missing keys that uz has

### Analytics

`AnalyticsService` injected via constructor into blocs/cubits, optional
`AnalyticsService?` named param. Use `unawaited(_analytics?.foo(...))` —
analytics must never throw or block the UI. Predefined Firebase event
names (`view_item`, `add_to_cart`, `purchase`, `sign_up`, …) are used
where they exist; custom snake_case names for the rest. `AppModeCubit`
uses a *lookup closure* (`() => sl<AnalyticsService>()`) because it's
constructed before catalog_module registers analytics — module order
matters in `service_locator.dart`.

### Crashlytics

Initialised in `main.dart` BEFORE `_bootstrapAndRun`. Three handlers
wired:
- `FlutterError.onError` → `recordFlutterFatalError`
- `PlatformDispatcher.instance.onError` → `recordError(fatal: true)`
- `runZonedGuarded` catches anything that escaped both
- `CrashlyticsTalkerObserver` → `talker.handle(...)` becomes a non-fatal report

Collection is enabled only when `!kDebugMode` — debug crashes don't
pollute prod dashboards. The `environment` custom key tags every
report with `prod` / `dev`.

### Supabase RLS gotchas

These are gotchas you will hit if you don't read them:

1. **`orders.user_id`, NOT `orders.customer_id`** — the legacy column
   name. `chats.customer_id` IS named correctly (separate table).
2. **`shops.name` collision in storage policies**: inside `EXISTS
   (SELECT 1 FROM shops s WHERE ...)`, an unqualified `name` rebinds to
   `s.name` (shop display name), not `objects.name` (file path). Always
   lift the path-segment extraction OUT of the inner subquery — see
   migration `20260523015757_fix_shop_assets_rls_final.sql` for the
   pattern.
3. **PostgREST embed ambiguity** — when a column has two FKs (e.g.
   `chats.customer_id` is FK'd to both `auth.users` and `profiles`),
   use the constraint name as the embed hint:
   `customer:profiles!chats_customer_id_profiles_fkey(id, full_name)`.
4. **`storage.objects` direct DELETE is blocked** by `protect_delete`
   trigger. Bypass for one-off cleanups:
   `SET LOCAL storage.allow_delete_query = 'true';` inside a tx.
5. After any RLS or policy change: `NOTIFY pgrst, 'reload schema';` so
   PostgREST picks it up without a server bounce.

### Migrations

Live at `supabase/migrations/<yyyymmddHHMMSS>_<name>.sql`. Applied via
the Supabase MCP `apply_migration` (preferred — atomic + logged) or
via `supabase db push`. **Always** save the SQL locally as a migration
file too — applying via MCP doesn't persist to the repo, and
`supabase db reset` would silently lose the schema change.

### Chat (per-order)

One row in `chats` per `order_id` (UNIQUE constraint). Customer
lazy-creates the row on first message; seller can never spawn a chat.
Chat stays OPEN forever, even after order delivered/cancelled — the
`ChatStatusBanner` reflects current order status with copy + a "Leave
a review" CTA on delivered orders (customer side only). Realtime:
inserts on `chat_messages` are subscribed via Supabase Realtime; the
list view auto-refreshes on any `chats` row change.

### Filter & search

`ProductSearchFilter` is the single filter type for both global search
and in-category browsing. Pass `showCategories: false` to the filter
sheet when scope is already pinned (in-category product list). Filter
sheet adapts options to the **currently visible products** —
`FilterAvailability` (computed at open time) hides dead-end colour
swatches and dead toggles (no discounted products → "Discounted"
toggle hidden, unless already active).

## Conventions

### Comments

Default to writing no comments. Add one only when the WHY is non-
obvious — a hidden constraint, a workaround for a specific bug, an
invariant a future reader wouldn't guess. Don't restate what the code
does. Don't reference the current task or PR — that belongs in commit
messages.

### Identifiers

Snake_case for analytics event names (matches Firebase predefined
naming). camelCase for Dart. Translation keys: dot-separated namespaced
paths (`chat.composer_hint`, `search.filter.title`).

### Testing

`test/` mirrors `lib/` paths. Bloc tests use `bloc_test` + `mocktail`.
`registerFallbackValue` is mandatory for non-nullable types matched
with `any()` — `setUpAll(() => registerFallbackValue(...))`. Existing
test suite expectations are strict — when adding a new emitted state
to a bloc, update the matching test or it will fail.

### What NOT to do

- Don't hardcode colours — always use a token bag (`PremiumTokens`,
  `AuthTokens`, `pt.dark`, `t.surface`, etc.)
- Don't add comments without a WHY worth recording
- Don't push to Play Console without bumping `version` in `pubspec.yaml`
  (`1.0.3+4` → `1.0.3+5`)
- Don't run `flutter build appbundle --release` without
  `--dart-define-from-file=env/prod.json` — the build is silently
  unusable. Use `./tools/build_release.sh` instead.
- Don't reintroduce Sentry — Crashlytics replaced it and the two
  conflict on `FlutterError.onError`
- Don't filter shops table inside storage RLS via unqualified `name`
- Don't pass `customer_id` to `orders` table — column is `user_id`
- Don't commit `env/prod.json`, `key.properties`, `*.jks`,
  `build/symbols/`, `google-services.json` if it contains secrets

## Recent feature work (Spring 2026)

This brain captures the state after a multi-session redesign:

- Search + per-category filter sheet — `ProductSearchFilter`, adaptive
  facet visibility, search UI redesigned with active-filter pills
- Subcategory chip bar in product list with realtime-safe race protection
- Per-order chat system — text + image, realtime delivery, read
  receipts, status banner
- Per-order chat lives in `lib/shared/chat/` and is reused by both modes
- Analytics + Crashlytics replaced Sentry; events wired into auth,
  search, cart, checkout, chat, seller (onboarding, products, orders)
- Profile/seller-profile cleanup — "Bildirishnomalar" entry removed
  from seller profile (redundant with dashboard bell)
- Auth bottom sheet (email → OTP → profile) refactored for dark mode
  via `AuthTokens`

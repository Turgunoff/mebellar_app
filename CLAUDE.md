# Woody — project brain

Furniture marketplace for Uzbekistan. Flutter mobile app with two
distinct modes (customer + seller) inside one binary, backed by a custom
FastAPI backend (`woody_backend` at `api.woody.uz`). Package name
`com.mebellar.app`, internal Dart package name `woody_app`.

> **Workspace master spec:** [`../docs/TZ.md`](../docs/TZ.md) (v1.1+) is the single source of truth for the whole platform. This file is the operational brain for the Flutter app. (`AGENTS.md` was merged here and removed.)

## Tech stack

- **Flutter** (Dart SDK `^3.11.5`) — single binary, customer + seller modes
- **woody_backend** — FastAPI + Postgres + R2 storage + WebSocket realtime at `api.woody.uz`; the only backend
- **Firebase** — Messaging (FCM), Crashlytics, Analytics; **no Firebase Auth** (woody_backend owns auth)
- **Hive** — local storage (settings, cart, favourites, news-reads cache)
- **GetIt** — service locator for DI
- **flutter_bloc** — Bloc + Cubit state management
- **go_router** — customer + seller routers (seller uses StatefulShellRoute)
- **flutter_phoenix** — restart subtree on customer↔seller mode swap

## Folder layout

```
lib/
├── auth/                        passwordless phone-OTP full-screen flow (showAuthScreen)
├── config/                      AppConfig, RemoteConfig, AppMode
├── core/
│   ├── analytics/               AnalyticsService (abstract + Firebase + Noop)
│   ├── auth/                    AuthCubit, AppModeCubit
│   ├── di/                      service_locator + module registration
│   ├── i18n/                    AppTranslations (Dart bundles, no .arb)
│   ├── logging/                 Talker + CrashlyticsTalkerObserver
│   ├── notifications/           PushService (FCM bootstrap)
│   ├── realtime/                WoodyRealtimeService (WebSocket) helper
│   └── theme/                   AppColors, AppFonts, customer/seller themes
├── customer/
│   ├── customer_app.dart        MaterialApp.router for customer
│   ├── router.dart              GoRouter (FirebaseAnalyticsObserver attached)
│   └── features/                home, search, product_list, cart,
│                                checkout, orders, favorites, profile,
│                                categories, chats, notifications, reviews,
│                                shop, ai_designer
├── seller/
│   ├── seller_app.dart          MaterialApp.router for seller
│   ├── seller_router.dart       StatefulShellRoute, 5 tabs
│   └── features/                dashboard, products, orders, analytics,
│                                profile, settings, onboarding, verification,
│                                reviews, tariff, notifications, wallet
└── shared/
    ├── chat/                    SHARED chat module (used by both modes)
    │   ├── bloc/                ChatsListCubit, ChatThreadCubit
    │   ├── screens/             ChatsListScreen, ChatThreadScreen
    │   └── widgets/             MessageBubble, ChatComposer, etc.
    ├── models/                  Product, Order, Chat, Category, etc.
    ├── repositories/            Woody REST repos (+ mock pairs for tests)
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
Required: `WOODY_API_URL`, `YANDEX_GEOCODER_API_KEY`.
The Sentry DSN was removed when Crashlytics replaced Sentry — do not re-add it.

### Code push (Shorebird)

Shorebird (`shorebird.yaml`, `app_id: c1639a0d-…`) lets us hot-fix shipped
builds **without a store review** — but only **Dart code** rides a patch.
Native (`android/`, `ios/`), bundled `assets/`, `pubspec` dependency, and
Flutter-version changes all need a brand-new release; Shorebird's own CLI
refuses those diffs (`--allow-native-diffs` / `--allow-asset-diffs` warn they
crash the app).

`tools/shorebird.sh` is the wrapper (mirrors `build_release.sh`'s env/signing
preflight; same `--obfuscate --split-debug-info`):

```bash
./tools/shorebird.sh check                 # "what did I change — patch-safe or not?"
./tools/shorebird.sh release android       # patchable store build + ledger entry
./tools/shorebird.sh patch android         # preflight-gated Dart patch to the live release
./tools/shorebird.sh log                   # release history
```

Invariants:

- **A patchable store build MUST come from `shorebird release`**, not
  `flutter build` / `build_release.sh`. Plain builds can't receive patches —
  `build_release.sh` now prints that reminder when `shorebird.yaml` exists.
- **The ledger is the history file** — `tools/shorebird/releases.md` (a
  markdown table; `.md` not `.log`, since `*.log` is gitignored) records
  `sana | versiya | git_sha | platforma | izoh` per release (committed to
  git). `check`/`patch` diff today's tree against the recorded SHA, so you
  always see *which files changed since the version you shipped* — the thing
  that's easy to forget. `release` appends automatically; `record <version>`
  logs a release built outside the script.
- **`patch` is preflight-gated** — it runs `check` first and aborts on a
  blocker (native/asset/flutter), so you can't accidentally ship a crashing
  patch. `--force` bypasses the guard (not recommended).
- **No Shorebird secret in the repo** — `shorebird.yaml`'s `app_id` is public
  by design; auth is the developer's `shorebird login` on the build machine,
  not a committed token.

## Architecture conventions


### Platform money, push & privacy (Aug 2026)

- **Internal escrow (not Payme Safe/Split):** online Payme/Click payment is held by Woody; on order `delivered`, the backend settles commission and credits seller `order_income`; sellers request card payouts via `wallet_withdrawals` (admin approve/reject). Details: workspace [`../docs/TZ.md`](../docs/TZ.md) monetization / escrow sections.
- **Hybrid inbox + push prefs:** guests read public news via `/catalog/news`; signed-in personal alerts via `/notifications`. `promo_push_enabled` → Flutter FCM topic `news`; `order_push_enabled` → backend may suppress OS FCM for ORDER types while keeping the in-app inbox.
- **Analytics privacy:** Settings **"Foydalanish statistikasi"** disables Firebase Analytics + Crashlytics (and Meta gated events) at toggle time and on cold boot via Hive. Never reintroduce always-on collection.

### Seller Oferta (B2B legal) — Aug 2026

- **Dynamic legal text:** Oferta bodies are **NOT hardcoded** as the source of
  truth. Fetch `GET /legal/oferta?lang=` via `LegalDocumentsRepository` /
  `WoodyLegalDocumentsRepository`, then interpolate
  `{{SOTUVCHI_NOMI}}`, `{{KOMISSIYA_FOIZI}}`, `{{SANA}}` with
  `injectOfertaPlaceholders` (`seller_contract_oferta.dart`). The embedded
  `kSellerOfertaFallbackContent` is offline/404 only. Pass
  `AppLocaleController.value.languageCode` as `lang` (uz/ru/en; backend falls
  back to uz).
- **Scroll-to-accept + stamp:** `SellerContractScreen` disables Accept until
  the seller scrolls to the bottom; onboarding submit stamps
  `contract_accepted_at` / `contract_version` via `POST /seller/onboarding`.
  Profile opens the same screen read-only.
- **PDF generation:** Uses `pdf` and `printing`. Logic lives in
  `lib/seller/features/onboarding/utils/contract_pdf_generator.dart`. Always
  use **Inter TTF** (`assets/google_fonts/Inter-*.ttf`) for PDF fonts so
  Cyrillic and Latin render without tofu boxes. Footer is two-column
  (Zettacode MCHJ left, seller right); labels localize by `languageCode`.

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
abstract interfaces with a Woody REST implementation (`Woody*Repository`,
talking to `WoodyApiClient`) plus an in-memory mock used by tests. Every
repository runs against `WoodyApiClient` — there is no raw-`Dio`/`Remote*`
layer left.

### Error-handling boundary (`Result<T>` vs `throw`) — a *deliberate* hybrid

Repositories are split by **risk**, not by whichever paradigm got typed last.
This is intentional; treat it as a rule, not a migration to "finish everywhere."
Rule card: [`.claude/rules/error-handling.md`](.claude/rules/error-handling.md).

- **`Result<T>`** (`lib/core/result/result.dart`) is **mandatory for
  user-initiated commands** where a swallowed error is a business problem —
  money / orders / seller mutations: `payment`, `checkout`, `order`,
  `seller_wallet`, `seller_product`, `seller_onboarding`, `tariff`,
  `verification`, `seller_services`, `reviews` (submit), `shop`,
  `shop_settings`. The method wraps its body in `runCatching(...)`; callers
  `fold(ok:, err:)`.
- **`throw` + global handler is allowed** for read-heavy browsing (only failure
  UX is a generic "couldn't load, retry") and all local Hive persistence:
  `product_data_source`, `category`, `banner`, `news`, `notifications`, `chat`
  reads, `hive_cart`, `hive_favorites`, cache / data-source layers.
- **A repository is fully-`Result` OR fully-`throw` — never mixed** (interface +
  `Woody*` impl + mock agree). A mixed file is the smell this rule kills.
- **Known debt, filled incrementally (tested, highest-risk first):** the command
  repos `order → seller_wallet → seller_product → seller_onboarding` are still on
  `throw` and are migrating to `Result<T>`. Each stays fully-`throw` until its
  turn; new code there is written `Result`-first. **Done:** `payment`
  (`checkoutUrl`) and `checkout` (`quote` / `placeOrder`) — via `runCatching` +
  the shared `apiErrorToFailure` bridge in `core/network/api_error_messages.dart`.

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
matters in `service_locator.dart`. AI events: `ai_suggest_requested`,
`ai_suggest_applied`.

### AI product authoring (seller "fill from photos")

The seller add-product form can draft itself from the uploaded photos.
The work is **all backend** — the app speaks only REST; there is no AI
SDK or API key in the app (woody_backend owns the Azure/Foundry key).

Flow: `MediaSection` shows the "AI bilan to'ldirish" CTA once ≥1 photo is
picked → `AddProductCubit.generateFromImages()` →
`AddProductRepository.suggestFromImages()` uploads the photos to R2 (reusing
the normal product-image upload) and POSTs the URLs to
`/seller/products/ai-suggest` → applies the returned
`AiProductSuggestion` (name, description, category, subcategory, colours,
attributes). **AI never auto-saves** — the seller reviews and taps save.

Invariants:

- **Sequencing matters.** `_applySuggestion` selects the category first and
  **awaits the attribute schema load** (`_awaitSchema`) before writing AI
  attributes, so only keys the chosen category defines survive — same rule
  the manual form enforces. Colours are filtered through `productColorBySlug`.
  The category attribute schemas (dimensions, materials, `mattress_included`
  switch, …) are seeded backend-side (`0011_seed_attributes.py`,
  `0012_revise_bed_attributes.py`); `DynamicAttributesSection` renders all five
  data types (select/multiselect/number/text/bool), so AI-filled attributes
  show as the right widget. An empty schema = no attribute fields.
- **Dimensions card.** `DynamicAttributesSection` splits out the per-piece
  dimension attributes (`number` + unit `sm` + label `"Piece — measure"`, e.g.
  `bed_length_cm` "Krovat — uzunligi") into a grouped `DimensionsCard`
  (KARAVOT / SHKAF / TRYUMO headers + compact number fields), so a bedroom set
  reads cleanly instead of as a flat list of nine fields. Everything else
  renders in the plain "Xususiyatlar" card. **Warranty is NOT an attribute** —
  it's the hard-coded `warrantyController` in `LogisticsSection` (→ typed
  `products.warranty_months`); don't reintroduce a `warranty_months` attribute
  or it shows twice.
- **Controller sync.** `name` / `description` are backed by free-standing
  `TextEditingController`s that don't auto-update from state, so
  `_runAiFill` writes them back from cubit state after applying.
- **Graceful degrade.** The endpoint always returns 200; on
  `available:false` (AI off / failed) the form shows a soft snackbar and the
  seller fills manually. `generateFromImages()` never throws; an upload
  failure is the only thing surfaced (the seller hits it again at save time).
- **Three outcomes.** `generateFromImages()` returns
  `(available, sameProduct)`; `_runAiFill` picks one of three snackbars:
  success, a "couldn't read" soft failure (`!available`), or a "these look
  like different products — add each separately" warning (`!sameProduct`,
  still filled from the primary photo). The cubit doesn't branch on
  `sameProduct` — it rides through `AiProductSuggestion` to the UI.
- **Image cap.** `_maxAiImages = 4` — the cubit trims before sending so a
  tariff that allows >4 photos doesn't 422 the backend. The form keeps all
  photos; only the AI call is trimmed.
- `isAiBusy` drives the button spinner and blocks re-tap / the add-photo tile.
- This seller flow uses seller-local styling tokens (`kInk`, `AppFonts.seller`),
  but its copy **is localized** (uz/ru/en) under the `add_product` translation
  domain — `tr('add_product.*')` — like the rest of the app (localized
  2026-06-24). Keep any NEW user-facing string in `tr()`; the seller-local
  tokens are for colour/font only and are not a reason to hardcode text. The
  **dynamic category attribute labels / option values stay backend-driven**
  (rendered from the model, localized server-side via Accept-Language) — never
  wrap those in `tr()`.

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

### Backend (woody_backend)

The only backend is **woody_backend** — a FastAPI service at `api.woody.uz`
(routes mount under `/api/v1`; `WoodyApiClient` adds the prefix). It owns
auth, the catalog, orders, per-order chat, the seller surfaces, and
presigned R2 uploads. The Flutter side speaks only REST + the Woody
WebSocket realtime feed (`wss://api.woody.uz/api/v1/realtime/ws`) — there is
no direct DB access, no RLS, and no Supabase anywhere in this repo.

- **Schema lives elsewhere** — DB schema + migrations are Alembic, in the
  `woody_backend` repo, not here. This repo never writes SQL.
- **Uploads** — every byte push (product images, chat attachments, KYC docs,
  tariff receipts) goes through `R2UploadClient` → `POST /storage/upload-url`
  (presigned PUT) with the right `R2Bucket`.
- **Realtime degrades gracefully** — order/notification updates fall back to
  refresh-on-open + FCM foreground push until the backend publishes the
  matching realtime events.

### Chat (per-order)

One row in `chats` per `order_id` (UNIQUE constraint). Customer
lazy-creates the row on first message; seller can never spawn a chat.
Chat stays OPEN forever, even after order delivered/cancelled — the
`ChatStatusBanner` reflects current order status with copy + a "Leave
a review" CTA on delivered orders (customer side only). Realtime: new
messages arrive over the Woody WebSocket feed; the list view refreshes on
reconnect / re-open.

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
- Don't reintroduce Supabase — it was fully removed; the only backend is
  woody_backend (REST + R2 + WebSocket). No `supabase_flutter` dependency.
- Don't hardcode the seller Oferta body as the live source of truth — fetch
  `/legal/oferta?lang=` and interpolate placeholders; keep Inter TTFs for PDFs
  (Cyrillic). Don't replace Inter with a Latin-only PDF font.
- Don't commit `env/prod.json`, `key.properties`, `*.jks`,
  `build/symbols/`, `google-services.json` if it contains secrets

## Recent feature work (Spring 2026)

This brain captures the state after a multi-session redesign:

- **Dynamic multi-lingual seller Oferta (2026-08)** — backend `legal_documents`
  (uz/ru/en) + `GET /legal/oferta?lang=`; scroll-to-accept onboarding step;
  `contract_accepted_at` / `contract_version` persistence; A4 PDF share with
  Zettacode requisites + localized footer labels (Inter fonts). See § Seller
  Oferta above and workspace TZ v1.2.
- **Internal escrow + withdrawals, hybrid push prefs, analytics privacy (2026-08)** —
  online settlement credits `order_income` on `delivered` (not Payme Safe/Split);
  Settings toggles for promo/order push and **"Foydalanish statistikasi"** (Analytics +
  Crashlytics). See § Platform money, push & privacy above and workspace TZ v1.1.
- **Full Supabase → woody_backend migration** — `supabase_flutter` dropped
  entirely; every repository, auth, realtime, storage and the seller
  add-product / tariff / services / attributes flows now run against the
  Woody REST API + R2 + WebSocket. `grep -i supabase lib/` is zero.
- **AI "fill from photos"** in the seller add-product form — the
  `MediaSection` shows an "AI bilan to'ldirish" CTA once a photo is added;
  `AddProductCubit.generateFromImages()` uploads the photos, calls
  `POST /seller/products/ai-suggest`, and applies the returned name /
  description / category / colours / attributes. AI never auto-saves — the
  seller reviews and taps save. See §AI product authoring.
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
- Auth flow (phone → OTP → profile) is a full-screen modal route opened
  by `showAuthScreen()` (was a bottom sheet); closed via the header X or
  system back. Dark mode via `AuthTokens`; steps under `auth/sheets/`,
  logic in `AuthSheetController`. File is still `auth/auth_bottom_sheet.dart`.
- OTP autofill: iOS uses QuickType (`AutofillHints.oneTimeCode` inside an
  `AutofillGroup` in `otp_step.dart`); Android picks its `smart_auth` API by
  the running build's app-signature hash in
  `AuthSheetController._listenForSmsCode` (started when the OTP is requested —
  fills `otpCtrl` → auto-submits). Play-installed builds match the Play App
  Signing hash (`_playAppSignatureHash = 'mH1HhnJpGqi'`, which the Eskiz OTP
  templates end with) and use **SMS Retriever** — zero-tap, no dialog;
  debug / sideloaded-release builds carry a different signing key (debug =
  `yaRHQKhlEo9`) so they fall back to the hash-free **SMS User Consent**
  dialog. The OTP SMS **follows the active UI language** (uz/ru/en):
  `AuthRepository.requestOtp(phone, appLanguage:)` maps the UI language via
  `_smsLocale` (uz→uz, ru→ru, anything else / unknown → **en**, never uz) and
  passes it as `_api.post(..., localeOverride: …)`; the interceptor lets that
  per-request `localeOverride` (carried in the request `extra`) win over the
  live `Accept-Language`. `AuthSheetController.sendOtp` supplies the UI language
  from `sl<AppLocaleController>().value.languageCode`. Each of the three Eskiz
  templates (uz/ru/en) is a single ≤140-byte segment ending with our app
  signature hash, so SMS Retriever zero-tap still works in every language. All
  three templates **must stay approved on the Eskiz dashboard** — a not-yet-
  moderated template makes `/auth/otp/request` fail for that language (Eskiz
  400 → `sms_unavailable`). Backend error codes are translated client-side
  (`auth_error_messages.dart`), independent of the SMS language.

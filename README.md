# Woody — Two-Sided Furniture Marketplace (Flutter)

> Internal codename: **Woody** (`pubspec.yaml` → `name: woody_app`). Brand: **Woody** — an Uzbekistan-focused furniture (`mebel`) marketplace. App id `com.mebellar.app`, version `1.0.36+36`.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-^3.11.5-0175C2?logo=dart)](https://dart.dev)
[![Backend](https://img.shields.io/badge/Backend-woody__backend%20(FastAPI)-009688)](https://api.woody.uz)

> **Authoritative docs:** the operational brain is [`CLAUDE.md`](./CLAUDE.md); the platform master spec is [`doc/TZ.md`](./doc/TZ.md) (v1.1+). [`woody_mobile_tz.md`](./woody_mobile_tz.md) is a redirect stub. Deep-dive guides live in [`docs/`](./docs/). This README is a high-level orientation.

### Where this app sits in the Woody / Mebellar ecosystem

```
┌──────────────────────────┐      REST  /api/v1            ┌──────────────────────────┐
│  mebellar_app (THIS)     │  ──────────────────────────▶  │  woody_backend (FastAPI)  │
│  Flutter — customer +    │  ◀──────────────────────────  │  api.woody.uz             │
│  seller in one binary    │      WebSocket realtime        │  Postgres · R2 · Alembic  │
└──────────────────────────┘                               └────────────┬─────────────┘
                                                                          │  shares the same API
                                              ┌───────────────────────────┴───────────────┐
                                              │  woody_admin (Next.js) — moderation panel   │
                                              └─────────────────────────────────────────────┘
```

The Flutter app is a **pure REST + WebSocket client**. It owns no database and runs no migrations — the schema and all Alembic migrations live in the separate **`woody_backend`** repo. The Next.js **`woody_admin`** panel talks to the same backend for moderation.

---

## 1. What is Woody?

Woody is a **two-sided B2B2C marketplace for furniture**, targeting the Uzbekistan market. It ships as **one Flutter binary that hosts two independent product surfaces**:

- a **customer storefront** — browse catalog, search, cart, checkout, track orders, per-order chat;
- a **seller back-office** — onboard a shop, manage products, fulfill orders, subscribe to tariff plans, manage the wallet.

A single user identity can be both a buyer and a seller. The app switches between the two surfaces **at runtime** — no re-install — by swapping the DI scope, theme, router, and navigation shell and rebirthing the widget tree.

### Business pillars

| Pillar | Description |
| --- | --- |
| **Catalog discovery** | Multi-level categories, search, filters, banners, premium home feed (infinite scroll + sort). |
| **Two-sided onboarding** | All users sign in by **phone + SMS OTP**; sellers run a multi-step onboarding + KYC verification flow. |
| **Order fulfillment** | Customers place orders with **cash (COD)** or **online Payme/Click** (both LIVE). Online funds use Woody **internal escrow** (not Payme Safe/Split); sellers fulfill; status via **WebSocket** + FCM. |
| **Monetization** | Tariff subscription + commission. On `delivered`, online orders credit seller `order_income` (net of commission); withdrawals via admin-approved `wallet_withdrawals`. Soft-freeze on debt. |
| **Engagement** | FCM push notifications (per-chat collapse + order/fee events) drive return visits. |

---

## 2. System Requirements & Tech Stack

### Build / runtime requirements

| Requirement | Value |
| --- | --- |
| Flutter / Dart | Dart SDK `^3.11.5` (Flutter 3.x) |
| Android | **`minSdk` 26** (`android/app/build.gradle.kts`). The `flutter_launcher_icons` `min_sdk_android: 21` in `pubspec.yaml` is icon-tooling only — the real gate is 26. `applicationId` / `namespace` `com.mebellar.app`. |
| iOS | Xcode 15+. **Flutter Swift Package Manager (SPM) must be DISABLED** (else Firebase module redefinition). CocoaPods `Podfile.lock` pinned to **Firebase 11.15.0** — keep aligned. |
| OTA tooling | Shorebird CLI (`shorebird login` on the build machine). App id `c1639a0d-e4a4-4606-bf14-4b4195fa061e`. |

### Core libraries (from `pubspec.yaml`)

| Layer | Package(s) · version |
| --- | --- |
| Framework / language | **Flutter** · **Dart** SDK `^3.11.5` |
| State management | `flutter_bloc` `^9.0.0`, `bloc_concurrency` `^0.3.0`, `equatable` `^2.0.8` |
| Dependency injection | `get_it` `^8.0.0` — scoped (root + per-mode) |
| Routing | `go_router` `^14.6.0` (customer: GoRouter; seller: StatefulShellRoute) |
| Networking | `dio` `^5.7.0`, `http` `^1.2.2`, `web_socket_channel` `^3.0.1` |
| Firebase | `firebase_core` `^3.6.0`, `firebase_messaging` `^15.1.3`, `firebase_crashlytics` `^4.1.5`, `firebase_analytics` `^11.3.5`, `flutter_local_notifications` `^18.0.1` |
| Local storage | `hive` `^2.2.3` / `hive_flutter` `^1.1.0`, `flutter_secure_storage` `^9.2.0`, `shared_preferences` `^2.3.0` |
| Runtime restart | `flutter_phoenix` `^1.1.1` (powers the mode switch) |
| Maps & location | `yandex_mapkit` `^4.2.1`, `geolocator` `^14.0.2`, `permission_handler` `^12.0.1` |
| AR — inline viewer | `model_viewer_plus` `^1.9.3`, `webview_flutter` `^4.13.0`, `gal` `^2.3.2` |
| AR — native multi-object | `ar_flutter_plugin_plus` `^1.1.3` (ARCore/ARKit), `vector_math` `^2.2.0` |
| AR — scan capture | `camera` `^0.11.0` (locked 3-photo scan) |
| Media | `image_picker` `^1.1.2`, `image` `^4.3.0`, `flutter_image_compress` `^2.3.0`, `cached_network_image` `^3.4.1` |
| Support-chat voice | `record` `^5.1.2`, `just_audio` `^0.9.42` |
| Connectivity | `connectivity_plus` `^6.1.0`, `internet_connection_checker_plus` `^2.5.2` |
| Auth helpers | `smart_auth` `^3.2.0` (Android SMS autofill), `mask_text_input_formatter` `^2.9.0` |
| Analytics (Meta) | `facebook_app_events` `^0.30.1`, `app_tracking_transparency` `^2.0.6` |
| App lifecycle | `in_app_review` `^2.0.10`, `package_info_plus` `^8.1.0`, `url_launcher` `^6.3.1`, `share_plus` `^12.0.2` |
| UI / charts | `fl_chart` `^0.69.0`, `lottie` `^3.1.2`, `shimmer` `^3.0.0`, `flutter_svg` `^2.0.10`, `flutter_staggered_grid_view` `^0.7.0`, `smooth_page_indicator` `^1.2.0`, `iconsax_flutter` `^1.0.0`, `font_awesome_flutter` `^11.0.0` |
| Localization / time | `intl` `^0.20.2`, `clock` `^1.1.1` |
| Logging | custom `AppLogger` → Crashlytics |

**Dev tooling:** `flutter_lints` `^6.0.0`, `bloc_test` `^10.0.0`, `mocktail` `^1.0.4`, `flutter_native_splash` `^2.4.4`, `flutter_launcher_icons` `^0.14.4`.

> A `dependency_override` pins `record_linux 1.3.1` (resolver-only — Linux is not a build target).

### External services

| Service | Used for | Direct or via backend |
| --- | --- | --- |
| **woody_backend** (FastAPI, `api.woody.uz`) | The ONLY backend — auth, catalog, orders, chat, seller surfaces, uploads, AI, payments | REST `/api/v1` + WebSocket `wss://api.woody.uz/api/v1/realtime/ws` |
| Cloudflare R2 | Object storage (images, docs, AR scans) | Direct presigned PUT via `POST /storage/upload-url` |
| Firebase | FCM push, Crashlytics, Analytics (**no Firebase Auth**) | Direct (needs `google-services.json` / `GoogleService-Info.plist` + APNs + `firebase_options.dart`) |
| Yandex MapKit / Geocoder | Checkout address picker | Direct (needs `YANDEX_GEOCODER_API_KEY`) |
| Eskiz SMS | OTP delivery (3 localized templates) | Via backend |
| Meshy | Photo-to-3D AR pipeline | Via backend (`MESHY_API_KEY` is backend-side) |
| Azure / Foundry vision | AI designer + product autofill | Via backend (key is backend-side) |
| Payme / Click | Payment apps (deep-link hand-off) | Client deep-link; settlement webhooks live in the backend |
| Meta App Events | Marketing attribution (consent + iOS ATT gated) | Direct (`facebook_app_events`) |
| CBU exchange-rate feed | Seller pricing | Direct (`exchange_rate_service.dart`) |

> Fonts (`Inter`, `Manrope`, `PlayfairDisplay`, `PlusJakartaSans`) are bundled as native TTF assets — the `google_fonts` package is **not** used.

---

## 3. Architecture at a Glance

A disciplined three-layer architecture — **UI → Logic → Data** — with a runtime mode switch on top.

```
   UI (Screens / Widgets)
        │   reads state · dispatches events
        ▼
   Logic (BLoC / Cubit)
        │   awaits
        ▼
   Data (abstract Repository interface)
        ├── Woody*Repository   ← REST/WebSocket impl over WoodyApiClient
        └── in-memory mock     ← used by tests
```

### Patterns a new developer must know

| Pattern | File(s) | What it does |
| --- | --- | --- |
| **`Woody*Repository` over `WoodyApiClient`** | `lib/shared/repositories/`, `lib/core/network/` | Repositories are abstract interfaces with a single Woody REST/WebSocket implementation + an in-memory mock for tests. **There is no raw `Dio`/`Remote*` layer.** A new data need = a new backend endpoint first, then a repo here. |
| **Scoped DI (`get_it`)** | `lib/core/di/` | A **root scope** holds cross-cutting singletons (auth, theme, notifications, Hive boxes); a **mode scope** (`customer` / `seller`) holds surface-specific blocs and is swapped on every mode change. Registration order matters (`service_locator.dart`). |
| **Runtime mode switch** | `AppModeCubit` + `flutter_phoenix` | A new `AppMode` triggers scope swap → `Phoenix.rebirth()`. A boot guard demotes to customer mode if the cached seller-approval flag is false. |
| **Hybrid local + backend cart/favorites** | `lib/shared/repositories/hybrid_*` | Guests use a local Hive cart/favorites; on login the local state **merges (union)** into the server. The login gate is only at checkout. |
| **Hand-rolled i18n** | `lib/core/i18n/` | Pure-Dart translation maps; a debug-only guard fails boot if `ru`/`en` drift below the `uz` baseline. No `.arb`, no `easy_localization`. |

Deeper invariants live in [`.claude/rules/`](./.claude/rules/) (architecture, theming, i18n, backend-api, testing) and [`CLAUDE.md`](./CLAUDE.md).

### Bootstrap (`lib/main.dart`)

Everything runs inside `runZonedGuarded`:

```
WidgetsFlutterBinding
  → AppConfig.assertConfigured()        # fail-fast on missing required env
  → assertTranslationsComplete()        # debug-only i18n parity guard
  → Firebase.initializeApp
  → Crashlytics wiring                  # FlutterError.onError, PlatformDispatcher.onError,
  →                                     #   CrashlyticsTalkerObserver; collection only when !kDebugMode
  → Hive.open
  → DI setup (service_locator)
  → Phoenix-wrapped mode router
```

### DI module order (matters)

`lib/core/di/service_locator.dart` registers in this order — `registerCoreModule` (Hive boxes, `TokenStore`, `WoodyApiClient`, `R2UploadClient`, `ThemeCubit`, `AppModeCubit`, `WoodyRealtimeService`) → `registerAuthModule` → `registerCatalogModule` (data sources, `AnalyticsService`, root-scoped `NotificationsCubit`, AI designer, payments) → `registerSellerModule`. `AppModeCubit` resolves analytics through a `() => sl<AnalyticsService>()` **lookup closure** because it is built before the catalog module registers analytics.

### Networking

`WoodyApiClient` (`lib/core/network/`) is a Dio wrapper on `AppConfig.woodyApiUrl + /api/v1`. The `_AuthInterceptor` injects the Bearer token and performs **single-flight `/auth/refresh` + replay on 401**. A per-request `localeOverride` (carried in `request.extra`) wins over the live `Accept-Language` so localized OTP SMS goes out in the right language. `NetworkLoggerInterceptor` is attached to **all** Dio clients (Woody API, R2 upload, CBU feed) but is **debug-only** (`kDebugMode`-gated — never logs in release). `TokenStore` (flutter_secure_storage) exposes a `changes` stream that starts/stops realtime. Uploads go through `R2UploadClient` (two-step `POST /storage/upload-url` presigned PUT) keyed by the `R2Bucket` enum (`product-images`, `shop-assets`, `chat-attachments`, `seller-documents`, `verification-docs`, `payment-receipts`, `user-avatars`, `product-ar-scans`, `ai-chat-images`).

### Realtime

`WoodyRealtimeService` holds one WebSocket to `wss://api.woody.uz/api/v1/realtime/ws`, routes per-user by `type`, and reconnects with exponential backoff. Events: `notification_created`, `chat_message`, `chat_read_receipt`, `order_status_changed`. It **degrades gracefully** to refresh-on-open + FCM foreground push when the socket is down.

### Multi-part AR structure (Product → Parts mapping)

See [`docs/ar.md`](./docs/ar.md) for the full guide. In brief:

- A **`Product`** carries `arParts: List<ArPart>` (`lib/shared/models/ar_part.dart`). Each `ArPart` is one **independently generated 3D model** — `{ id, partKey ('bed'|'wardrobe'|'single'|…), label, arStatus (none|processing|approved|failed), arModelUrl, usdzUrl, arModelBytes, isArVisible, freeScanUsed, arErrorReason, widthCm/heightCm/depthCm }`. A single-piece product is one `single` part.
- **Two JSON shapes:** `ArPart.fromCustomerJson` (buyer detail — approved + visible only) and `ArPart.fromSellerJson` (`GET /seller/products/{id}/ar-parts` — full per-part state).
- **Monetization is per-part:** 1 free scan, then an AR token from the seller's token wallet.
- **Client viewer routing** (`lib/customer/features/product_list/widgets/ar_entry_points.dart` gates entry):
  - single-part / inline → **`BuyerArViewerScreen`** (`model_viewer_plus`, part toggle via `ArViewerCubit`, `GlbCacheService` `file://` cache, watermarked save-to-gallery);
  - multi-part garnitur/set (`Product.hasMultiPartAr` — `arParts.where(hasModel).length >= 2`) → **`SetArViewerScreen`** — true native ARCore/ARKit via `ar_flutter_plugin_plus`;
  - non-AR devices → **`fallback_2d_camera_screen.dart`** (2D sticker overlay).
- **Capability probe:** `ArSupport` (`lib/shared/ar/ar_support.dart`) via `MethodChannel com.mebellar.app/ar` → Android `PackageManager.FEATURE_CAMERA_AR`; iOS returns true (AR Quick Look). `ar_flutter_plugin_plus` is a **native** dep — native multi-object AR ships only in a **full store release**, never a Shorebird patch.

### Payment architecture (deep-link hand-off + recovery)

See [`docs/payments.md`](./docs/payments.md) for the full guide. In brief:

- The app does **NOT** store cards or charge. There are **no Payme/Click webhooks or JSON-RPC** in this repo — those (Payme Merchant `POST /webhooks/payme`, 6 RPC + fiscalization) live in **`woody_backend`**.
- **Flow:** `PaymentProvider {payme, click}` → `PaymentRepository.checkoutUrl()` POSTs `/orders/{id}/pay/{provider}`, gets back `CheckoutLink {provider, checkout_url, amount, reference}`, then `launchUrl(LaunchMode.externalApplication)` hands off to the Payme/Click app. Errors: 404 (not your order) / 409 (already paid) / 503 (provider unconfigured).
- **Checkout** (`CheckoutCubit`, `CheckoutPayment {cash, payme, click}`) fans the cart out into **one order per shop**; multi-shop carts can only link the FIRST order (documented limitation). The cart is cleared **before** minting the link so a failed hand-off can't double-checkout; a failed mint still counts as success (order placed unpaid — confirmation is a webhook concern).
- **Recovery** (`lib/shared/payments/`, root-scoped): on hand-off `PendingPaymentService.mark` writes a `PendingPayment` to `PendingPaymentStore` (**SharedPreferences**, survives OS kill). `PendingPaymentKind {order, arTokens, subscription, walletDeposit}`; `PaymentRecoveryGate` resumes on return (resume poll + cold-start probe). `WoodyPaymentStatusGateway` routes each kind to its status endpoint and maps to `PaymentOutcome {paid, pending, unknown}` — `unknown` is treated like `pending`, never claims success. The same rails power seller **tariff upgrades**, **wallet deposits**, and **AR-token top-ups**.

---

## 4. Repository Layout

```
mebellar_app/
├── android/ · ios/            # native projects (incl. Firebase/FCM config)
├── assets/                    # bundled fonts + brand logo
├── env/
│   ├── example.json           # committed template (blank secrets)
│   └── prod.json              # the single working env file — GITIGNORED (see §6)
├── lib/
│   ├── main.dart              # bootstrap → Firebase → DI → Phoenix mode router
│   ├── config/                # AppConfig + AppMode enum
│   ├── core/                  # DI, network (WoodyApiClient), i18n, theme, notifications, logging…
│   ├── shared/                # cross-mode models, repositories (+ mocks), chat module, widgets
│   ├── auth/                  # phone + OTP login/verify bottom-sheet flow
│   ├── customer/              # customer surface — features/, services/, widgets/
│   └── seller/                # seller surface — features/, services/, widgets/
├── test/                      # mirrors lib/ exactly (a test sits at its subject's mirrored path)
│   └── goldens/               # golden baseline PNGs — kept flat, not mirrored
├── integration_test/          # end-to-end happy-path test (also drives showcase screenshots)
└── store/                     # App Store / Play listings + privacy policy
```

> **Test layout convention.** The `test/` tree is a strict mirror of `lib/`. The only exception is `test/goldens/`. New tests must follow this — do not add files to the `test/` root.

---

## 5. Setup

### Prerequisites

- Flutter `3.11+` / Dart `3.11+` (`flutter --version`)
- Android SDK with **`minSdk` 26** and/or Xcode 15+ (iOS: keep Flutter SPM disabled + `Podfile.lock` on Firebase 11.15.0)
- A `env/prod.json` (copy from `env/example.json` and fill the keys below) and the Firebase config for FCM
- Shorebird CLI (`shorebird login`) if you intend to cut OTA releases/patches

### Clone & install

```bash
git clone <repo-url> mebellar_app
cd mebellar_app
flutter pub get
cp env/example.json env/prod.json   # then fill in the keys
```

---

## 6. Environment Configuration

All runtime config is injected at build time via `--dart-define-from-file`. **No secret has a compiled-in default** — `AppConfig.assertConfigured()` runs at the top of `main()` and **aborts loudly** if a required key is missing.

The project uses **one canonical environment file: `env/prod.json`** (gitignored). It drives every local run, build, and test seed.

There is no `.env` file — Flutter reads build-time constants via `--dart-define-from-file`. The contract is `env/prod.json` (gitignored), seeded from `env/example.json`. Full table (see [`docs/env-config.md`](./docs/env-config.md)):

| Key | Required | Read via | Purpose · example |
| --- | --- | --- | --- |
| `WOODY_API_URL` | ✅ | `String.fromEnvironment` | Backend base URL; `WoodyApiClient` adds `/api/v1`. `https://api.woody.uz` |
| `YANDEX_GEOCODER_API_KEY` | ✅ | `String.fromEnvironment` | Checkout map address picker. Restrict by package/referrer. `yandex-geocoder-dummy-key-0000000000000000` |
| `APP_ENV` | — | `String.fromEnvironment` | `dev` (default) or `prod`; sets `AppConfig.isProd` + Crashlytics `environment` key. `prod` |
| `PAYME_MERCHANT_ID` | — | not read by the app (env file only) | Vestigial Payme merchant id carried in the env file; the live checkout deep-link is minted entirely by the backend (`POST /orders/{id}/pay/{provider}`). `0000000000000000000000aa` |
| `PAYME_API_URL` | — | not read by the app (env file only) | Vestigial Payme base; unused by the client. `https://checkout.test.paycom.uz` |
| `PAYME_MOCK` | — | not read by the app (env file only) | Vestigial mock flag; unused by the client. `true` |
| `SELLER_USES_GO_ROUTER` | — | `bool.fromEnvironment` | Route seller mode through go_router StatefulShellRoute (default `true`); flip off for legacy imperative nav. `true` |
| `SCREENSHOT_MODE` | — | `bool.fromEnvironment` | Enables the integration-test showcase/screenshot pipeline (`lib/config/screenshot_mode.dart`). `false` |

> The `PAYME_*` keys live in `env/prod.json` but are **not read anywhere in the app** — not via `String.fromEnvironment` in `lib/config`, and not by the Android/iOS native code. They are vestigial config left over from the removed saved-cards era; the real payment flow gets its checkout URL entirely from the backend (`POST /orders/{id}/pay/{provider}`). They are mirrored into `env/example.json` only so a fresh `cp env/example.json env/prod.json` matches the on-disk key set.

> ⚠️ **Secrets hygiene.** `env/prod.json` is **gitignored** — never commit it, signing keystores (`*.jks`, `key.properties`), `google-services.json` if it carries secrets, or a Firebase **Admin SDK** service-account key.

---

## 7. Running, Building & Testing

The env file is **mandatory** — without it `AppConfig.assertConfigured()` crashes before the splash paints.

```bash
# Run the app (device or emulator)
flutter run --dart-define-from-file=env/prod.json

# Static analysis — must report 0 issues
flutter analyze            # or: dart analyze lib/

# Tests — 122 test files, ~767 test/testWidgets/blocTest cases (incl. 5 golden baselines)
flutter test                              # CI excludes goldens: flutter test --exclude-tags golden
flutter test --tags golden                # run only the golden baselines
flutter test --tags golden --update-goldens   # regenerate golden PNGs locally
flutter test --coverage                   # lcov report
flutter test integration_test             # E2E happy path (needs a device; also drives showcase screenshots)

# Formatting
dart format lib/ test/
```

> **No client migrations.** This is a Flutter client with no database — there is no `woody migrate` / Alembic here. DB schema + migrations live in `woody_backend` (run there). The app's "version ledger" equivalent is the Shorebird release ledger ([`tools/shorebird/releases.md`](./tools/shorebird/releases.md)).

### Release builds

```bash
# Android App Bundle (preferred wrapper: ./tools/build_release.sh)
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json

# Quick APK for sideloading
flutter build apk --release --dart-define-from-file=env/prod.json

# iOS IPA — requires Flutter SPM DISABLED + Podfile.lock pinned to Firebase 11.15.0
flutter build ipa --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json
```

> Bump `version` in `pubspec.yaml` (`+N`) before any Play Console / App Store push.

### Shorebird OTA (code push)

Shorebird hot-fixes shipped builds **without store review** — but **only Dart code rides a patch**. Native (`android/`, `ios/`), bundled `assets/`, `pubspec` dependency, or Flutter-version changes all require a **full release**. `tools/shorebird.sh` mirrors the build/env/signing preflight:

```bash
./tools/shorebird.sh check                 # "what changed since the last release — patch-safe?"
./tools/shorebird.sh release android|ios   # patchable store build + ledger entry
./tools/shorebird.sh patch android|ios     # preflight-gated Dart-only patch to the live release
./tools/shorebird.sh log                   # release history
```

- A patchable store build MUST come from `shorebird release`, not `flutter build` / `build_release.sh`.
- `patch` runs `check` first and aborts on a native/asset/Flutter blocker (`--force` bypasses, not recommended).
- The ledger ([`tools/shorebird/releases.md`](./tools/shorebird/releases.md)) is append-only history (latest `1.0.36+36` — see ledger for SHA). `app_id` `c1639a0d-e4a4-4606-bf14-4b4195fa061e`.

See [`docs/release-shorebird.md`](./docs/release-shorebird.md) for the full OTA rules and iOS SPM / Firebase 11.15.0 caveats.

---

## 8. Companion Documentation

| File | Scope |
| --- | --- |
| [`docs/architecture.md`](./docs/architecture.md) | Layers, DI module order, mode switch, routing, networking, realtime. |
| [`docs/payments.md`](./docs/payments.md) | Deep-link hand-off + recovery gate, payment kinds / status endpoints, multi-shop limitation. |
| [`docs/ar.md`](./docs/ar.md) | Product → ArPart mapping, viewer routing, capability gate, per-part token monetization. |
| [`docs/ai-designer.md`](./docs/ai-designer.md) | AI Interior Designer chat (RAG, FAB, root-scope cubit, privacy). |
| [`docs/env-config.md`](./docs/env-config.md) | Full build-time config key table. |
| [`docs/release-shorebird.md`](./docs/release-shorebird.md) | OTA rules + ledger + iOS SPM / Firebase caveats. |
| [`CLAUDE.md`](./CLAUDE.md) | **Start here** — operational brain: architecture, conventions, gotchas, do-not-break invariants. |
| [`.claude/rules/`](./.claude/rules/) | Distilled invariant cards (architecture, theming, i18n, backend-api, testing). |
| [`woody_mobile_tz.md`](./woody_mobile_tz.md) | Redirect stub → workspace [`doc/TZ.md`](./doc/TZ.md). |
| [`doc/TZ.md`](./doc/TZ.md) | Platform **Master Technical Specification** (single source of truth, v1.1+). |
| [`doc/_archive/workspace_audit_2026_06_18.md`](./doc/_archive/workspace_audit_2026_06_18.md) | 2026-06-18 code-health audit (incl. the mobile findings) — archived, all resolved. |
| [`store/`](./store/) | App Store / Play listings + privacy policy. |

---

## 9. Maintainer

- Lead developer: **Eldor Turg'unov** (`Turgunoff`).
- Internal package name: `woody_app`; app id: `com.mebellar.app`.
- The project is private; no open-source license has been selected.

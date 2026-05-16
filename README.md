# MEBELLAR APP — Two-Sided Furniture Marketplace (Flutter)

> Internal codename: **Woody** (`pubspec.yaml` → `name: woody_app`). Brand: **Mebellar** — Uzbekistan-focused mebel (furniture) marketplace.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-^3.11.5-0175C2?logo=dart)](https://dart.dev)
[![Backend](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase)](https://supabase.com)
[![Status](https://img.shields.io/badge/Status-Pre--release%20MVP-orange)]()

---

## 1. Purpose & Business Logic

Mebellar is a **two-sided B2C/C2C marketplace** for furniture (`mebel`) targeting the Uzbekistan market. The app is a single Flutter binary that hosts **two independent product surfaces** — a buyer-facing storefront and a seller-facing back-office — switchable at runtime without re-installing.

### Business pillars

| Pillar | Description |
| --- | --- |
| **Catalog discovery** | Multi-level categories, search, banners, premium home blocks (`customer/features/home`, `catalog`, `search`). |
| **Two-sided onboarding** | Buyers sign up with email/password; sellers go through a separate onboarding + KYC verification flow (`seller/features/onboarding`, `verification`). |
| **Order fulfillment** | Customers place orders, sellers fulfill them; both sides see realtime status changes via Supabase Realtime CDC (`customer/features/orders`, `seller/features/orders`). |
| **Monetization** | Sellers subscribe to tariff plans (`seller/features/tariff`), upgrade via in-app P2P payment flow. |
| **Engagement** | Cross-mode push notifications (FCM topics for broadcasts, per-token personal pings) drive return visits. |

### Why a single binary instead of two apps?

- One Flutter codebase, one Supabase project, one auth identity per user.
- A user can be both a buyer and a seller — the runtime mode switch (`AppModeCubit` + `flutter_phoenix`) keeps the same Supabase session while swapping the entire DI scope, theme, router, and bottom-nav.
- Reduces ASO/store-listing duplication: ships as `uz.mebellar.app` / `com.mebellar.app` on both platforms.

---

## 2. Customer & Seller Modules

The two product surfaces live side-by-side under `lib/customer/` and `lib/seller/`. They are **never both active at the same time** — the active `AppMode` (persisted in Hive under key `app_mode`) chooses which `MaterialApp` is mounted.

### Customer module — `lib/customer/`

| Feature | Path | Status |
| --- | --- | --- |
| Home (banners, premium blocks) | `features/home/` | Live (Supabase + mocks) |
| Catalog / categories | `features/catalog/`, `features/categories/` | Live |
| Product list (per category) | `features/product_list/` | Live (Supabase) |
| Product detail | `features/product_detail/` | Live |
| Search | `features/search/` | Live |
| Favorites | `features/favorites/` | Hybrid (Hive + Supabase) |
| Cart | `features/cart/` | Hybrid (Hive + Supabase) |
| Checkout (incl. Yandex map address picker) | `features/checkout/` | Live |
| Orders + tracking | `features/orders/` | Live (Supabase Realtime) |
| Profile + addresses | `features/profile/` | Live |
| Notifications inbox | `features/notifications/` | Live (Supabase Realtime) |
| Onboarding tutorial | `features/tutorial/` | Gated via Hive flag |
| Broadcast news | `features/broadcasts/` | Read-state in Hive |

**Customer shell:** `customer/customer_app.dart` (`CustomerApp` — `MaterialApp.router` + `GoRouter`) with `CustomerHomeShell` and a `GlassBottomNav`.

### Seller module — `lib/seller/`

| Feature | Path | Status |
| --- | --- | --- |
| Onboarding (multi-step) | `features/onboarding/` | Live |
| KYC verification (passport upload) | `features/verification/` | Live |
| Dashboard (metrics) | `features/dashboard/` | Live (Supabase) |
| Product CRUD (6-step form) | `features/products/` | Live |
| Orders fulfillment | `features/orders/` | Mock-backed |
| Shop settings (hours, services) | `features/settings/` | Mock-backed |
| Tariff upgrade (P2P pay) | `features/tariff/` | Mock + live plan catalog |
| Analytics | `features/analytics/` | Mock |
| Reviews | `features/reviews/` | Mock |
| Notifications inbox | `features/notifications/` | Live (Supabase Realtime) |

**Seller shell:** `seller/seller_app.dart` (`SellerApp` — traditional `MaterialApp` + `onGenerateRoute`) with `SellerHomeShell` and `SellerBottomNav`.

### How they interact

```
                    ┌─────────────────────┐
                    │  AppModeCubit       │  ← persists in Hive
                    │  (root-scoped)      │
                    └──────────┬──────────┘
                               │ emits new AppMode
                               ▼
              ┌────────────────────────────────┐
              │  Phoenix-wrapped BlocListener  │
              └──────────┬─────────────────────┘
                         │ popScope() + initModeScope(mode)
                         │ + Phoenix.rebirth(context)
                         ▼
        ┌───────────────────────────────────────────┐
        │  _ModeRouter (rebuilt under new key)      │
        │  switch (getInitialMode()) {              │
        │    AppMode.customer => CustomerApp(),     │
        │    AppMode.seller   => SellerApp(),       │
        │  }                                        │
        └───────────────────────────────────────────┘
```

Cross-cutting state survives the swap:

- `AuthCubit` (Supabase session) — root-scoped, same user identity in both modes.
- `NotificationsCubit` — root-scoped intentionally, so a Realtime push that arrives during a mode swap is not lost.
- Hive boxes (`settings`, `cache`, `pendingRoute`, `onboardingDraft`, `favorites`, `cart`, `newsReads`) — opened in root scope.

A push notification tapped in the wrong mode stashes its route in `pending_route` Hive box, the mode flips, Phoenix rebirths, then the new shell consumes the pending route on the first frame.

---

## 3. Tech Stack

### Runtime

| Layer | Choice | Version |
| --- | --- | --- |
| Framework | Flutter | `^3.11.5` SDK constraint |
| Language | Dart | `^3.11.5` |
| Flutter channel (`.metadata`) | `stable` @ `cc0734ac71` | — |
| Min Android SDK | 21 | (Android 5.0+) |
| iOS bundle | `com.mebellar.app` | — |
| Android bundle | `uz.mebellar.app` / `com.mebellar.app` | — |

### Dependencies (from `pubspec.yaml`)

| Concern | Package | Version |
| --- | --- | --- |
| State management | `flutter_bloc` | `^9.0.0` |
| DI | `get_it` | `^8.0.0` |
| Value equality | `equatable` | `^2.0.7` |
| Routing (customer) | `go_router` | `^14.6.0` |
| HTTP | `dio` | `^5.7.0` |
| HTTP (secondary) | `http` | `^1.2.2` |
| Backend (auth, DB, Realtime, Storage) | `supabase_flutter` | `^2.8.0` |
| Firebase core | `firebase_core` | `^3.6.0` |
| Push messaging | `firebase_messaging` | `^15.1.3` |
| Local notifications (foreground display) | `flutter_local_notifications` | `^18.0.1` |
| Local storage | `hive` + `hive_flutter` | `^2.2.3` / `^1.1.0` |
| Secure storage | `flutter_secure_storage` | `^9.2.0` |
| Runtime restart | `flutter_phoenix` | `^1.1.1` |
| Localization helpers | `intl` | `^0.20.2` |
| Image cache | `cached_network_image` | `^3.4.1` |
| Image picker / compress / decode | `image_picker`, `flutter_image_compress`, `image` | `^1.1.2` / `^2.3.0` / `^4.3.0` |
| SVG | `flutter_svg` | `^2.0.10` |
| Loading shimmer | `shimmer` | `^3.0.0` |
| Icons | `iconsax_flutter` | `^1.0.0` |
| Masonry grid | `flutter_staggered_grid_view` | `^0.7.0` |
| Charts | `fl_chart` | `^0.69.0` |
| URL launcher | `url_launcher` | `^6.3.1` |
| Maps | `yandex_mapkit` | `^4.2.1` |
| Geolocation | `geolocator` | `^13.0.2` |
| Permissions | `permission_handler` | `^11.4.0` |
| Phone mask | `mask_text_input_formatter` | `^2.9.0` |
| Logging | `talker_flutter` | `^5.1.16` |
| Crash reporting | `sentry_flutter` | `^8.0.0` |
| Connectivity link | `connectivity_plus` | `^6.1.0` |
| Connectivity reachability | `internet_connection_checker_plus` | `^2.5.2` |

### Dev tooling

| Tool | Package |
| --- | --- |
| Linting | `flutter_lints ^6.0.0` |
| BLoC tests | `bloc_test ^10.0.0` |
| Mocks | `mocktail ^1.0.4` |
| Native splash | `flutter_native_splash ^2.4.4` |
| Launcher icons | `flutter_launcher_icons ^0.14.1` |

### Fonts (bundled — Google Fonts package removed)

`Inter`, `Manrope`, `PlayfairDisplay`, `PlusJakartaSans` — all weights `400–800` shipped as TTFs under `assets/google_fonts/` and registered natively in `pubspec.yaml`. This allows Shorebird code-push to ship copy edits OTA.

### What is NOT in the stack (despite older docs claiming otherwise)

- ❌ `easy_localization` — replaced by hand-rolled `lib/core/i18n/` translations.
- ❌ `onesignal_flutter` — replaced by `firebase_messaging` + FCM.
- ❌ `google_fonts` package — fonts bundled as native assets.
- ❌ Shorebird code-push — referenced in comments but not yet integrated.

> See `BUGS_AND_ISSUES.md` for the documentation drift list.

---

## 4. Project Status

- **Greenfield rewrite** — V1 was never shipped to either store.
- **MVP under construction.** Customer flows are largely Supabase-backed; seller flows (orders, shop settings, services, tariff) still rely on mock repositories.
- **`USE_MOCKS=true`** is the default in `env/dev.json`; flipping to `false` in `env/prod.json` exposes the actual Supabase RLS surface.
- Approx. **53,000 lines of Dart** under `lib/` across 200+ files.

---

## 5. Setup

### Prerequisites

- Flutter `3.11+` (run `flutter --version`)
- Dart `3.11+`
- Android SDK 21+ / Xcode 15+
- A Supabase project (URL + anon key) and a Firebase project (FCM enabled)

### Clone & install

```bash
git clone <repo-url> mebellar_new
cd mebellar_new/mebellar_app
flutter pub get
```

### Environment configuration

All configuration is passed via `--dart-define-from-file=env/<env>.json`.
**No credential has a compiled-in default.** `AppConfig.assertConfigured()`
runs at the top of `main()` and aborts the app on launch if a required key is
missing — a build with no env file fails loudly instead of silently running
against blank credentials.

| File | Purpose |
| --- | --- |
| `env/example.json` | Committed template — full key shape, secret values blank. Copy it to make a new env file. |
| `env/dev.json` | Local development (`USE_MOCKS: true`). |
| `env/prod.json` | Release builds (`USE_MOCKS: false`). |

| Key | Required | Notes |
| --- | --- | --- |
| `SUPABASE_URL` | ✅ | Project URL. |
| `SUPABASE_ANON_KEY` | ✅ | Public anon JWT — safe in the client, guarded by RLS. |
| `YANDEX_GEOCODER_API_KEY` | ✅ | Restrict by package / referrer in Yandex Cloud. |
| `SENTRY_DSN` | — | Empty ⇒ Sentry initialises disabled (no telemetry sent). |
| `APP_ENV` | — | `dev` (default) or `prod`. |
| `USE_MOCKS` | — | `true` ⇒ canned catalog data instead of the live API. |
| `SELLER_FULFILLMENT_ENABLED` | — | `false` (default) ⇒ mock-only seller surfaces (orders, shop settings, services, KYC) render a "coming soon" placeholder instead of fake data. |

> ⚠️ **`env/dev.json` / `env/prod.json` are committed to this private repo** so
> config syncs across the maintainer's machines via `git pull`. The Supabase
> anon key is low-risk by design, but treat the whole repo as a secret:
> **rotate every key if it is cloned to an untrusted machine or the repo is
> exposed.** A Firebase **Admin SDK** service-account private key must *never*
> live in this repo — see `BUGS_AND_ISSUES.md` §1.

### Running

```bash
# Dev (mocks ON)
flutter run --dart-define-from-file=env/dev.json

# Prod-like (Supabase live, mocks OFF)
flutter run --dart-define-from-file=env/prod.json
```

### Build

```bash
# Android APK (release, obfuscated)
flutter build apk --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json

# Android App Bundle (Play Store)
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json

# iOS IPA
flutter build ipa --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json
```

### Generate launcher icons / native splash

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Test

```bash
flutter test                 # only 5 BLoC tests currently exist
flutter test --coverage
flutter analyze              # uses analysis_options.yaml
dart format lib/ test/
```

---

## 6. High-Level Folder Map

```
mebellar_app/
├── android/                  # native Android (incl. google-services.json)
├── ios/                      # native iOS (incl. GoogleService-Info.plist)
├── assets/
│   ├── google_fonts/         # bundled TTFs (replaces google_fonts pkg)
│   └── logo/                 # brand assets for launcher / splash
├── docs/legacy/              # archived in-Uzbek docs (18 files; see folder README)
├── env/
│   ├── example.json          # committed template (blank secrets)
│   ├── dev.json              # committed; USE_MOCKS=true
│   └── prod.json             # committed; USE_MOCKS=false
├── lib/
│   ├── main.dart             # bootstrap, Firebase init, Phoenix-wrapped mode router
│   ├── firebase_options.dart # generated; Android + iOS FCM keys hardcoded
│   ├── config/               # AppConfig + AppMode enum
│   ├── core/                 # shared infra (DI, auth, network, i18n, theme, …)
│   ├── shared/               # cross-mode domain (models, repos, mocks, widgets)
│   ├── auth/                 # shared login/register/verify screens
│   ├── customer/             # customer surface (features/, services/, widgets/)
│   └── seller/               # seller surface (features/, services/, widgets/)
├── store/                    # Play Store listing + privacy policy
├── test/                     # 5 BLoC tests
└── pubspec.yaml
```

For the deep dive, see [`ARCHITECTURE.md`](./ARCHITECTURE.md).

---

## 7. Companion Documentation

| File | Scope |
| --- | --- |
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | System design, Firebase vs Supabase split, DI scopes, routing, state |
| [`BUGS_AND_ISSUES.md`](./BUGS_AND_ISSUES.md) | Security, anti-patterns, broken logic, documentation drift |
| [`REFACTORING.md`](./REFACTORING.md) | SOLID/DRY violations, files to split, scalability levers |
| [`ROADMAP.md`](./ROADMAP.md) | Short / mid / long-term action plan to ship V1 |
| [`docs/legacy/`](./docs/legacy/) | Archived in-Uzbek deep-dives — predate the FCM / hand-rolled-i18n stack (see the folder README) |

---

## 8. Maintainer

- Lead developer: **Eldor Turg'unov** (`Turgunoff`)
- Internal codename remains `woody_app` in `pubspec.yaml`; brand-facing identifier is `uz.mebellar.app` / `com.mebellar.app`.

> The project is private and has no open-source license selected yet.

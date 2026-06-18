# Woody — Two-Sided Furniture Marketplace (Flutter)

> Internal codename: **Woody** (`pubspec.yaml` → `name: woody_app`). Brand: **Woody** — an Uzbekistan-focused furniture (`mebel`) marketplace. App id `com.mebellar.app`.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-^3.11.5-0175C2?logo=dart)](https://dart.dev)
[![Backend](https://img.shields.io/badge/Backend-woody__backend%20(FastAPI)-009688)](https://api.woody.uz)

> **Authoritative docs:** the operational brain is [`CLAUDE.md`](./CLAUDE.md); the component spec is [`woody_mobile_tz.md`](./woody_mobile_tz.md); the platform master spec is [`../TZ.md`](../TZ.md). This README is a high-level orientation.

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
| **Order fulfillment** | Customers place orders (currently **COD**), sellers fulfill them; both sides see status via the Woody **WebSocket** feed with FCM push fallback. |
| **Monetization** | Sellers pay a tariff subscription + commission settled through a wallet ledger (soft-freeze on debt). |
| **Engagement** | FCM push notifications (per-chat collapse + order/fee events) drive return visits. |

---

## 2. Tech Stack

| Layer | Choice |
| --- | --- |
| Framework / language | **Flutter** · **Dart** SDK `^3.11.5` |
| State management | **`flutter_bloc`** `^9` (Bloc for event-driven flows, Cubit for single-input commands; `bloc_concurrency`) |
| Dependency injection | **`get_it`** `^8` — scoped (root + per-mode) |
| Routing | **`go_router`** `^14` (customer: GoRouter; seller: StatefulShellRoute) |
| Backend | **`woody_backend`** — FastAPI at `api.woody.uz`; REST (`/api/v1`) + WebSocket. **The only backend.** No Supabase, no Firebase Auth. |
| Auth | Phone + SMS OTP → backend-issued JWT (access + refresh) in `flutter_secure_storage` |
| Push / crash / analytics | **Firebase** — Messaging (FCM) + Crashlytics + Analytics (`firebase_messaging`, `flutter_local_notifications`). **No Sentry.** |
| Local storage | **Hive** (cache, hybrid guest cart/favorites, settings) + `flutter_secure_storage` (tokens) |
| Networking | `dio` / `http` via `WoodyApiClient` (single client; `Accept-Language` + auth interceptors) |
| Maps & location | `yandex_mapkit`, `geolocator`, `permission_handler` |
| Localization | Hand-rolled pure-Dart i18n (`lib/core/i18n/`) — uz / ru / en (uz baseline) |
| AR | `model_viewer_plus` + `webview_flutter` + `gal` (buyer AR viewer, save-to-gallery) |
| Logging | `talker_flutter` |
| Runtime restart | `flutter_phoenix` (powers the mode switch) |
| Charts / images / UI | `fl_chart`, `cached_network_image`, `shimmer`, `iconsax_flutter`, `lottie`, `flutter_svg` |

**Dev tooling:** `flutter_lints`, `bloc_test`, `mocktail`, `integration_test`, `flutter_native_splash`, `flutter_launcher_icons`.

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
- Android SDK 21+ and/or Xcode 15+
- A `env/prod.json` (copy from `env/example.json` and fill the keys below) and the Firebase config for FCM

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

| Key | Required | Notes |
| --- | --- | --- |
| `WOODY_API_URL` | ✅ | Backend base URL — `https://api.woody.uz`. `WoodyApiClient` adds the `/api/v1` prefix. |
| `YANDEX_GEOCODER_API_KEY` | ✅ | Restrict by package / referrer in the Yandex Cloud console. |
| `APP_ENV` | — | `dev` (default) or `prod`. |

> ⚠️ **Secrets hygiene.** `env/prod.json` is **gitignored** — never commit it, signing keystores (`*.jks`, `key.properties`), or a Firebase **Admin SDK** service-account key.

---

## 7. Running, Building & Testing

```bash
# Run the app
flutter run --dart-define-from-file=env/prod.json

# Static analysis — must report 0 issues
dart analyze lib/

# Tests
flutter test
flutter test --coverage          # with lcov report
flutter test integration_test    # end-to-end happy path (needs a device)

# Formatting
dart format lib/ test/
```

### Release builds

```bash
# Android App Bundle
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json

# iOS IPA
flutter build ipa --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json
```

---

## 8. Companion Documentation

| File | Scope |
| --- | --- |
| [`CLAUDE.md`](./CLAUDE.md) | **Start here** — operational brain: architecture, conventions, gotchas, do-not-break invariants. |
| [`.claude/rules/`](./.claude/rules/) | Distilled invariant cards (architecture, theming, i18n, backend-api, testing). |
| [`woody_mobile_tz.md`](./woody_mobile_tz.md) | Component-level technical spec for the mobile app. |
| [`../TZ.md`](../TZ.md) | Platform **Master Technical Specification** (single source of truth). |
| [`../docs/audit/workspace_audit_2026_06_18.md`](../docs/audit/workspace_audit_2026_06_18.md) | Latest code-health audit (incl. the mobile findings). |
| [`store/`](./store/) | App Store / Play listings + privacy policy. |

---

## 9. Maintainer

- Lead developer: **Eldor Turg'unov** (`Turgunoff`).
- Internal package name: `woody_app`; app id: `com.mebellar.app`.
- The project is private; no open-source license has been selected.

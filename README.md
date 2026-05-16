# Mebellar — Two-Sided Furniture Marketplace (Flutter)

> Internal codename: **Woody** (`pubspec.yaml` → `name: woody_app`). Brand: **Mebellar** — an Uzbekistan-focused furniture (`mebel`) marketplace.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-^3.11.5-0175C2?logo=dart)](https://dart.dev)
[![Backend](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase)](https://supabase.com)
[![Analyzer](https://img.shields.io/badge/dart%20analyze-0%20issues-success)]()
[![Tests](https://img.shields.io/badge/tests-192%20passing-success)]()

---

## 1. What is Mebellar?

Mebellar is a **two-sided B2C/C2C marketplace for furniture**, targeting the Uzbekistan market. It ships as **one Flutter binary that hosts two independent product surfaces**:

- a **customer storefront** — browse catalog, search, cart, checkout, track orders;
- a **seller back-office** — onboard a shop, manage products, fulfill orders, subscribe to tariff plans.

A single user identity can be both a buyer and a seller. The app switches between the two surfaces **at runtime** — no re-install — by swapping the DI scope, theme, router, and navigation shell and rebirthing the widget tree.

### Business pillars

| Pillar | Description |
| --- | --- |
| **Catalog discovery** | Multi-level categories, search, banners, premium home blocks. |
| **Two-sided onboarding** | Buyers sign up with email/OTP; sellers run a multi-step onboarding + KYC verification flow. |
| **Order fulfillment** | Customers place orders, sellers fulfill them; both sides see realtime status via Supabase Realtime. |
| **Monetization** | Sellers subscribe to tariff plans, upgraded via an in-app P2P payment flow. |
| **Engagement** | FCM push notifications (topic broadcasts + per-token personal pings) drive return visits. |

---

## 2. Tech Stack

| Layer | Choice |
| --- | --- |
| Framework / language | **Flutter** · **Dart** SDK `^3.11.5` |
| State management | **`flutter_bloc`** `^9` (+ `bloc_concurrency` for event transformers) |
| Dependency injection | **`get_it`** `^8` — scoped (root + per-mode) |
| Routing | **`go_router`** `^14` — declarative, both modes |
| Backend | **Supabase** (`supabase_flutter` `^2.8`) — Auth, Postgres, Realtime, Storage |
| Push notifications | **Firebase Cloud Messaging** (`firebase_messaging` + `flutter_local_notifications`) |
| Local storage | **Hive** (cache, settings, drafts) + `flutter_secure_storage` |
| Networking | `dio` / `http` |
| Maps & location | `yandex_mapkit`, `geolocator`, `permission_handler` |
| Localization | Hand-rolled pure-Dart i18n (`lib/core/i18n/`) — uz / ru / en |
| Logging & crash reporting | `talker_flutter` → `sentry_flutter` |
| Runtime restart | `flutter_phoenix` (powers the mode switch) |
| Charts / images / UI | `fl_chart`, `cached_network_image`, `flutter_staggered_grid_view`, `shimmer`, `iconsax_flutter` |

**Dev tooling:** `flutter_lints`, `bloc_test`, `mocktail`, `integration_test`, `flutter_native_splash`, `flutter_launcher_icons`.

> **Not in the stack** (despite some older docs): `easy_localization`, `onesignal_flutter`, the `google_fonts` package. Fonts (`Inter`, `Manrope`, `PlayfairDisplay`, `PlusJakartaSans`) are bundled as native TTF assets.

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
   Data (Repository interface)
        │   resolved by RepositoryResolver
        ├── Supabase*Repository   ← live backend
        └── Mock*Repository       ← canned data
```

### Architectural patterns a new developer must know

| Pattern | File(s) | What it does |
| --- | --- | --- |
| **`Result<T, Failure>`** | `lib/core/result/result.dart`, `lib/core/error/failure.dart` | Repository methods return a typed success-or-failure value instead of throwing. Callers pattern-match `Ok` / `Err` — no stray exceptions crossing layer boundaries. |
| **`RepositoryResolver`** | `lib/core/di/repository_resolver.dart` | Chooses the `Mock*` or `Supabase*` implementation per `AppConfig.useMocks`. Release builds tree-shake the mock graph out of the binary. |
| **Scoped DI (`get_it`)** | `lib/core/di/` | A **root scope** holds cross-cutting singletons (auth, theme, notifications, Hive boxes); a **mode scope** (`customer` / `seller`) holds surface-specific blocs and is swapped on every mode change. Registration is split into `*_module.dart` files. |
| **Runtime mode switch** | `AppModeCubit` + `flutter_phoenix` | Emitting a new `AppMode` triggers `popScope()` → `initModeScope(mode)` → `Phoenix.rebirth()`, rebuilding the tree under the other surface. |
| **Hand-rolled i18n** | `lib/core/i18n/` | Pure-Dart translation maps; a debug-only guard fails boot if `ru`/`en` drift below the `uz` baseline. |

For the full deep dive, see [`ARCHITECTURE.md`](./ARCHITECTURE.md) and [`docs/PROJECT_STATE_ANALYSIS.md`](./docs/PROJECT_STATE_ANALYSIS.md).

---

## 4. Repository Layout

```
mebellar_app/
├── android/ · ios/            # native projects (incl. FCM config)
├── assets/                    # bundled fonts + brand logo
├── docs/
│   ├── PROJECT_STATE_ANALYSIS.md   # architectural health report — start here
│   ├── supabase_rls_policies.sql.md
│   └── legacy/                # archived in-Uzbek deep-dives (predate current stack)
├── env/
│   ├── example.json           # committed template (blank secrets)
│   └── prod.json              # the single working env file (see §6)
├── supabase/
│   ├── migrations/            # 23 ordered SQL migrations (schema + RLS)
│   └── functions/             # send-news-broadcast Edge Function
├── lib/
│   ├── main.dart              # bootstrap → Firebase → DI → Phoenix mode router
│   ├── config/                # AppConfig + AppMode enum
│   ├── core/                  # DI, auth, network, i18n, theme, result, logging…
│   ├── shared/                # cross-mode models, repositories, mocks, widgets
│   ├── auth/                  # shared login / register / verify / OTP screens
│   ├── customer/              # customer surface — features/, services/, widgets/
│   └── seller/                # seller surface — features/, services/, widgets/
├── test/                      # mirrors lib/ exactly — every test sits at the
│   │                          #   same path as its subject (e.g. a test for
│   │                          #   lib/customer/features/cart/bloc/ lives in
│   │                          #   test/customer/features/cart/bloc/)
│   └── goldens/                # golden baseline PNGs — kept flat, not mirrored
└── integration_test/          # end-to-end happy-path test
```

> **Test layout convention.** The `test/` tree is a strict mirror of `lib/`: a
> test file lives at the directory that mirrors the path of the class or widget
> it covers. The only exception is `test/goldens/`, which stays a flat folder of
> baseline images. New tests must follow this convention — do not add files to
> the `test/` root.

---

## 5. Setup

### Prerequisites

- Flutter `3.11+` / Dart `3.11+` (`flutter --version`)
- Android SDK 21+ and/or Xcode 15+
- Access to the project's Supabase project and Firebase project (FCM)

### Clone & install

```bash
git clone <repo-url> mebellar_app
cd mebellar_app
flutter pub get
```

---

## 6. Environment Configuration — Single `prod.json` Setup

All runtime configuration is injected at build time via `--dart-define-from-file`. **No secret has a compiled-in default** — `AppConfig.assertConfigured()` runs at the top of `main()` and **aborts the build loudly** if any required key is missing. A build with no env file fails fast instead of silently running against blank credentials.

The project uses **one canonical environment file: `env/prod.json`.** The earlier `dev.json` was retired — there is no longer a separate dev profile. `env/prod.json` drives every local run, every build, and every test fixture seed.

| File | Role |
| --- | --- |
| `env/example.json` | Committed template — the full key shape with blank secret values. Copy it if you ever need to recreate `prod.json`. |
| `env/prod.json` | The single working env file. Committed to this **private** repo so config syncs across the maintainer's machines. |

### Keys

| Key | Required | Notes |
| --- | --- | --- |
| `SUPABASE_URL` | ✅ | Project URL. |
| `SUPABASE_ANON_KEY` | ✅ | Public anon JWT — safe in the client, guarded by RLS. |
| `YANDEX_GEOCODER_API_KEY` | ✅ | Restrict by package / referrer in the Yandex Cloud console. |
| `SENTRY_DSN` | — | Empty ⇒ Sentry initialises disabled (no telemetry sent). |
| `APP_ENV` | — | `dev` (default) or `prod`. |
| `USE_MOCKS` | — | `true` ⇒ canned catalog data instead of the live backend. |
| `SELLER_FULFILLMENT_ENABLED` | — | `false` (default) ⇒ mock-only seller surfaces show a "coming soon" placeholder. |
| `SELLER_USES_GO_ROUTER` | — | `true` (default) ⇒ seller mode runs on `go_router`. |

> ⚠️ **Secrets hygiene.** `env/prod.json` is committed deliberately (private repo, RLS-guarded anon key). However, a Firebase **Admin SDK** service-account key must *never* be committed — see [`docs/PROJECT_STATE_ANALYSIS.md`](./docs/PROJECT_STATE_ANALYSIS.md) §6.

---

## 7. Running, Building & Testing

```bash
# Run the app (single env file)
flutter run --dart-define-from-file=env/prod.json

# Static analysis — must report 0 issues
dart analyze

# Full test suite — 192 tests
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
| [`docs/PROJECT_STATE_ANALYSIS.md`](./docs/PROJECT_STATE_ANALYSIS.md) | **Start here** — architectural health, tech-debt register, bug sweep. |
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Deep system design — DI scopes, routing, state, Firebase vs Supabase split. |
| [`ROADMAP.md`](./ROADMAP.md) | What is built (Part 1) and remaining development tasks (Part 2). |
| [`BUGS_AND_ISSUES.md`](./BUGS_AND_ISSUES.md) | Historical issue log (security, anti-patterns, drift). |
| [`REFACTORING.md`](./REFACTORING.md) | SOLID/DRY notes and scalability levers. |
| [`docs/legacy/`](./docs/legacy/) | Archived in-Uzbek deep-dives — predate the current stack. |

---

## 9. Maintainer

- Lead developer: **Eldor Turg'unov** (`Turgunoff`).
- The internal package name remains `woody_app`; the brand-facing app id is `uz.mebellar.app` / `com.mebellar.app`.
- The project is private; no open-source license has been selected.

# Mebellar V2 — Flutter App

> Two-sided mebel marketplace mobile app — bitta loyihada **customer** va **seller** rejimlari, `flutter_phoenix` orqali restart pattern bilan mode switch.

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart)](https://dart.dev)
[![Status](https://img.shields.io/badge/Status-V1%20MVP%20development-yellow)]()
[![Backend](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi)](../backend)

## Tezkor navigatsiya

| Hujjat | Maqsad |
|--------|--------|
| [`docs/README.md`](./docs/README.md) | Mobile hujjatlari indeksi (16 fayl) |
| [`docs/00-overview.md`](./docs/00-overview.md) | Loyiha umumiy ko'rinishi va mobile arxitekturasi |
| [`docs/02-dual-entry-mode-switching.md`](./docs/02-dual-entry-mode-switching.md) | Dual entry-point, scoped DI, mode switch |
| [`docs/05-notifications-deep-linking.md`](./docs/05-notifications-deep-linking.md) | Cross-mode push notification handling |
| [`docs/07-api-reference.md`](./docs/07-api-reference.md) | Backend API kontrakti |
| [`ROADMAP.md`](./ROADMAP.md) | Sprint-by-sprint amaliy reja |
| [`../ROADMAP.md`](../ROADMAP.md) | Master timeline (backend bilan sinxron) |

## Mebellar nima

Mebellar — O'zbekistondagi mebel marketplace platformasi. Ikki tomonli (two-sided):

- **Customer** — xaridor: catalog, search, cart, checkout, order tracking
- **Seller** — sotuvchi: shop, mahsulot CRUD, order fulfillment, dashboard, tariff

V1 hech qaysi store'ga chiqarilmagan, shuning uchun **greenfield rewrite**.

## Asosiy arxitektura xususiyatlari

- **Dual entry-point** — bitta loyiha, ikkita `MaterialApp` (`CustomerApp`, `SellerApp`)
- **Scoped DI** (`get_it` + scope pattern) — root scope (Hive, Supabase, Dio) + mode scope (BLoC, realtime channels) — memory leak'siz mode switch
- **`flutter_phoenix`** — widget tree restart, `main()` qayta chaqirilmaydi (scope manipulyatsiya rebirth'dan oldin)
- **Cross-mode notification handling** — pending route Hive'ga saqlanadi, mode switch'dan keyin consume qilinadi
- **Multilingual** — `easy_localization` (uz/ru/en) + backend JSONB
- **Realtime** — Supabase Postgres CDC (orders status updates, yangi orderlar)

Tafsilotlar: [`docs/`](./docs/) ichida 16 fayl.

## Stack

| Layer | Texnologiya |
|-------|-------------|
| Framework | Flutter 3.41+, Dart 3.11+ |
| State | `flutter_bloc` |
| Routing | `go_router` (har AppMode uchun alohida router) |
| DI | `get_it` + scope pattern |
| HTTP | `dio` (Bearer token interceptor) |
| Auth | `supabase_flutter` (email/password) |
| Realtime | Supabase Realtime (Postgres CDC) |
| Local storage | `hive_flutter` (settings, cache) |
| Secure storage | `flutter_secure_storage` (refresh tokens) |
| Push | `onesignal_flutter` |
| App restart | `flutter_phoenix` |
| Localization | `easy_localization` |
| Image | `image_picker`, `image`, `cached_network_image` |
| Monitoring | `sentry_flutter` |

## Joriy holat

V1 implementatsiyasi **boshlanish bosqichida**. Hozirgi `lib/` papkasida demo skeleton bor (boshlanish kodi). Sprint plan asosida bosqichma-bosqich kengaytiriladi.

Rejani [`ROADMAP.md`](./ROADMAP.md) faylda ko'ring.

## Loyiha tuzilmasi (V2 maqsad)

```
lib/
├── main.dart                  # bootstrap + mode detection + cold-start notif
├── core/                      # SHARED — root scope dependencies
│   ├── di/
│   ├── network/               # Dio, Supabase client
│   ├── storage/               # Hive boxes, secure storage
│   ├── auth/                  # AuthRepository, TokenManager
│   ├── theme/                 # customer + seller themes
│   ├── localization/
│   ├── notifications/         # cross-mode handler
│   ├── widgets/
│   └── utils/
├── shared/                    # SHARED domain models & repositories
│   ├── models/
│   ├── repositories/
│   └── widgets/
├── customer/
│   ├── customer_app.dart      # MaterialApp + GoRouter (customer)
│   ├── router.dart
│   ├── features/              # home, catalog, product_detail, cart, checkout, orders, ...
│   └── widgets/
├── seller/
│   ├── seller_app.dart        # MaterialApp + GoRouter (seller)
│   ├── router.dart
│   ├── features/              # onboarding, dashboard, products, orders, analytics, tariff, ...
│   └── widgets/
└── auth/                      # SHARED auth screens (login, register, ...)
```

Tafsilot: [`docs/01-project-structure.md`](./docs/01-project-structure.md).

## Boshlash

### Talab qilinadi

- Flutter 3.41+ (`flutter --version`)
- Dart 3.11+
- Xcode 15+ (iOS uchun)
- Android Studio + SDK 34+ (Android uchun)
- Backend ishga tushgan bo'lishi shart — [`../backend/README.md`](../backend/README.md)

### O'rnatish

```bash
git clone <repo-url>
cd Mebellar-olami/app
flutter pub get
```

### Ishga tushirish (V2 — kelajakda)

V2 implementatsiyasi tugagandan keyin environment fayllar bilan:

```bash
# Dev (local backend + local Supabase)
flutter run --dart-define-from-file=env/dev.json

# Staging
flutter run --dart-define-from-file=env/staging.json

# Production
flutter run --dart-define-from-file=env/prod.json
```

`env/dev.json` misoli:

```json
{
  "SUPABASE_URL": "http://127.0.0.1:54321",
  "SUPABASE_ANON_KEY": "...",
  "API_BASE_URL": "http://127.0.0.1:8000/api/v1",
  "ONESIGNAL_APP_ID": "...",
  "SENTRY_DSN": ""
}
```

> `env/*.json` fayllar `.gitignore`'da. `env/example.json` saqlash mumkin.

### Hozirgi demo'ni ishga tushirish

```bash
flutter pub get
flutter run
```

Demo Backend `/api/products` endpoint'idan mahsulot ro'yxatini fetch qiladi. Backend ishga tushgan bo'lishi shart (`../backend/run.sh`).

API URL konfiguratsiyasi (`lib/main.dart`'dagi `defaultApiBaseUrl()`):

| Platforma | URL |
|-----------|-----|
| Android emulator | `http://10.0.2.2:8000` (host loopback) |
| iOS simulator / macOS / web | `http://127.0.0.1:8000` |
| Real qurilma | Kompyuter local IP (masalan `http://192.168.1.50:8000`) |

## Test

```bash
flutter test                              # widget + unit tests
flutter test test/widget_test.dart        # alohida fayl
flutter test --coverage                   # coverage hisoboti
```

## Lint va format

```bash
flutter analyze                           # static analysis
dart format lib/ test/                    # auto-format
```

`analysis_options.yaml` strict rules bilan sozlangan.

## Build

```bash
# Android (debug)
flutter build apk

# Android release (obfuscated, symbols Sentry uchun)
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols/

# iOS (release, Apple Developer account kerak)
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/symbols/

# Bundle size analiz
flutter build apk --analyze-size
```

## Bundle ID

| Platforma | ID |
|-----------|-----|
| iOS | `uz.mebellar.app` |
| Android | `uz.mebellar.app` |

## Roadmap

V1 implementatsiyasi 12 sprint (~3 oy optimistik / 6 oy realistik solo dev). Tafsilot:

- [`ROADMAP.md`](./ROADMAP.md) — Flutter sprint plan
- [`../ROADMAP.md`](../ROADMAP.md) — Master timeline (backend bilan sinxron)

Asosiy bosqichlar:

| Sprint | Maqsad |
|--------|--------|
| 0 | Apple/Google account, design assets |
| 1 | Mobile skeleton + auth + GET /me |
| 2 | Mode switching + DI |
| 3 | Customer home + catalog |
| 4 | Product detail + cart |
| 5 | Checkout + orders + realtime |
| 6 | Seller onboarding + verification |
| 7 | Seller dashboard + products |
| 8 | Seller orders + shop settings |
| 9 | Tariff upgrade UX (P2P payment) |
| 10 | Cross-mode notifications |
| 11 | Polish + QA |
| 12 | Launch prep (App Store + Play Store) |

## Hujjatlar

[`docs/`](./docs/) ichida 16 fayl — har biri bitta amaliy mavzuga bag'ishlangan. Boshlanish: [`docs/README.md`](./docs/README.md).

| # | Mavzu |
|---|-------|
| 00 | Overview |
| 01 | Project structure |
| 02 | Dual entry & mode switching |
| 03 | Deferred components |
| 04 | Realtime (Supabase) |
| 05 | Notifications & deep linking |
| 06 | Auth flow |
| 07 | API reference |
| 08 | Customer features |
| 09 | Seller features |
| 10 | Tariff upgrade UX |
| 11 | Storage & image upload |
| 12 | Localization |
| 13 | Security |
| 14 | Roadmap phases |
| 15 | Glossary & open questions |

## Litsenziya

Private project — litsenziya hali tanlanmagan.

## Bog'lanish

Loyiha muallifi: [Eldor Turg'unov](https://github.com/eldor-eshniyazov)

Texnik savollar uchun: GitHub Issues (kelajakda) yoki Telegram.

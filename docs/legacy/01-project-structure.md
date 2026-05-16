# 01 — Loyiha tuzilishi (`lib/`)

> Asl §5.1.

## Asosiy bo'limlar

```
lib/
├── main.dart                  # bootstrap + mode detection + cold-start notif
│
├── core/                      # SHARED — har ikkala mode foydalanadi
│   ├── di/                    # GetIt + Injectable setup (root + mode scopes)
│   ├── network/
│   │   ├── api_client.dart    # Dio instance, interceptors (auth header)
│   │   ├── supabase_client.dart
│   │   └── error_handler.dart
│   ├── storage/
│   │   ├── hive_boxes.dart    # settings, cache, pending_route
│   │   └── secure_storage.dart  # refresh token
│   ├── auth/
│   │   ├── auth_repository.dart
│   │   └── token_manager.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── customer_theme.dart   # different brand for each
│   │   └── seller_theme.dart
│   ├── localization/
│   │   └── ... (uz, ru, en)
│   ├── error/
│   │   ├── failure.dart
│   │   └── either.dart
│   ├── notifications/
│   │   ├── notification_handler.dart   # cross-mode deep linking
│   │   └── onesignal_setup.dart
│   ├── widgets/               # truly shared widgets
│   │   ├── primary_button.dart
│   │   ├── text_field.dart
│   │   └── ...
│   └── utils/
│
├── shared/                    # SHARED domain models & repositories
│   ├── models/
│   │   ├── product.dart
│   │   ├── shop.dart
│   │   ├── order.dart
│   │   ├── multilingual_text.dart
│   │   └── ...
│   ├── repositories/
│   │   ├── product_repository.dart
│   │   ├── shop_repository.dart
│   │   └── ...
│   └── widgets/               # shared cross-mode widgets
│       ├── product_card.dart
│       ├── order_tile.dart
│       └── shop_header.dart
│
├── customer/
│   ├── customer_app.dart      # MaterialApp + GoRouter (customer)
│   ├── router.dart
│   ├── features/
│   │   ├── home/
│   │   ├── catalog/
│   │   ├── product_detail/
│   │   ├── search/
│   │   ├── cart/
│   │   ├── checkout/
│   │   ├── orders/
│   │   ├── favorites/
│   │   └── profile/
│   └── widgets/
│
├── seller/
│   ├── seller_app.dart        # MaterialApp + GoRouter (seller)
│   ├── router.dart
│   ├── features/
│   │   ├── onboarding/        # first-time seller registration + verification
│   │   ├── dashboard/
│   │   ├── products/
│   │   ├── orders/
│   │   ├── analytics/
│   │   ├── shop_settings/
│   │   ├── verification/
│   │   ├── tariff/
│   │   └── profile/
│   └── widgets/
│
└── auth/                      # shared auth screens (login, register)
    ├── login_screen.dart
    ├── register_screen.dart
    ├── verify_email_screen.dart
    └── forgot_password_screen.dart
```

## Bo'limlar maqsadi

### `core/`

**SHARED across both apps** — har ikkala AppMode foydalanadi. **Root scope'ga registratsiya qilinadigan** singletonlar shu yerdan keladi:

- HTTP client (Dio)
- Supabase client
- Hive boxes (settings, cache)
- AuthRepository, TokenManager
- Theme, localization
- OneSignal handler

> Bu qatlamdagi narsalar mode switch'da **dispose qilinmaydi** — root scope'da turadi.

### `shared/`

Domain models va repositoriy layer — har ikkala mode foydalanadigan, lekin business logic'li. Misol: `Product` modeli, `ProductRepository` (catalog uchun customer'ga, mahsulot CRUD uchun seller'ga).

### `customer/`

Faqat customer mode'da yuklanadi. Har feature folder ichida BLoC + screens + widgets:

```
customer/features/cart/
├── bloc/
│   ├── cart_bloc.dart
│   ├── cart_event.dart
│   └── cart_state.dart
├── screens/
│   └── cart_screen.dart
├── widgets/
│   ├── cart_item_tile.dart
│   └── cart_summary.dart
└── repository/
    └── cart_repository.dart
```

### `seller/`

Faqat seller mode'da yuklanadi. Strukturasi customer bilan bir xil pattern.

### `auth/`

**SHARED** — login/register screens. Login bo'lgandan keyin app `_getInitialMode()` orqali qaysi mode'ga kirishni aniqlaydi.

## `assets/` daraxti

```
assets/
├── images/
├── icons/
└── translations/
    ├── uz.json
    ├── ru.json
    └── en.json
```

## Naming va kod stili

- File names: `snake_case.dart`
- Class names: `PascalCase`
- BLoC: `<Feature>Bloc`, events: `<Feature>Event`, states: `<Feature>State`
- Repository pattern: interface + implementation (testlar uchun mock yengil)
- `analysis_options.yaml`: flutter_lints + custom rules
- Linter strict: `prefer_const_constructors`, `unused_import`, `avoid_print`

## `pubspec.yaml` asosiy dependencies (V1)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.0.0
  go_router: ^14.6.0
  get_it: ^8.0.0
  dio: ^5.7.0
  supabase_flutter: ^2.8.0
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.2.0
  flutter_phoenix: ^1.1.1
  easy_localization: ^3.0.7
  onesignal_flutter: ^5.2.0
  flutter_svg: ^2.0.10
  cached_network_image: ^3.4.1
  image_picker: ^1.1.2
  image: ^4.3.0           # client-side resize
  intl: ^0.19.0
  equatable: ^2.0.7
```

V2 da qo'shiladi: `fl_chart`, `pdf`, `qr_flutter` (faqat seller analytics, deferred).

## Joriy holat va keyingi qadam

Hozirgi `app/` papkasida demo Flutter skeleton bor:

```
app/
├── lib/
│   └── main.dart              # demo (mahsulotlar listini fetch qiladi)
├── pubspec.yaml
├── android/, ios/, web/, ...
```

V2 implementatsiyasi uchun `lib/` ni yuqoridagi to'liq strukturaga **bosqichma-bosqich** kengaytiramiz. Tartib uchun [14-roadmap-phases.md](./14-roadmap-phases.md) ga qarang.

## Keyingi qadam

→ [02-dual-entry-mode-switching.md](./02-dual-entry-mode-switching.md) — main.dart, scoped DI, mode switch

# Woody Mobile — Texnik Topshiriq (TZ)

**Komponent:** `mebellar_app` — Woody mobil ilova (customer + seller)
**Sana:** 2026-06-04 · **Holat:** Production · **Versiya:** `1.0.5+6`
**Package:** `com.mebellar.app` (Dart paket `woody_app`)
**Umumiy TZ:** [`../woody_v2_tz.md`](../woody_v2_tz.md) · **Brain:** `CLAUDE.md`

> Bitta binary'da ikki rejim (customer + seller), `woody_backend` (`api.woody.uz`)
> ustida. Authoritative narrative — `CLAUDE.md`; invariant kartalar — `.claude/rules/`.

---

## 1. Texnologiya Stack

| Komponent | Tanlov |
|---|---|
| SDK | **Flutter** (Dart `^3.11.5`) — single binary, 2 rejim |
| State | **flutter_bloc** (Bloc + Cubit) + `bloc_concurrency` |
| DI | **GetIt** (scoped) |
| Routing | **go_router** — customer `GoRouter`, seller `StatefulShellRoute` (5 tab) |
| Restart | **flutter_phoenix** — rejim almashinuvi |
| Backend | **woody_backend** (REST `/api/v1` + WebSocket) — yagona |
| HTTP | **dio** (`WoodyApiClient`) |
| Realtime | **web_socket_channel** (`WoodyRealtimeService`) |
| Firebase | Messaging (FCM), Crashlytics, Analytics — **Firebase Auth YO'Q** |
| Local | **Hive** (settings, cart, favorites, news-reads, onboarding draft) |
| Secure | **flutter_secure_storage** (`TokenStore`) |
| Map | **yandex_mapkit** + geolocator + permission_handler |
| OTP autofill | **smart_auth** (Android SMS Consent) + iOS QuickType |
| Charts | **fl_chart** (seller analitika) |
| Test | flutter_test + bloc_test + mocktail (41 fayl) |

> **Env majburiy** — `--dart-define-from-file=env/prod.json`. `WOODY_API_URL`,
> `YANDEX_GEOCODER_API_KEY`. Bo'sh bo'lsa boot'da crash. Sentry **qaytmaydi**
> (Crashlytics almashtirdi).

---

## 2. Arxitektura Konventsiyalari

### 2.1 Ikki rejim shell

Boot'da Hive'dan rejim aniqlanadi; security guard cached seller-approval flag
false bo'lsa customer'ga tushiradi. `switchAppMode(...)` rejimni saqlaydi, GetIt
scope'ni almashtiradi, `Phoenix.rebirth` qiladi. **Customer cubit'lar seller
scope'da ro'yxatga olinmaydi** (va aksincha). Cross-mode kod `lib/shared/`'da.

### 2.2 State management

- **Bloc** — event-driven (search, cart, orders); **Cubit** — single-input
  (profile, checkout, mode).
- **Repository** — abstract interface + `Woody*Repository` (over `WoodyApiClient`)
  + in-memory mock (test). **Raw Dio/Remote* qatlam yo'q.**
- **DI ro'yxat tartibi muhim** — `AppModeCubit` lookup closure ishlatadi
  (`() => sl<AnalyticsService>()`), chunki catalog_module'dan oldin quriladi.

### 2.3 Theme — rang qattiq yozilmaydi

Light + dark mode. Har surface/text/border/fill token bag'dan:
- `PremiumTokens.of(context)` — customer ekranlar
- `AuthTokens.of(context)` — auth sheet
- `kInk`, `kDivider` — seller order details lokal token'lar

Brand accent (`PremiumTokens.accent`, `kTerracotta` = `#C27A5F`) — konstanta,
dark mode'da flip qilmaydi.

### 2.4 Localisation

Dart `Map` bundle'lar `lib/core/i18n/translations/` (`.arb` yo'q). Uchta til:
`*Uz` (baseline), `*Ru`, `*En`. `tr('namespace.key')` context-free.
`_missing_keys_check.dart` — debug boot'da ru/en parity yo'q bo'lsa crash.
Namespace'lar: auth, cart, catalog, checkout, common, notifications, product,
seller, tariff, tutorial, address, mode, onboarding, system, beta.

---

## 3. Customer Feature'lar (`lib/customer/features/`)

| Feature | Asosiy ekran(lar) | Holat | Mazmun |
|---|---|---|---|
| **home** | HomeScreen + HomeBloc | ✅ | Banner, kategoriya grid, tavsiya carousel |
| **tutorial** | TutorialScreen | ✅ | First-launch onboarding gate |
| **search** | SearchScreen + SearchBloc | ✅ | Global qidiruv, `ProductSearchFilter` (adaptiv facet), active-filter pill |
| **product_list** | ProductListScreen + Cubit | ✅ | Per-category, subkategoriya chip bar (race protection) |
| **product detail** | CatalogProductDetailScreen | ✅ | Cached peek + network refresh, add-to-cart, favorite, reviews |
| **cart** | CartScreen + CartBloc | ✅ | `watchItems()` stream, `/customer/cart/items` |
| **checkout** | CheckoutScreen + Cubit, MapAddressPickerScreen | ✅ | Yandex map manzil + fallback, `POST /customer/orders` |
| **orders** | OrdersHistory/Orders/OrderDetail | ✅ | Status banner, "Leave a review" CTA delivered'da |
| **favorites** | FavoritesScreen + Bloc | ✅ | Hive + `/customer/favorites` sync |
| **categories** | CategoriesScreen + Bloc | ✅ | Grid + subkategoriya drill-down |
| **notifications** | NotificationsScreen + Cubit (root-scoped) | ✅ | Unified inbox, realtime + FCM fallback |
| **broadcasts** | BroadcastPlaceholderScreen | ⏸️ | `/promo/:id`, `/news/:id`, `/system-alert/:id` — routing tayyor, UI kerak |
| **reviews** | review widgets (order detail ichida) | ✅ | Yulduz + matn + rasm, `POST /customer/reviews` |

---

## 4. Seller Feature'lar (`lib/seller/features/`)

**5 bottom-tab** (StatefulShellRoute, `seller_router.dart`):

| Tab | Feature | Holat | Mazmun |
|---|---|---|---|
| 0 | **dashboard** | ✅ | KPI snapshot, recent orders, `/seller/dashboard` |
| 1 | **products** | ✅ | CRUD, ProductFormScreen, R2 image upload, atributlar |
| 2 | **orders** | ✅ | Status filtr, transition, per-order chat |
| 3 | **analytics** | ✅ | fl_chart, date-range, sales/customers/reviews/orders |
| 4 | **profile** | ✅ | settings, shop-settings, services sub-route'lar |

**Full-screen / gated:**
| Feature | Holat | Mazmun |
|---|---|---|
| **onboarding** | ✅ | Multi-step: welcome → personal → shop → manzil (map) → KYC docs → business type → review → submit. Hive draft (resume) |
| **verification** | ✅ | KYC status polling (`verification-docs` bucket). Resubmit/appeal — backend support kutilmoqda |
| **reviews** | ✅ | Aggregat reyting + individual sharhlar |
| **tariff** | ✅ | TariffScreen/History/Pending, `payment-receipts` upload, pending P2P upgrade |
| **notifications** | ✅ | Root-scoped `NotificationsCubit` (customer bilan shared) |

---

## 5. Shared Modullar (`lib/shared/`)

### 5.1 Chat (per-order, ikkala rejimda)
`lib/shared/chat/` — `ChatsListCubit`, `ChatThreadCubit`; `MessageBubble`,
`ChatComposer`, `ChatStatusBanner`. Matn + rasm (`chat-attachments` bucket),
realtime (`chat_message`), read receipt. Viewer: `ChatSenderRole.customer | .seller`.
Bitta `chats` qatori har `order_id`'ga (UNIQUE) — mijoz birinchi xabarda lazy-create
qiladi, sotuvchi chat ocha olmaydi. Chat **doimo ochiq** qoladi.

### 5.2 Models (~37 klass)
Product/SellerProduct, Order/OrderStatus, Cart/CartItem, Chat/ChatMessage/
ChatSenderRole, Category, Address/Region, Shop, Review, AppNotification,
VerificationDocument/VerificationStatus, OnboardingDraft, Tariff, Banner,
ShopService/Config, WorkingHours, AttributeDefinition/Option, DashboardSnapshot,
Me, BusinessType, MultilingualText (uz/ru/en).

### 5.3 Repositories (`Woody*Repository` → backend)
| Repository | Backend endpoint |
|---|---|
| CartRepository | `/customer/cart/items` |
| OrderRepository | `/customer/orders`, `/{id}`, `/cancel` |
| FavoritesRepository | `/customer/favorites` |
| CustomerReviewsRepository | `/customer/reviews` |
| NotificationsRepository | `/chat/notifications` |
| ChatRepository | `/chat/chats[/{id}/messages]` |
| CategoryDataSource | `/catalog/categories` |
| ProductDataSource | `/catalog/products[/{id}]` (cached) |
| BannerRepository | `/catalog/banners` (cached) |
| NewsDataSource | `/catalog/news` (Hive read-state) |
| SellerProductRepository | `/seller/products/*` |
| SellerOrderRepository | `/seller/orders[/{id}]` |
| SellerDashboardRepository | `/seller/dashboard` |
| SellerAnalyticsRepository | `/seller/analytics` |
| SellerOnboardingRepository | `/seller/onboarding` |
| SellerVerificationRepository | `/seller/verification/documents` |
| TariffRepository | `/seller/tariff*` |
| ShopSettingsRepository | `/seller/shop` |
| SellerServicesRepository | `/seller/services` |
| SellerReviewsRepository | `/seller/reviews` |

Pattern: abstract + Woody impl + mock. Caching decorator'lar
(`CachedCategoryRepository`, `CachedProductDataSource`, `CachedBannerRepository`)
Hive write-through.

---

## 6. Core / Infratuzilma (`lib/core/`)

### 6.1 Auth (`lib/auth/` + `core/auth/`)
- **AuthCubit** — telefon → OTP → profil; token store o'zgarishini kuzatadi,
  realtime start/stop. **AppModeCubit** — rejimni Hive'ga saqlaydi, security guard.
- **AuthSheetController** — state machine (phone → OTP → profile → done),
  `showAuthScreen()` full-screen modal. PhoneStep/OtpStep/ProfileStep (`auth/sheets/`).
- **OTP autofill:** iOS QuickType (`AutofillHints.oneTimeCode` + `AutofillGroup`);
  Android `smart_auth` SMS User Consent (OTP so'ralganda boshlanadi → auto-submit).
  User Consent (Retriever emas), chunki Eskiz template'da boshqa app signature hash.
- Auth endpoint'lar: `/auth/otp/request`, `/auth/otp/verify`, `/auth/refresh`,
  `/auth/logout`.

### 6.2 DI (`core/di/service_locator.dart`)
Modullar: **CoreModule** (Hive box'lar, TokenStore, WoodyApiClient, R2UploadClient,
ThemeCubit, AppModeCubit, WoodyRealtimeService), **AuthModule** (AuthCubit, PushService),
**CatalogModule** (data source'lar, AnalyticsService, root-scoped NotificationsCubit),
**SellerModule** (seller repo'lar), **ScopeModule** (customer/seller scope BLoC'lar).

### 6.3 Realtime (`core/realtime/woody_realtime_service.dart`)
Bitta WebSocket → `wss://api.woody.uz/api/v1/realtime/ws` (JWT). Per-user
`user:<id>:events`, `type` bo'yicha routing, `eventsOfType(String)` subscriber.
Exponential backoff reconnect. Hodisalar: `notification_created`, `chat_message`,
`chat_read_receipt`, `order_status_changed`. **Graceful fallback:** refresh-on-open
+ FCM agar WebSocket yo'q.

### 6.4 Push (`core/notifications/`)
**PushService** — FCM listener'lar (`onMessage`, `onMessageOpenedApp`,
`getInitialMessage`, `onTokenRefresh`); foreground push flutter_local_notifications
orqali tray'da; device-token `POST /customer/push/device-tokens`. `news` topic boot'da.
**NotificationHandler** — tap → pending route (DeepLinkService).

### 6.5 Analytics & Crashlytics
`AnalyticsService` (abstract + Firebase + Noop), constructor inject, har doim
`unawaited(_analytics?.foo(...))`. Crashlytics `main.dart`'da `_bootstrapAndRun`'dan
oldin; `FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`,
`CrashlyticsTalkerObserver`. Faqat `!kDebugMode`.

---

## 7. API Klient & Upload

### WoodyApiClient (`core/network/`)
Dio wrapper, base `AppConfig.woodyApiUrl` + `/api/v1`. `_AuthInterceptor`:
`Bearer` inject, 401'da single-flight `/auth/refresh` + replay. `ApiError`:
FastAPI `{detail}` envelope, `Retry-After` → `retryAfterSeconds`, network error.
`TokenStore` — secure storage, `changes` stream (realtime start/stop).

### R2UploadClient (`core/storage/`)
Two-step: `POST /storage/upload-url` (presigned PUT) → R2'ga PUT. `R2Bucket` enum:
`product-images`, `shop-assets`, `chat-attachments`, `seller-documents`,
`verification-docs`, `payment-receipts`, `user-avatars`. `R2UploadResult` →
public bucket'lar uchun `publicUrl`.

---

## 8. Testing

41 fayl (~5K LOC). bloc_test + mocktail, abstract repo mock, `registerFallbackValue`
majburiy. Coverage: core (auth_cubit, app_mode_cubit, mode_switching, api refresh,
network, theme, i18n parity), shared (repo contract, notifications, chat thread),
seller (profile, orders, onboarding, analytics, verification, settings/services),
widget (auth sheet, polish). Noop analytics — test Firebase'ga tegmaydi.
**Skip bilan yashil bo'lma.**

---

## 9. Build & Release

```bash
flutter run --dart-define-from-file=env/prod.json     # dev
./tools/build_release.sh                              # release AAB (preferred)
#  = flutter build appbundle --release --dart-define-from-file=env/prod.json \
#      --obfuscate --split-debug-info=build/symbols
flutter test ; dart analyze lib/
```
- Play Console'ga push'dan oldin `pubspec.yaml` `version` bump (`+N`).
- `--dart-define-from-file` siz release **jimgina ishlamaydi** — `build_release.sh`.
- Commit qilma: `env/prod.json`, `key.properties`, `*.jks`, `build/symbols/`.

---

## 10. Kelajak Ishlar (next-stage)

| # | Ish | Tafsilot |
|---|---|---|
| 1 | **To'lov gateway klient** | Checkout payment-type tanlash bor; Click/Payme flow backend API kelganda |
| 2 | **Broadcast ekranlar** | `BroadcastPlaceholderScreen` o'rniga promo/news/system-alert UI |
| 3 | **Realtime chat subscriptions** | Hozir `notification_created` orqali; `subscribe_chat` backend Phase 8.1'da |
| 4 | **Seller verification resubmit** | Rad etilganda qayta topshirish/appeal (backend support TBD) |
| 5 | **Shop sahifa** | `shop_translations.coming_soon` — sotuvchi do'kon ko'rinishi |
| 6 | **Guest cart / offline** | Hozir savat faqat server-side sync |
| 7 | **MyID verifikatsiya** | Manual KYC ishlaydi; MyID V2 |

---

## 11. Saqlash Kerak Bo'lgan Invariantlar (What NOT to do)

- Rang qattiq yozma — token bag (`PremiumTokens`, `AuthTokens`, ...).
- Supabase'ni qaytarma — `grep -i supabase lib/` nol bo'lishi shart, `supabase_flutter` yo'q.
- Sentry'ni qaytarma — Crashlytics bilan `FlutterError.onError`'da to'qnashadi.
- Raw SQL yozma — schema `woody_backend`'da; yangi data → avval backend endpoint.
- Yarim tarjima ship qilma — boot crash.
- `version` bump'siz Play Console'ga push qilma.
- Enum'lar backend + admin bilan ko'zgu — bir tomonni o'zgartirsang, uchchalasini.

---

**Hujjat oxiri.** Yangilanishlar `CLAUDE.md` + `.claude/rules/`'ga ham tegishli.

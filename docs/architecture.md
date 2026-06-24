# Architecture

> Companion to the root [`README.md`](../README.md) §3 and the operational brain [`CLAUDE.md`](../CLAUDE.md). Where they disagree, `CLAUDE.md` wins.

`mebellar_app` is a **single Flutter binary** (`woody_app`, app id `com.mebellar.app`, version `1.0.26+26`) that hosts two runtime surfaces — a **customer storefront** and a **seller back-office** — sharing one phone + OTP identity. The only backend is **`woody_backend`** (FastAPI at `api.woody.uz`; REST under `/api/v1` + WebSocket). There is **no Supabase, no Firebase Auth, and no raw Dio/Remote layer**.

## Layering — UI → Logic → Data

```
   UI (Screens / Widgets)
        │   reads state · dispatches events
        ▼
   Logic (flutter_bloc)
        │   Bloc  — event-driven flows (search, cart, orders)
        │   Cubit — single-input commands (profile, checkout, mode)
        ▼
   Data (abstract Repository interface)
        ├── Woody*Repository   ← single REST/WebSocket impl over WoodyApiClient
        └── in-memory mock      ← used by tests
```

A new data need = a new backend endpoint first, then a repository here. Repositories are abstract interfaces; each has exactly one `Woody*Repository` implementation plus an in-memory mock for tests.

## Bootstrap (`lib/main.dart`)

Everything runs inside `runZonedGuarded`:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `AppConfig.assertConfigured()` — fail-fast: aborts boot if a required env key is empty.
3. `assertTranslationsComplete()` — debug-only i18n parity guard (throws if `ru`/`en` drift below the `uz` baseline).
4. `Firebase.initializeApp`
5. Crashlytics wiring — `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded`, and `CrashlyticsTalkerObserver`. Collection is enabled only when `!kDebugMode`; the `environment` custom key tags every report `prod`/`dev`.
6. `Hive.open`
7. DI setup (`service_locator`)
8. Phoenix-wrapped mode router.

## Dependency injection (`lib/core/di/service_locator.dart`, GetIt)

Modules register in a fixed order — **order matters**:

```
registerCoreModule      # Hive boxes, TokenStore, WoodyApiClient, R2UploadClient,
                        #   ThemeCubit, AppModeCubit, WoodyRealtimeService
registerAuthModule
registerCatalogModule   # data sources, AnalyticsService, root-scoped NotificationsCubit,
                        #   AI designer, payments
registerSellerModule
```

`AppModeCubit` is built before the catalog module registers `AnalyticsService`, so it resolves analytics through a **lookup closure** `() => sl<AnalyticsService>()` rather than a direct injection.

### Scopes

- A **root scope** holds cross-cutting singletons (auth, theme, `NotificationsCubit`, AI designer, payments, Hive boxes, realtime).
- A **per-mode scope** (`customer` / `seller`) holds surface-specific blocs and is **swapped on every mode change**. Customer cubits are never registered in the seller scope and vice versa; cross-mode code lives in `lib/shared/`.

## Mode switch

Boot resolves the mode from Hive with a **security guard** that demotes to customer if the cached seller-approval flag is false. `switchAppMode()` persists the mode, swaps the GetIt scope, and `Phoenix.rebirth()`s the subtree. The shared chat module works in both modes via `viewer: ChatSenderRole.customer | .seller`.

## Routing

| Surface | Router | Notes |
| --- | --- | --- |
| Customer | `GoRouter` (`lib/customer/router.dart`) | `FirebaseAnalyticsObserver` attached. Routes: `/`, `/tutorial`, `/onboarding`, `/categories`, `/product-list`, `/product-detail/:id`, `/product/:id`, `/shop/:id`, `/search`, `/chats`, `/orders/:id/chat`, `/support`, `/ai-designer-chat`, `/cart`, `/favorites`, `/checkout`, `/orders`, `/notifications`, `/promo`, `/news`, `/system-alert`. |
| Seller | `StatefulShellRoute` (`lib/seller/seller_router.dart`) | 5 bottom tabs: dashboard, products, orders, analytics, profile. Toggle via `SELLER_USES_GO_ROUTER` (default ON). |

## Networking

`WoodyApiClient` (`lib/core/network/`) wraps Dio over `AppConfig.woodyApiUrl + /api/v1`:

- `_AuthInterceptor` injects the Bearer token and does **single-flight `/auth/refresh` + replay on 401**.
- A per-request `localeOverride` (carried in `request.extra`) wins over the live `Accept-Language` — used so OTP SMS is sent in the right language.
- `NetworkLoggerInterceptor` is attached to **all** Dio clients (Woody API, R2 upload, CBU feed) but is **debug-only** (`kDebugMode`-gated, never logs in release).
- `TokenStore` (flutter_secure_storage) exposes a `changes` stream that starts/stops realtime.
- Uploads go through `R2UploadClient` — a two-step `POST /storage/upload-url` presigned PUT keyed by the `R2Bucket` enum: `product-images`, `shop-assets`, `chat-attachments`, `seller-documents`, `verification-docs`, `payment-receipts`, `user-avatars`, `product-ar-scans`, `ai-chat-images`.

## Realtime

`WoodyRealtimeService` holds one WebSocket to `wss://api.woody.uz/api/v1/realtime/ws`, routes per-user by `type`, and reconnects with exponential backoff. Events: `notification_created`, `chat_message`, `chat_read_receipt`, `order_status_changed`. It degrades gracefully to refresh-on-open + FCM foreground push when the socket is unavailable.

## Theming

Light + dark. Every surface/text/border/fill colour comes from a token bag — never a const literal:

- `PremiumTokens.of(context)` — customer screens.
- `AuthTokens.of(context)` — auth sheet.
- `kInk`, `kDivider`, … — seller order details (`order_details_kit.dart`).

Brand accent `kTerracotta` / `PremiumTokens.accent` = `#C27A5F` is a constant (does not flip in dark mode). Fonts are bundled native TTF (Inter, Manrope, PlayfairDisplay, PlusJakartaSans) — `google_fonts` is not used.

## Internationalization

Hand-rolled pure-Dart `Map<String, dynamic>` bundles under `lib/core/i18n/translations/` — `uz` baseline + `ru` + `en`, no `.arb`. `_missing_keys_check.dart` throws at boot in debug on parity drift.

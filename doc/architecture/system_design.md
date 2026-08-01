# Woody / Mebellar — System Design & Architecture

> **Status:** Production · **Versiya:** 1.0 · **Sana:** 2026-06-12
> **Doirasi:** Backend (FastAPI), Mobil (Flutter), Admin (Next.js), Marketing (Next.js).
> Mahsulot biznes-qoidalari uchun [TZ.md (master)](../../TZ.md). Rejalar uchun [docs/planning/roadmap.md](../planning/roadmap.md).

Bu hujjat **kanonik arxitektura ko'rinishi**. Har bir biznes-qoida emas, balki *tizim qanday qurilgani* — qatlamlar, holat boshqaruvi, kesh strategiyasi, modal egalik logikasi, tarjima DB strukturasi — bayon qilinadi.

---

## Mundarija

1. [Yuqori-darajali topologiya](#1-yuqori-darajali-topologiya)
2. [Backend arxitekturasi (woody_backend)](#2-backend-arxitekturasi-woody_backend)
3. [Mobil arxitekturasi (mebellar_app)](#3-mobil-arxitekturasi-mebellar_app)
4. [Admin arxitekturasi (woody_admin)](#4-admin-arxitekturasi-woody_admin)
5. [Marketing frontend (woody_frontend)](#5-marketing-frontend-woody_frontend)
6. [Kesishuvchi masalalar](#6-kesishuvchi-masalalar)
7. [Ma'lumotlar modeli](#7-malumotlar-modeli)
8. [Deploy va muhitlar](#8-deploy-va-muhitlar)

---

## 1. Yuqori-darajali topologiya

```
                         ┌──────────────────────────────┐
   Flutter (mobil)  ───► │                              │
   Customer + Seller     │      woody_backend           │ ───► Postgres (asyncpg)
                         │      FastAPI · api.woody.uz   │ ───► Cloudflare R2 (presigned)
   Next.js admin    ───► │                              │ ───► Eskiz (OTP SMS)
   admin.woody.uz        │  REST (/api/v1) + WebSocket   │ ───► Firebase FCM (push)
                         │                              │ ───► Azure OpenAI (AI suggest)
   Next.js landing  ───► │                              │ ───► Redis (ixtiyoriy: WS broker)
   woody.uz (public)     │                              │ ───► Payme Merchant API (webhook)
                         └──────────────────────────────┘
```

- **Yagona backend.** Barcha mijozlar (mobil, admin, marketing) faqat woody_backend bilan gaplashadi. Mijozlarda hech qanday to'g'ridan-to'g'ri DB yoki uchinchi-tomon SDK (Supabase yo'q).
- **Tashqi integratsiyalar** backend orqali abstraktlanadi: Eskiz, R2, FCM, Azure OpenAI, Meshy, **Payme**, Redis. Click faqat checkout URL mint qiladi (settlement webhook yo'q).
- **Realtime** o'z WebSocket broker'i orqali (Redis bilan multi-worker, yoki in-process single-worker).

---

## 2. Backend arxitekturasi (woody_backend)

### 2.1 Qatlamlash

```
HTTP/WS marshruti (app/api/v1/*.py)        ← FastAPI router, async def, guard (require_admin/require_role)
   │
Domen + xizmatlar (app/services/*, app/domain/*)   ← biznes-logika, holat-mashinalari, sweeper'lar
   │
Repozitoriylar                              ← parametrli asyncpg so'rovlari
   │
DatabasePool (app/clients/database.py)      ← process-singleton, lifespan ochadi
   │
Postgres                                    ← Alembic-boshqariladigan schema
```

- **To'liq async.** Handler'larda sync I/O yo'q. `DatabasePool` — lifespan ochadigan process-singleton; repozitoriylar ulanish oladi va parametrli so'rovlar yuradi. Prepared-statement kesh asyncpg ulanish darajasida.
- **SQLAlchemy faqat Alembic uchun** ishlatiladi (runtime so'rovlar xom asyncpg).
- **32 ta router** `api_router`da o'rnatilgan: `health, me, auth, catalog, customer, seller, chat, dashboard, orders, products, sellers, categories, tariffs, wallets, storage, user_storage, realtime, customers, shops, reviews, banners, news, admin_notifications, analytics, achievements, settings, managers`.
- **Prefiks konvensiyalari:** `/auth` (ochiq), `/catalog` (ochiq), `/customer/*` (user), `/seller/*` (user+owner), `/admin/*` (admin), `/ws/*` (WebSocket).

### 2.2 Autentifikatsiya va RBAC

- **OTP → JWT.** `OtpService` Eskiz dispatch + refresh token boshqaruvini orkestratsiya qiladi. JWT payload: `{sub, phone, role, token_type, jti, iat, exp, iss, aud}`. `token_type` access vs refresh'ni ajratadi (access token `/refresh`da rad etiladi).
- **Effective role har so'rovda qayta hisoblanadi** (`get_effective_role()`), JWT'ga ishonilmaydi. `super_admin` faqat `SUPER_ADMIN_PHONE` mosligida.
- **Scope gating avtomatik:** `require_admin` → `scope_for_admin_path` har bir `/admin/*` marshruti uchun. Guard'ni unutish = xavfsizlik xatosi.

### 2.3 Background sweeper'lar (asyncio interval loop)

| Sweeper | Vazifa | Interval / qoida |
|---|---|---|
| `NotificationDispatcher` | LISTEN + worker queue + sweep → FCM + WS fan-out; yaroqsiz token tozalash | sweep konfiguratsiyalanadigan |
| `TariffExpirySweeper` | Obuna tugashi: limitdan oshган mahsulotni arxivlash (eng eski avval), free'ga qaytarish, ogohlantirish | 100/batch, `FOR UPDATE` re-check, 5-kun ogohlantirish |
| `WalletDebtSweeper` | Grace lapse → suspension; floor-moved → grace start; tiklanganlarni qayta-faollashtirish | 300s, 100 seller/o'tish |
| `OrderSLASweeper` | `confirmed` dan keyin `deadline_at` o'tgan in-flight buyurtmalarni `is_delayed=true` qilish + seller notify | 3600s, 100/batch; clock faqat `confirmed` da stamp qilinadi |

**SLA jarimalari (0087):** `sellers.sla_penalty_multiplier` katalog reytingini yumshoq pastga tushiradi; `is_suspended_due_to_sla` moderator tomonidan (`PATCH /admin/sellers/{id}/sla-suspend`) yoqiladi va qarz bloklashiga o'xshash hard freeze beradi (`seller_suspended_sla` → 403). Pul jarimasi mavjud wallet `adjustment` orqali.

### 2.8 To'lovlar (Payme live · Click link-only)

- **Payme Merchant API** — `POST /api/v1/webhooks/payme` (`payme_webhook.py` → `PaymeMerchantService` → `PaymeTransactionRepository`). HTTP Basic (`PAYME_MERCHANT_KEY`). Barcha 6 RPC: CheckPerform / Create / Perform / Cancel / Check / GetStatement. Fiscalization (`detail.items` + MXIK) order / AR / tariff / wallet uchun.
- **Deferred order pay:** checkout `payment_method` saqlaydi; seller fee + customer approve → `awaiting_payment`; `POST /orders/{id}/pay/payme` → `checkout.paycom.uz` deep-link; Perform → `paid` + `confirmed` + `stamp_order_deadline`. CheckPerform/Create faqat `awaiting_payment` + `unpaid` qabul qiladi (`-31050` aks holda).
- **Cancel after perform:** order → `payment_status=refunded` + `status=cancelled` (`cancel_reason_code=payment_refunded`, `is_delayed=false`) bir xil DB tranzaksiyasida; `delivered` → `-31007`.
- **Seller self-serve:** tariff `/pay`, AR `/buy`, wallet `/deposit` — xuddi shu `PaymentLinkService` + webhook settlement.
- **Click:** `my.click.uz` URL mint qilinadi; settlement webhook **yo'q** — avto-tasdiq faqat Payme orqali.

Har bir balans mutatsiyasi `apply_wallet_delta()` orqali o'zgarmas ledger qatorini qo'shadi (single choke point).

### 2.4 Storage (Cloudflare R2)

- Presigned URL'lar: PUT TTL **300s**, GET TTL **600s**.
- Bucketlar: `seller-documents, product-images, shop-assets, chat-attachments, payment-receipts, verification-docs`.
  > ⚠️ **Ma'lum drift:** `woody_backend_tz.md` 7-bucket (`user-avatars` bilan), CLAUDE.md 6-bucket sanaydi. Yarashtirilishi kerak (qarang [roadmap](../planning/roadmap.md)).

### 2.5 Realtime (WebSocket broker)

- `RealtimeBroker` — `WebSocketRegistry`ni in-process ushlaydi (dev/single-worker) yoki Redis pub/sub orqali marshrutlaydi (prod/multi-worker). Lifespan `REDIS_URL` bo'yicha shartli ulaydi.
- Bildirishnomalar FCM yuborilgandan keyin broker'ga publish qilinadi.

### 2.6 FCM klient abstraksiyasi

- `FcmClient` Protocol; ikki implementatsiya: `NoOpFcmClient` (dev/CI default) va `FirebaseFcmClient` (`firebase-admin`).
- `send_to_tokens()` — `asyncio.to_thread()` orqali 500/batch chunk; yaroqsiz tokenlar (`UnregisteredError`/`SenderIdMismatchError`) tozalash uchun qaytariladi. `send_to_topic()` — `news` fan-out.

### 2.7 AI product authoring (Azure OpenAI)

- `AzureOpenAIVisionClient` (xom httpx, `/openai/v1` path, `api-key:` header — Bearer emas). Model `gpt-5-mini`, `reasoning_effort='low'`, `response_format='json_object'`.
- Service promptiga real kategoriya daraxti + atribut sxemasini joylashtiradi. **Har doim 200**, hech qachon avto-saqlamaydi.

---

## 3. Mobil arxitekturasi (mebellar_app)

### 3.1 Holat boshqaruvi — Bloc/Cubit

**Ikki naqsh:** *Cubit* sodda reaktiv holat uchun (auth, mode, theme, network), *Bloc* event-driven oqimlar uchun (cart, favorites, home, orders).

| Holat egasi | Doira | Egalik qiladi |
|---|---|---|
| `AuthCubit` | root singleton | Token hayot-tsikli, `AppAuthState` (Authenticated/Unauthenticated); `TokenStore` oqimini kuzatadi, realtime + analitika bilan koordinatsiya |
| `AppModeCubit` | root | Customer ⇄ Seller rejim; cold-start'da tasdiq flag'i bo'yicha demotion |
| `ThemeCubit` / `NetworkCubit` | root | Tema; tarmoq holati (`initial/online/offline`) |
| `CartBloc` | mode-scoped | `LoadCart, AddToCart, UpdateQuantity, RemoveFromCart, ClearCart`; optimistic + rollback |
| `FavoritesBloc` | mode-scoped | `Set<String>` id; optimistic toggle + re-fetch; auth o'zgarishida refresh |
| `HomeBloc` / `CategoriesBloc` / `ProductListCubit` / `OrdersBloc` | mode-scoped | Kesh-birinchi paint + 5s timeout + 3-tier UX |
| `ChatsListCubit` / `ChatThreadCubit` | shared | Chat hayot-tsikli (customer + seller, `viewer` parametri bilan) |

### 3.2 Ma'lumot qatlami

- **`WoodyApiClient`** — yagona HTTP klient (Dio asosida). Avtomatik **401 → refresh → retry**; token biriktirish `_AuthInterceptor` orqali; normalizatsiyalangan `ApiError`. Handler'lardan to'g'ridan-to'g'ri Dio chaqiruvi yo'q.
- **Tarmoq bardoshliligi:** `GET` exponential backoff (1s/2s/4s, `Retry-After` hurmat qilinadi), transient aniqlash (status==0, 5xx, 429). **POST/PUT/PATCH/DELETE hech qachon retry qilinmaydi** (idempotentlik).
- **`TokenStore`** — `flutter_secure_storage` (Keychain/EncryptedSharedPreferences) ustida broadcast `Stream<TokenPair?>`; `AuthCubit` polling'siz sign-in/out/refresh-failure'ni eshitadi. Muddat 30s grace bilan hisoblanadi.
- **Abstrakt repozitoriylar** + `Woody*Repository` (REST impl) + in-memory mock juftliklari (test uchun).
- **`R2UploadClient`** — presigned PUT/GET (`POST /storage/upload-url`).

### 3.3 Lokal saqlash (Hive)

Yetti box (`CoreBoxes` record): `settings, cache, pendingRoute, onboardingDraft, favorites, cart, newsReads`. `newsReads` — anonim foydalanuvchilar uchun o'qilgan yangilik id'lari (`Set<String>`).

### 3.4 Kesh strategiyasi va 3-tier network UX

> To'liq UX qoidalari [master_tz §11 (arxiv)](../_archive/master_tz_2026_06_12.md#11-tarmoq-barqarorligi-ux-3-tier)da. Arxitektura:

- **`CacheStore`** — Hive asosida, per-entry TTL (ISO8601 timestamp `'${key}__ts'`da), JSON encoding. **Til-scoped:** kalitlarga `@{lang}` qo'shiladi.
- **`CachedProductDataSource` / `CachedBannerRepository` / `CachedCategoryRepository`** — cache-aside; `peek*()` sovuq-start uchun sinxron kesh o'qishi (tarmoqsiz).
- **Holat mashinasi:** `initial → (cache-hit: ready) | (no-cache: loading) → (success: ready) | (timeout/error: failure[cached fallback] | critical[modal])`.
- **5s hard timeout** har bir asosiy ekran blokida (`Duration(seconds: 5)`), Dio timeout'idan qisqa.

### 3.5 Single-owner modal pop logikasi

> Bu naqsh avval hech qayerda hujjatlashtirilmagan edi; bu yerda kanonizatsiya qilinadi.

Bloklovchi tarmoq modali (`FlashscoreNetworkModal`) uchun ilova **bir vaqtda faqat bitta** bloklovchi modal kafolatlaydi:

1. **Owner flag:** `network_error_gate.dart` `_modalOpen` bool ushlaydi. Modal faqat `isCritical(state) && _active && !_modalOpen` bo'lganda ochiladi → stacking yo'q.
2. **Root navigator:** `showNetworkErrorModal(useRootNavigator: true)` — bottom nav/shell scope ustida, faqat bitta root overlay.
3. **Avto-pop:** ochilgandan keyin ichki `BlocListener` `isRecovered`ni kuzatadi va `true` bo'lishi bilan `Navigator.of(modalCtx).pop()` qiladi.
4. **Non-dismissible:** `PopScope(canPop:false)` + `barrierDismissible:false` — foydalanuvchi chetlab o'ta olmaydi; faqat "Qayta urinish" yoki tiklanish modalni yopadi.

> Boshqa modal/bottom-sheet'lar standart `showDialog`/`showModalBottomSheet` ishlatadi; ketma-ket oqim dizayni bir vaqtda bir nechta bloklovchi modal bo'lmasligini ta'minlaydi.

### 3.6 Dual-mode shell, DI scope va routing

- **GetIt service locator:** `initRootScope()` core/auth/catalog/seller modullarini ro'yxatga oladi; `initModeScope(AppMode)` customer/seller-specific blok'larni push qiladi. `switchAppMode()` GetIt scope almashadan keyin `Phoenix.rebirth(context)` qiladi (toza qayta-qurish).
- **Ikki router:** customer (`GoRouter`) va seller (`StatefulShellRoute` — 5 ta persistent tab). Shared chat ikkalasida `viewer: ChatSenderRole` parametri orqali ishlaydi.

### 3.7 Tema va lokalizatsiya

- Tema token'lari (PremiumTokens, AuthTokens, seller `kInk/kDivider`); hardcoded hex taqiqlangan. Light + dark.
- i18n Dart bundle'lar; 3 til; debug'da yo'q ru/en kalit = boot crash. `WoodyApiClient._locale` closure har so'rovga `Accept-Language` (bare kod) bosadi.

---

## 4. Admin arxitekturasi (woody_admin)

- **Next.js 16 App Router, server-first (React 19).** Hech qanday client-side state framework. Sahifalar `lib/queries/*` orqali server'da olib keladi; `lib/actions/*` (`'use server'`) POST/PATCH/DELETE qiladi va `revalidatePath()`.
- **`apiFetch<T>()`** — yagona tarmoq nuqtasi (server-only; client componentdan chaqirilsa build'da yiqiladi). 401'da bir marta `/auth/refresh` orqali retry; non-2xx'da `ApiError`. `apiFetchOrNull<T>()` detal sahifalar uchun 404 yutadi.
- **Edge gate (`proxy.ts`):** cookie mavjudligini tekshiradi, autentifikatsiyalanmaganni `/login`ga yuboradi. JWT'ni **validatsiya qilmaydi** — avtoritar gate `(admin)/layout`da `requireAdmin()`.
- **RBAC mirror:** `lib/auth/roles.ts` `MODERATOR_SCOPES`ni backend `rbac.py` bilan moslashtiradi. `requireRole()/requirePermission()` har action/query'da.
- **Storage:** `signedStorageUrl()` `/admin/storage/download-url`ga round-trip; banner R2 CORS'dan qochish uchun **server tomonida** PUT.
- **Styling:** Tailwind v4 + shadcn/ui (base-nova), CSS o'zgaruvchilar (`bg-background, bg-card, …`); komponentlarda hardcoded hex yo'q. `components/ui/` qo'lda tahrirlanmaydi (skill orqali qo'shiladi).

---

## 5. Marketing frontend (woody_frontend)

- **Next.js 14, Server Components only**, R3F faqat AI orb uchun. Trilingual landing (`app/[locale]`, middleware cookie → Accept-Language → uz).
- Per-page metadata, `next/image`, cookie-based locale (FOUC yo'q). Docker (port 3003) deploy.
- 7 ta invariant (CLAUDE.md): qo'lda-sinxron dictionary'lar, Server Components, `next/image`, per-page metadata, static-export-mumkin-emas, `.glass` `backdrop-filter`siz, Docker deploy.
- Landing telefon-showcase mebellar_app integration testidan generatsiya qilingan PNG skrinshotlarni ishlatadi (`SCREENSHOT_MODE`).

---

## 6. Kesishuvchi masalalar

### 6.1 Enum sinxronizatsiyasi (uch joy)

`OrderStatus`, `VerificationStatus`, `ProductStatus` uch repoda nusxalanadi:
- Backend: `app/domain/enums.py` (manba haqiqati)
- Mobil: `lib/shared/models/`
- Admin: `lib/enums.ts`

> ⚠️ Avtomatlashtirilgan validatsiya yo'q — qo'lda sinxronlash. Drift xavfi. Kelajakdagi OpenAPI codegen ko'rib chiqilmoqda ([roadmap](../planning/roadmap.md)).

### 6.2 i18n DB strukturasi va end-to-end oqim

> To'liq kontrakt [master_tz §9 (arxiv)](../_archive/master_tz_2026_06_12.md#9-internatsionalizatsiya-i18n-kontraktlari)da. Arxitektura xulosasi:

- **Ikki saqlash shakli:** mahsulot/subkategoriya — `*_i18n` JSONB (faqat ru/en override, uz base ustunda); kategoriya — legacy suffix ustunlar (`name_uz/ru/en`).
- **`MultilingualText`** pydantic modeli `pick_lang()` fallback zanjiri uz→ru→en bilan; `from_suffixed()/to_suffixed()` JSONB ⇄ ustun konvertatsiya.
- **`TranslationPatch`** RFC-7386 merge-patch; **uz hech qachon yozilmaydi** (`extra='forbid'`).
- **Oqim:** Flutter til → `_locale` closure → `Accept-Language` header → backend `parse_accept_language()` → `catalog_repos` `COALESCE(NULLIF(...), base)` rezolyutsiyasi → admin tarjimalari uz'ga tegmaydi.

### 6.3 API kontrakt va xato shakli

- Xatolar HTTP statuslarga normalizatsiyalanadi; mijozlar `ApiError`ni mahalliylashtiradi (`apiErrorMessage(e)` → i18n kalit).
- Bloklash = 403 (`AccountBlocked`), auth muvaffaqiyatsizligi = 401.

---

## 7. Ma'lumotlar modeli

**32 ta jadval** (baseline 29 + kengaytmalar). Asosiylar:

| Domen | Jadvallar |
|---|---|
| Identitet | `profiles` (phone, app_metadata_role, app_metadata_permissions, is_seller_pending, deleted_at, blocked_at), `otp_codes`, `refresh_tokens` |
| Sotuvchi | `sellers` (wallet_balance, credit_limit, is_suspended_due_to_debt, debt_grace_period_until, first_approved_at, sla_penalty_multiplier, is_suspended_due_to_sla), `shops`, `shop_services`, `verification_documents`, `seller_verifications` |
| Katalog | `products` (name, description, name_i18n, description_i18n, status), `product_images`, `product_variants`, `categories`, `subcategories`, `attribute_definitions`, `attribute_options` |
| Savdo | `orders` (payment_provider, payment_status, awaiting_payment, deadline_at, is_delayed), `order_items` (commission_rate), `cart_items`, `favorites`, `reviews`, `payme_transactions` |
| Pul | `subscription_plans`, `subscriptions`, `subscription_history`, `subscription_receipts`, `wallet_transactions`, `wallet_topups`, `wallet_deposits`, `ar_token_purchases` |
| Aloqa | `chats` (order_id UNIQUE), `chat_messages`, `notifications`, `device_tokens`, `banners`, `news` |

**Asosiy indekslar:** `profiles_phone_unique_idx` (partial, live), `sellers_debt_grace_sweep_idx`, `wallet_tx_commission_once_idx` (idempotentlik), `products_status_idx`, `orders_status_idx`, `chats_order_id_idx`.

**Migration'lar:** Alembic, baseline `0001_baseline_schema.sql` (Supabase eksportidan, RLS/auth.users/pg_net olib tashlangan) + `0002`–`0027` kengaytmalar. Joriy: **`0027_seller_wallet`**. `AUTO_MIGRATE` prod'da o'chiq; deploy `woody migrate` ishlatadi.

---

## 8. Deploy va muhitlar

| Komponent | Domen | Deploy (haqiqiy) | Hujjat holati |
|---|---|---|---|
| Backend | api.woody.uz | Docker (`docker compose`) | ⚠️ CLAUDE.md/TZ systemd deydi — yarashtirilishi kerak |
| Admin | admin.woody.uz | Docker | ⚠️ CLAUDE.md/TZ npm+systemd deydi |
| Marketing | woody.uz (port 3003) | Docker (`DEPLOY.md` to'g'ri) | ✅ Yarashtirilgan |

**Muhit kalitlari (asosiy):**
- Backend: `DATABASE_URL`, `JWT_SECRET`, `SUPER_ADMIN_PHONE`, `ESKIZ_*`, `R2_*`, `FCM_SERVICE_ACCOUNT_PATH`, `AI_SUGGEST_ENABLED` + Azure kalitlari, `REDIS_URL` (ixtiyoriy), `WALLET_DEBT_GRACE_HOURS`, `ORDER_SLA_*`, **`PAYME_MERCHANT_ID` / `PAYME_MERCHANT_KEY` / `PAYME_CHECKOUT_BASE` / fiscal MXIK'lar**, `CLICK_MERCHANT_ID` / `CLICK_SERVICE_ID` (deep-link only).
- Mobil: `WOODY_API_URL`, `YANDEX_GEOCODER_API_KEY` (`env/prod.json` majburiy).
- Admin: `NEXT_PUBLIC_API_URL`, `SUPER_ADMIN_PHONE`.

> **Ma'lum texnik qarz:** deploy hujjat drift'i (Docker vs systemd) backend va admin'da hali yarashtirilmagan. Batafsil [roadmap](../planning/roadmap.md).

---

## Component-spec havolalar

| Komponent | Deep-dive |
|---|---|
| Backend | `woody_backend/woody_backend_tz.md`, `woody_backend/CLAUDE.md` |
| Admin | `woody_admin/woody_admin_tz.md`, `woody_admin/CLAUDE.md` |
| Mobil | `mebellar_app/woody_mobile_tz.md`, `mebellar_app/CLAUDE.md` |
| Marketing | `woody_frontend/CLAUDE.md`, `woody_frontend/DEPLOY.md` |

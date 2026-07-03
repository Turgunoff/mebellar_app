# Woody / Mebellar — Full Project Context

> **Purpose of this document.** A single, self-contained briefing on the entire Woody
> (Mebellar) furniture-marketplace ecosystem, written to be handed to an AI agent that
> has **no prior knowledge** of the codebase. It covers all four sub-projects (backend,
> admin, marketing site, mobile app), how they fit together, the data model, the API
> surface, integrations, deployment, and how to run each piece locally.
>
> Generated 2026-07-03 from a fresh code analysis of all four repositories. Treat
> versions/counts as accurate-at-time-of-writing snapshots; verify against the live
> source before relying on exact numbers.

---

## 1. What Woody Is

**Woody** (internal/legacy name **Mebellar**) is a furniture e-commerce **marketplace for
Uzbekistan**. Sellers (furniture shops/workshops) list products; customers browse, place
orders, chat with sellers, and visualize furniture in their own rooms using **AR / 3D**.
The platform is trilingual (**Uzbek / Russian / English**) and integrates with local
fintech (Payme/Click), the local SMS gateway (Eskiz), and AI services (Azure OpenAI for an
AI Interior Designer + product authoring; Meshy for photo-to-3D model generation).

### Standout / differentiating features
- **Phone + OTP passwordless auth** (no email/password) via Eskiz SMS.
- **AR furniture preview**: buyers place real-scale 3D models in their room (native ARCore/ARKit) or view them in a WebGL viewer; furniture **sets** support multi-object placement.
- **Admin-mediated photo-to-3D pipeline**: sellers *request* a 3D model per product part → admin picks photos and sends to Meshy → `.glb` auto-generated → admin QC → available to buyers. Monetized per AR "token" (first request per part free).
- **AI Interior Designer**: customers chat + upload a room photo → grounded furniture recommendations from the live catalog (vision + RAG over products).
- **AI product authoring**: sellers upload product photos → vision model pre-fills the product card (category, attributes, colors, dimensions).
- **Deferred online payment**: seller accepts order → customer pays exact total (delivery fee locked in at acceptance) via Payme/Click deep link; cash orders skip straight to `confirmed`.
- **Seller tariffs/subscriptions**, **seller wallet** with commission + soft-freeze, **trial bonus**, **support chat**, **FCM notifications**, **realtime chat**, **marketplace health analytics** (retention, cohorts, product views, seller health), **GA4 app-usage dashboard**.

---

## 2. The Four Sub-Projects (Monorepo-ish Layout)

The working tree at `/Volumes/Storage/Projects/Mebellar/` is **not** a single git repo. It is
an umbrella folder containing **four independent git repositories**, each with its own
GitHub remote, CI, and deployment:

| Folder | Repo (GitHub: `Turgunoff/…`) | Stack | Role | Prod host |
|---|---|---|---|---|
| `woody_backend/` | `woody_backend` | Python 3.11+ / FastAPI (async) | **Single source of truth** API + DB + auth + storage + realtime | `api.woody.uz` |
| `mebellar_app/` | `mebellar_app` | Flutter (Dart) | Customer + Seller mobile app | Google Play / App Store |
| `woody_admin/` | `woody_admin` | Next.js 16 / React 19 | Internal admin & moderation panel | `admin.woody.uz` |
| `woody_frontend/` | `woody_frontend` | Next.js 14 / React 18 | Public marketing landing (3D, trilingual) | `woody.uz` |

Umbrella-level docs also live at the root: `TZ.md` (master spec), `README.md`, and a
canonical `docs/` folder (`architecture/`, `design/`, `planning/`, plus `_archive/` of
retired Supabase-era specs).

### High-level data flow

```
                       ┌────────────────────────────┐
   Customers ─────────▶│        mebellar_app        │
   Sellers   ─────────▶│   (Flutter, one binary)    │
                       └──────────────┬─────────────┘
                                      │ HTTPS REST + WSS
                                      ▼
   Admins/Moderators ──▶ woody_admin ─┼─▶  woody_backend  ◀── Payme webhook
   (Next.js, SSR)                     │   (FastAPI async)  ◀── Meshy AR callback
                                      │        │
   Public visitors ────▶ woody_frontend        │ owns:
   (Next.js, static-ish, no API)               ├─ PostgreSQL (+pgvector)
                                                ├─ Cloudflare R2 (object storage)
                                                ├─ JWT auth (OTP via Eskiz)
                                                ├─ Realtime (in-proc / Redis)
                                                └─ Integrations: Eskiz, Payme/Click,
                                                   Meshy, Azure OpenAI/Vision, Firebase FCM,
                                                   GA4 (via Cloud Run proxy)
```

**Key architectural fact:** `woody_backend` is the only thing that touches the database,
storage, or auth secrets. The Flutter app and the admin panel are **pure API clients** —
they hold no DB credentials. The marketing site makes **no API calls at all**.

### Cross-repo contracts you must keep in sync
- **Enums** are mirrored in three places — change one, change all:
  - Backend: `woody_backend/app/domain/enums.py`
  - Admin: `woody_admin/lib/enums.ts` (Zod)
  - App: Dart enums in `mebellar_app/lib/...`
- **RBAC** roles/scopes mirrored in `woody_backend/app/security/rbac.py` and
  `woody_admin/lib/auth/roles.ts`. Backend is authoritative; admin guards are fast redirects + defence-in-depth.

---

## 3. Backend — `woody_backend` (FastAPI)

### 3.1 Stack
- **Python ≥ 3.11** (CI on 3.12), build backend **Hatchling**, CLI entry `woody`.
- **FastAPI** (async), **uvicorn[standard]**, **pydantic v2** + **pydantic-settings**.
- **asyncpg** is the only runtime DB driver (raw, parametrized SQL — no ORM at runtime).
  SQLAlchemy/psycopg exist **only** for Alembic migration scaffolding.
- **pgvector** for embeddings (text + image RAG/dedupe).
- **httpx** for all external clients (no vendor SDKs except `firebase-admin`, `boto3`).
- **PyJWT** (HS256) access + refresh tokens.
- **Alembic** migrations. **boto3** → Cloudflare R2 (S3-compatible). **redis** (optional) for multi-worker WebSocket fan-out.
- Lint/format: **ruff** (note: repo is *not* fully ruff-clean — pre-existing `N818` on the AuthError hierarchy is intentional; match existing style, don't bulk-reformat).

### 3.2 Layout (`app/`)
- `main.py` — `create_app()` factory + lifespan (opens DB pool, broker, dispatcher, AR worker).
- `settings.py` — `Settings` (pydantic-settings), `get_settings()` cached. `.env.example` is canonical.
- `cli.py` — `woody migrate|downgrade|current|history|serve|seed-tariffs|seed-achievements`.
- `deps.py` / `deps_auth.py` / `deps_read.py` — auth guards (`get_current_user`, `require_admin`, `require_role`) and DI wiring.
- `api/v1/` — **37 routers** (see API surface below).
- `security/` — `jwt.py`, `otp.py` (HMAC-SHA256 + per-row salt), `phones.py` (E.164), `rbac.py`.
- `services/` — repositories (read/write split behind Protocols), OTP, notifications dispatcher, realtime broker, AI suggest, AI designer, AR pipeline worker, payment links, tariff expiry sweeper, wallet/debt sweeper, embeddings, Payme merchant state machine, product views, achievements seed, tariffs seed.
- `clients/` — `database.py`, `eskiz.py`, `storage.py` (R2), `fcm.py`, `meshy.py`, `azure_openai.py`, `azure_embeddings.py`, `azure_vision_embeddings.py`, `ga4_proxy.py`.
- `domain/` — pydantic models, `enums.py`, `i18n.py` (`MultilingualText` uz/ru/en), AR token pricing, Payme fiscal constants, `engagement.py`, `marketplace_analytics.py`.
- `utils/` — GLB→USDZ conversion (iOS AR), GLB compression.
- `ga4_proxy/` — standalone Cloud Run service (GA4 Data API reader; no JSON keys on `api.woody.uz`).
- `alembic/versions/` — **80 migrations (0001–0080)**; heavy DDL kept in hand-written `sql/` files.

### 3.3 Database (PostgreSQL + pgvector)
- Requires the `pgvector` extension (e.g. `pgvector/pgvector:pg16`/`pg17` Docker image). Migration 0044 enables it; later migrations add `products.embedding` (text, 1536) and `products.image_embedding` (visual, 1024).
- **80 Alembic migrations**, every one with both `upgrade()` and `downgrade()` (verified by `tests/test_migrations.py`).
- **Core tables (30+):**
  - **Auth:** `profiles` (phone, role, app_metadata), `otp_codes`, `refresh_tokens`, `device_tokens`.
  - **Catalog:** `categories`, `subcategories`, `products` (incl. `ar_model_url`, `max_delivery_fee`, embeddings), `product_attributes`, `product_images`, `product_colors`, `product_sets` + `set_items`, `product_views` (impression events).
  - **Commerce:** `orders`, `order_items`, order status history, `tariff_plans`, `subscription_receipts`.
  - **Seller:** `shops`, `seller_wallets`, `wallet_transactions`, `wallet_deposits`.
  - **Reviews:** `reviews` (+ moderation), attachments.
  - **Chat:** seller↔customer rooms + messages + attachments; **support** chats (customer↔admin) separate.
  - **AR:** `product_ar_parts` (per-part models + request states), AR token purchases/grants.
  - **AI:** `ai_chat_logs` (no image stored, `has_image` flag only; optional `image_url` for admin review).
  - **Payments:** Payme transactions (fiscalization), payment/checkout state.
  - **Notifications:** `notifications` (coarse `notification_type` generated column for inbox tabs).
  - **Achievements:** seller milestone catalogue + per-seller unlock rows.

### 3.4 API surface (all under `/api/v1`)
Logical groups (base paths + representative endpoints):

- **Health:** `GET /health` (unauthenticated).
- **Auth (OTP+JWT):** `POST /auth/otp/request {phone,lang}`, `POST /auth/otp/verify {phone,code}` → token pair, `POST /auth/refresh`, `POST /auth/logout`. `GET /me` resolves effective role per-request. Optional `REVIEW_TEST_PHONE`/`REVIEW_TEST_OTP` bypass for app-store review (off by default).
- **Catalog (public/customer):** `GET /catalog/categories`, `GET /catalog/products` (search/filter/sort/paginate), `GET /catalog/products/{id}`, `POST /catalog/products/{id}/view` (record impression, deduped 30 min/viewer), `/catalog/attributes` (public), product reviews. Public settings: `GET /catalog/settings/maintenance`, `…/support_contacts`, `…/payment_methods`.
- **Customer:** `/customer/cart`, `/customer/favorites`, `/customer/orders` (+ create/cancel/cancellation-reasons), `/customer/reviews`, `/customer/payment/checkout-links`, `/customer/storage/upload-url`.
- **Seller:** `/seller/me` (+ `PATCH /seller/me/alerts`), `/seller/shop`, `/seller/products` (CRUD, archive/restore, `POST /seller/products/ai-suggest`), `/seller/products/{id}/ar-request` (request 3D per part — primary AR workflow), `/seller/products/{id}/ar-scan/photos` (legacy direct Meshy scan — still present), `/seller/products/{id}/ar-parts`, `/seller/ar-tokens/*`, `/seller/orders` (+ status incl. `awaiting_payment`, `PATCH …/delivery-fee` locked after acceptance), `/seller/sets`, `/seller/tariff/*`, `/seller/wallet/*`, `/seller/dashboard`, `/seller/analytics`, `/seller/achievements`.
- **Chat:** `GET /chat/rooms`, messages (text/image), `WS /ws/chat/{room_id}`. One chat row per `order_id` (UNIQUE); customer lazy-creates; stays open forever.
- **AI Designer:** `POST /ai/chat` (room photo + text → grounded suggestions), `GET /ai/chat/history`. Gated by `AI_DESIGNER_ENABLED`.
- **Admin / moderation:** `/admin/orders`, `/admin/products` (approve/reject), `/admin/sellers` (verify/suspend/reactivate, KYC docs), `/admin/customers`, `/admin/shops` (unlist/relist), `/admin/categories`, `/admin/tariffs/plans` (CRUD + per-plan AR grant), `/admin/wallets`, `/admin/reviews`, `/admin/notifications/send`, `/admin/settings` (maintenance, support contacts, payment-method toggles, app min-version, receiving card), `/admin/managers` (super_admin only), `/admin/dashboard`, `/admin/analytics` (overview, engagement, retention, cohorts, seller-health, product-views, ar-tokens), `/admin/ar-requests` (AR request queue — send-to-meshy / reject), `/admin/ai/logs`, `/admin/banners`, `/admin/news`, `/admin/sets`, `/admin/support/*`, `/admin/achievements`, `/admin/storage/*` (presigned URLs).
- **Realtime:** `WS /ws/chat/{id}`, `WS /ws/support/{id}`, `WS /ws/notifications`.
- **Webhooks:** `POST /webhooks/payme` (HTTP Basic with `PAYME_MERCHANT_KEY`; 6 RPC methods + fiscalization; handles order payments, AR tokens, and tariff subscriptions), `POST /internal/ar-webhook` (Meshy/AR callback, secret header).

### 3.5 Auth & RBAC
- **Flow:** request OTP (60s cooldown, rate-limited) → SMS via Eskiz (template matched to `Accept-Language`) → verify (5-digit, hashed with per-row salt, TTL 5 min, max 5 attempts) → find-or-create `profiles` row → mint JWT pair.
- **Tokens (HS256):** access ~15 min (customer) / ~1 h (admin); refresh ~30 days. Claims include `sub, phone, role, token_type, jti, iss, aud`; `iss`/`aud` verified.
- **Per-request role resolution (`get_effective_role`)** — the JWT role claim is advisory. On every request: phone == `SUPER_ADMIN_PHONE` → `super_admin`; else `profiles.app_metadata_role == 'manager'` → `manager`; else customer/none.
- **Roles:** `super_admin` (sole source = env phone), `manager` (moderator, optionally scoped via `app_metadata_permissions` jsonb), customer.
- **Delegable scopes:** orders, products, sellers, shops, customers, reviews, categories, analytics, achievements. **Owner-only:** settings, managers, tariffs, wallets, banners, news, notifications, support, ai-logs.
- Deleted/blocked accounts are force-logged-out (per-request gate returns `401 account_inactive`).

### 3.6 Order lifecycle (deferred payment)
- **Cash:** `pending` → seller accepts → `confirmed` → `preparing` → `shipped` → `delivered`.
- **Online (Payme/Click):** `pending` → seller accepts + sets exact delivery fee → `awaiting_payment` (customer notified, pays via deep link) → `confirmed` → …
- Products carry `max_delivery_fee` (seller's estimated range at listing time); exact fee entered per order at acceptance.

### 3.7 Integrations & feature flags
| Integration | Client | Purpose | Key env vars / flags |
|---|---|---|---|
| **Eskiz SMS** | `clients/eskiz.py` | OTP delivery (uz/ru/en templates, Android SMS-Retriever hash `mH1HhnJpGqi`) | `ESKIZ_EMAIL/PASSWORD/SENDER`, `ESKIZ_MESSAGE_TEMPLATE_{UZ,RU,EN}` |
| **Cloudflare R2** | `clients/storage.py` (boto3) | Object storage; presigned PUT(300s)/GET(600s); many buckets | `R2_ENDPOINT_URL`, `R2_ACCESS_KEY_ID/SECRET`, `R2_*_PUBLIC_BASE_URL` |
| **Firebase FCM** | `clients/fcm.py` (firebase-admin; NoOp default) | Push notifications via DB-trigger + dispatcher | `NOTIFICATIONS_ENABLED`, `FCM_SERVICE_ACCOUNT_PATH` |
| **Payme + Click** | payment-link service + `payme_webhook` | Deep-link checkout (no saved cards) + merchant webhook + fiscalization | `PAYME_MERCHANT_ID`, `PAYME_MERCHANT_KEY`, `CLICK_*` |
| **Meshy** | `clients/meshy.py` | Photo→3D `.glb` generation (background poller; admin-triggered from AR-requests queue) | `AR_PIPELINE_ENABLED`, `MESHY_API_KEY`, `MESHY_BASE_URL` |
| **Azure OpenAI** | `clients/azure_openai.py` + embeddings | AI product authoring, AI designer chat, dedupe | `AZURE_OPENAI_ENDPOINT/_API_KEY/_DEPLOYMENT`, `AI_SUGGEST_ENABLED`, `AI_DESIGNER_ENABLED`, `PRODUCT_DEDUPE_ENABLED` |
| **Azure AI Vision** | `clients/azure_vision_embeddings.py` | Multimodal embeddings for visual RAG | `AZURE_VISION_ENDPOINT/_KEY`, `VISUAL_RAG_ENABLED` |
| **GA4 (Cloud Run proxy)** | `clients/ga4_proxy.py` + `ga4_proxy/` service | Mobile app engagement metrics for admin dashboard (no GCP keys on API server) | `GA4_PROXY_URL`, `GA4_PROXY_API_KEY` |
| **Redis** | broker | Multi-worker WebSocket fan-out (in-proc fallback) | `REDIS_URL` |

Required runtime env always: `DATABASE_URL`, `JWT_SECRET`, `SUPER_ADMIN_PHONE`, plus Eskiz + R2.
Most AI/AR/notification/GA4 features are **off by default** and flip on via env flags (graceful degradation: disabled AI endpoints return `available=false`, payment 503s, engagement returns `available=false`, etc.).

### 3.8 Tests & deploy
- **pytest + pytest-asyncio**, **91 test files / ~1300 tests**: endpoint smoke + auth-gate tests, unit (security/services), `test_migrations.py` (up+down), SQL-parse validation (pglast), some integration. Fakes in `tests/_fakes.py` implement repo Protocols (no DB needed for service tests).
- **Run:** `.venv/bin/pytest` (or single file). Lint: `ruff check app/ tests/`.
- **Deploy:** push to `main` → GitHub Actions `deploy.yml` → SSH → `git reset --hard origin/main` → docker compose rebuild → `woody migrate` → health-check `…/api/v1/docs`. Prod on `api.woody.uz` (port 4001 behind nginx). **No path filter** — any push to backend main redeploys prod.

### 3.9 Run locally
```bash
python3.11 -m venv .venv && .venv/bin/pip install -e '.[dev]'
cp .env.example .env   # fill DATABASE_URL, JWT_SECRET, SUPER_ADMIN_PHONE, ESKIZ_*, R2_*
.venv/bin/woody migrate
.venv/bin/woody serve --reload --port 8000
# OpenAPI docs: http://127.0.0.1:8000/api/v1/docs
```

---

## 4. Mobile App — `mebellar_app` (Flutter)

### 4.1 Stack
- **Flutter, Dart SDK `^3.11.5`**. App package `com.mebellar.app`, internal name `woody_app`.
- **Version `1.0.33+33`** (versionName+versionCode). Android minSdk 26; iOS 15.0+.
- **State:** `flutter_bloc` (Bloc/Cubit) + `bloc_concurrency` + `equatable`. **DI:** `GetIt` with modular registration (`core_module`, `auth_module`, `catalog_module`, `seller_module`, scope modules). **Module order matters.**
- **Routing:** customer uses `go_router`; seller uses `StatefulShellRoute.indexedStack` (5 tabs) — nested pushes must use `rootNavigator: true`. Deferred deep links resolved at boot via `DeferredDeepLinkService`.
- **Networking:** `dio` wrapped in `WoodyApiClient` → base `api.woody.uz` + `/api/v1`; Bearer from `TokenStore` (secure storage); 401 → single `/auth/refresh`, failure → forced sign-out; normalized `ApiError` (handles 429 `Retry-After`). Realtime via `web_socket_channel` (`wss://api.woody.uz/api/v1/realtime/ws`). Uploads via presigned R2 PUT.
- **Local storage:** **Hive** boxes (settings, cache, cart, favorites, newsReads, pendingRoute, onboardingDraft, aiChatHistory) + `flutter_secure_storage` (tokens) + dedicated `GlbCacheManager` for 3D models.
- **Notifications/analytics:** `firebase_messaging`, `flutter_local_notifications`, `app_badge_plus` (launcher badge), `firebase_analytics`, `firebase_crashlytics`, `facebook_app_events` (separate `FacebookAnalyticsService`), App Tracking Transparency. Product detail fires `view_item` + `POST /catalog/products/{id}/view` for DB analytics.
- **AR/3D/media:** `model_viewer_plus` (WebGL `<model-viewer>` in `webview_flutter`), `ar_flutter_plugin_plus` (native ARCore/ARKit multi-object), `camera`/`image_picker`/`flutter_image_compress`, `gal` (save to gallery), `vector_math`.
- **Maps/misc:** `yandex_mapkit` + `geolocator` + `permission_handler`; `flutter_phoenix` (mode-switch restart); `in_app_update`, `in_app_review`, `smart_auth` (OTP autofill), `record`+`just_audio` (voice notes), `fl_chart`, `lottie`.
- **No `google_fonts` package** — TTFs bundled under `assets/google_fonts/` (Inter, Manrope, PlayfairDisplay, PlusJakartaSans).

### 4.2 Architecture (`lib/`)
- `main.dart` (Firebase/Crashlytics/Hive boot) · `config/` · `auth/` (phone→OTP→profile modal).
- `core/` — analytics, auth (`AuthCubit`, `AppModeCubit`), DI, i18n, logging (Talker), maps, notifications (FCM, badge sync, active-chat trackers), realtime, storage, theme, updates, widgets, deeplink.
- `customer/` — `customer_app.dart`, `router.dart`, plus `features/`.
- `seller/` — `seller_app.dart`, `seller_router.dart`, plus `features/`.
- `shared/` — chat (per-order), AR utilities, models, repositories (abstract `Woody*Repository` + impl + in-memory mocks), payments, widgets.

### 4.3 Features
- **Customer:** auth, home feed (carousel + infinite scroll + grid/list + sort), search (adaptive facets), category browse, product detail (AR/3D badge, attributes, reviews, seller contact, self-purchase blocked, view tracking), hybrid cart (local Hive + backend, login gate at checkout), favorites (hybrid, union-merge on login), checkout (address via Yandex Maps → payment method selection → place; deferred payment note for online; split delivery/installation fees, Payme/Click), orders + per-order chat + `awaiting_payment` pay bar, reviews (rating lock, in-app review at 4★+), notifications inbox (tabs: All/Orders/System), profile, AR token wallet (`ArTokensScreen`), **AI Interior Designer** (root-scope singleton, non-blocking UX), support chat (text/image/voice), maintenance overlay (reads `GET /catalog/settings/maintenance` at boot).
- **Seller:** verification/KYC onboarding, dashboard (bonus urgency banner, wallet debt banner, leaderboard, achievements), products CRUD with **AI photo-fill** + **AR request per part** (admin-mediated workflow; first request free), `max_delivery_fee` slider on product form, orders (status timeline incl. `awaiting_payment`, delivery-fee lock), reviews, wallet (balance + transactions + soft-freeze), tariff/subscription, analytics (charts), furniture **sets** (multi-object AR), alert flags (DB-backed), full **dark mode**.
- **AR system:** (1) buyer WebGL viewer (`buyer_ar_viewer_screen.dart`, real-scale, watermarked save-to-gallery); (2) native multi-object set viewer (`set_ar_viewer_screen.dart`, ARCore/ARKit, place/rotate/delete nodes); (3) 2D sticker fallback for non-AR devices. Per-part models, GLB file-cache (`GlbCacheService`, file://), capability gate via `canActivateAR` (not src-mapping).

### 4.4 i18n
- **Custom Dart translation bundles** (no `.arb`) under `lib/core/i18n/translations/` — **29 files**, languages **uz (baseline) / ru / en**. `tr('namespace.key')`, context-free. **Boot guard** throws in debug if ru/en drift below uz. `AppLocaleController` stamps `Accept-Language` on every API call so backend localizes dynamic content too. **Both customer and seller portals are fully localized** (seller copy lives in `seller_translations.dart`, `seller_orders_translations.dart`, `add_product_translations.dart`, `tariff_translations.dart`, etc.).

### 4.5 Release / OTA (Shorebird)
- `shorebird.yaml` app id `c1639a0d-e4a4-4606-bf14-4b4195fa061e`. **Dart-only changes are OTA-patchable**; anything native (new pubspec deps, native plugins like `ar_flutter_plugin_plus`, permission/manifest changes, Flutter SDK bump, new bundled assets) needs a **full store release**.
- Helper scripts: `tools/build_release.sh` (AAB/APK/IPA, non-patchable) and `tools/shorebird.sh` (`release`/`check`/`patch`/`log`). Ledger at `tools/shorebird/releases.md`. Bump `version:` before every store release.
- **iOS specifics:** Flutter SPM **disabled** (avoids Firebase module redefinition); `Podfile.lock` aligned to Firebase 11.15.0. iOS code-share warnings have appeared — next iOS App Store build should be a fresh `shorebird release ios`.

### 4.6 Tests & run
- **Tests:** `flutter_test` + `bloc_test` + `mocktail`, golden tests (tagged `golden`, excluded in CI), `integration_test`. Mock the abstract repo interfaces, never raw `dio`; inject a Noop `AnalyticsService`.
- **Run:** needs `env/prod.json` (`WOODY_API_URL`, `YANDEX_GEOCODER_API_KEY`, optional `PAYME_*`, `SCREENSHOT_MODE`).
  ```bash
  flutter run --dart-define-from-file=env/prod.json
  flutter test                       # full suite
  dart analyze lib/
  ```
- **Modes:** customer (default) ↔ seller, persisted in Hive, switched via `Phoenix.rebirth()`. `SCREENSHOT_MODE=true` powers marketing screenshots reused by `woody_frontend`.

---

## 5. Admin Panel — `woody_admin` (Next.js 16)

### 5.1 Stack
- **Next.js 16 (App Router, RSC by default), React 19, TypeScript strict.** npm.
- **Tailwind v4** + **shadcn/ui** (`base-nova`) + **lucide-react**; tokens in `app/globals.css` (oklch).
- **Zod** for enum validation; **recharts** for analytics; **sonner** toasts; **next-themes**; **@google/model-viewer** for AR `.glb` review.
- Data fetched in Server Components; mutations via `'use server'` actions + `revalidatePath`. No react-query/SWR.

### 5.2 Layout & pages
- `app/login/` — OTP login (server actions `requestOtp`/`verifyOtp`).
- `app/(admin)/` — guarded route group (`layout.tsx` calls `requireAdmin()`):
  - **Delegable (moderator scopes):** `/` dashboard, `/analytics` (platform KPIs), `/app-usage` (GA4 engagement — DAU, sessions, top screens/events), `/marketplace-health` (retention, cohorts, seller health, product-view conversion), `/orders`, `/customers`, `/reviews`, `/products`, `/ar-models` (AR request queue + per-part approve/reject/send-to-meshy + 3D viewer), `/sets`, `/categories` (multilingual), `/shops`, `/sellers` (verification + KYC docs), `/achievements`.
  - **Owner-only (super_admin):** `/banners`, `/news`, `/notifications`, `/tariffs` (plans CRUD + master on/off + per-plan AR grant), `/wallets` (top-ups + online payments moderation), `/support`, `/ai-logs`, `/managers` (scope delegation), `/settings` (typed GUI: receiving card, app min-version, maintenance mode, support contacts, payment-method toggles).
- `lib/api/client.ts` — `apiFetch<T>` (Bearer from httpOnly cookie, throws `ApiError`). `lib/queries/*` (reads), `lib/actions/*` (writes). `lib/auth/admin-guard.ts` (`requireAdmin/requireRole/requirePermission`), `lib/auth/roles.ts` (RBAC mirror). `lib/enums.ts`, `lib/i18n.ts` (`pickLang` uz→ru→en), `lib/storage.ts` (signed R2 URLs).
- `proxy.ts` — edge middleware, cheap cookie-presence gate (not JWT validation).
- `components/admin/` — `sidebar-nav` (role/scope gating, grouped nav), `status-badge`, `safe-image` (fallback), `banner-form`, `category-form`, `ar-requests-table`, engagement charts, marketplace-health panels, row-action components.

### 5.3 Auth & integration
- OTP login → JWT pair stored as **httpOnly cookies**. `GET /me` returns `{user_id, phone, role, permissions}`. `hasPermission(role, permissions, scope)`: super_admin → all; manager + `null` permissions → full moderator; manager + array → scope must be listed.
- All data/auth from `woody_backend` (`NEXT_PUBLIC_API_URL`, e.g. `https://api.woody.uz`). Banner uploads PUT server-side to R2 (sidesteps CORS). Image hostnames allowlisted in `next.config.ts`; CSP strict; 50 MB body limit.

### 5.4 Deploy & run
- Push `main` → GitHub Actions `deploy.yml` → SSH → `git reset --hard origin/main` → `docker compose up -d --build admin_panel` → health-check `127.0.0.1:3002`. Host `admin.woody.uz` (nginx). **Deploys that change schema need `woody migrate` on the backend.**
- Env: `NEXT_PUBLIC_API_URL` (required), `NEXT_PUBLIC_IMAGE_HOSTNAMES` (optional).
  ```bash
  npm install && npm run dev   # http://localhost:3000
  npm run build && npm start
  npm run lint && npx tsc --noEmit
  ```

---

## 6. Marketing Site — `woody_frontend` (Next.js 14)

### 6.1 Purpose & stack
- Public **trilingual (uz/ru/en) marketing landing** for `woody.uz`. **No API calls, no auth, no secrets** — pure content + app-download CTAs. Deep links `/product/[id]` and `/shop/[id]` redirect to the stores.
- **Next.js 14.2 (App Router), React 18, TypeScript strict, Tailwind 3.4, framer-motion.** npm with `.npmrc` `legacy-peer-deps=true` (model-viewer ↔ three peer mismatch; no runtime conflict — model-viewer bundles its own three).
- **3D:** hero chair rendered with **@google/model-viewer** (bundled `public/models/hero_chair.glb`, ~3.2 MB, quantized + WebP, no Draco). The **AI orb** uses react-three-fiber/drei + three 0.169. (model-viewer is used for the chair because R3F flattened the Meshy albedo/wood texture.)
- **Fonts:** Lora (serif display) + Poppins (sans) via `next/font/google`, self-hosted.

### 6.2 Brand & structure
- **2026 brandbook:** terracotta `#C2703D` primary accent, charcoal text, warm bone/sand surfaces; 60·30·10 rule; radius tokens (input 10 / button 12 / card 16 / sheet 24). Locked in `tailwind.config.ts` + `globals.css`.
- Routes under `app/[locale]/`: home (hero + sections), `buyers`, `sellers`, `ai`, `pricing`, `product/[id]`, `shop/[id]`, `privacy`, `terms`, `data-deletion`. Locale resolved in `middleware.ts` (cookie `woody.locale` → `Accept-Language` → default `uz`).
- `lib/i18n/dictionaries.ts` holds uz/ru/en copy (ru/en typed `typeof uz` — shape-checked; sync by hand). `InteractivePhoneShowcase` reuses **real app screenshots** exported from the `mebellar_app` integration-test pipeline.
- **Strict CSP** (enforced) in `next.config.mjs`: includes `'wasm-unsafe-eval'` (model-viewer WASM) and `connect-src 'self' blob:` (texture streaming). `output: 'standalone'` (static export impossible because of locale middleware).

### 6.3 Deploy & run
- Push `main` → GitHub Actions (`ci.yml` typecheck/lint/build; `deploy.yml` SSH → `docker compose up -d --build frontend`, health-check `127.0.0.1:3003`). Host `woody.uz` (nginx, 3-stage Alpine Dockerfile, non-root).
  ```bash
  npm install && npm run dev      # http://localhost:3000 → redirects to /uz
  npm run build && npm start      # port 3003
  ```

---

## 7. Cross-Cutting Notes for an Incoming Agent

- **Backend is canonical.** Any behavior change usually starts in `woody_backend` (route + migration + tests), then mirrors into the app and admin (enums, request/response shapes). The marketing site is independent.
- **Migrations are first-class.** Schema changes go through Alembic with up+down; prod deploy runs `woody migrate`. Never hand-edit prod schema.
- **Feature flags gate the expensive integrations** (AI, AR, FCM, payments, GA4). In dev they're off and endpoints degrade gracefully; don't assume a feature is "broken" if its flag/key is unset.
- **Three-way enum + RBAC sync** is a recurring footgun — see §2.
- **AR workflow is admin-mediated.** Sellers `POST …/ar-request`; admin picks photos and `POST …/send-to-meshy` from `/admin/ar-requests`. The legacy seller-direct `ar-scan/photos` path still exists but is not the primary flow.
- **Deferred payment** is live: online orders pause at `awaiting_payment` until the customer pays the seller-locked total.
- **Mobile OTA discipline:** prefer Dart-only changes for Shorebird patches; native changes force a full store release. iOS has the SPM-disabled / Firebase-pods caveat.
- **Secrets live only in the backend** (and CI). The app ships `env/*.json` (non-secret URLs/keys), admin uses httpOnly cookies, frontend has none. GA4 credentials stay on Cloud Run, not `api.woody.uz`.
- **Languages:** product is uz/ru/en; backend localizes dynamic content via `Accept-Language`; OTP SMS has three Eskiz templates. The repo owner communicates in Uzbek (mixed technical English).

### Repo quick-reference
| Repo | Test cmd | Lint/Type | Deploy trigger | Prod |
|---|---|---|---|---|
| woody_backend | `.venv/bin/pytest` | `ruff check` | push `main` | api.woody.uz |
| mebellar_app | `flutter test` | `dart analyze` | manual store/Shorebird | Play / App Store |
| woody_admin | (tsc/lint) | `npm run lint`, `tsc --noEmit` | push `main` | admin.woody.uz |
| woody_frontend | (build) | `npm run lint`, `tsc` | push `main` | woody.uz |

### Glossary
- **Woody / Mebellar** — same product (Woody is the brand, Mebellar the legacy name).
- **Seller** — furniture shop/workshop; **Customer** — buyer; **Manager** — scoped moderator; **super_admin** — single owner (env phone).
- **AR token** — unit of currency for generating/placing 3D models; first part request free, re-requests token-priced.
- **Set** — a furniture bundle (e.g. bedroom set) that supports multi-object AR placement.
- **Tariff** — seller subscription plan (limits, AR grant, AI quotas, features); paid via Payme webhook or receipt upload + admin moderation.
- **Deferred payment** — online checkout where the customer pays only after the seller accepts and sets the exact delivery fee (`awaiting_payment` status).
- **GA4 proxy** — Cloud Run microservice (`ga4_proxy/`) that reads Firebase Analytics / GA4 and exposes engagement metrics to the backend without GCP JSON keys on the API server.

---

*End of context document.*

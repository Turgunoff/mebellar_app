# ROADMAP.md — Engineering State & Remaining Work

> **Rewritten from scratch · 2026-05-16.**
> This roadmap reflects a deliberate strategic pivot: **all DevOps, CI/CD, App Store / Play Store release, and marketing work is out of scope.** The sole focus is **code completion, bug resolution, and architectural quality** — getting the app *functionally perfect* as a piece of software.
>
> - **Part 1** — what has been engineered so far (context for new developers).
> - **Part 2** — the remaining pure coding / architectural tasks.
>
> Companion docs: [`README.md`](./README.md) · [`docs/PROJECT_STATE_ANALYSIS.md`](./docs/PROJECT_STATE_ANALYSIS.md) · [`ARCHITECTURE.md`](./ARCHITECTURE.md).

---

# Part 1 — Completed Engineering

Everything below is **built, tested, and merged**. `dart analyze` is clean; **192 tests pass**.

## 1.1 Foundation & Architecture

- ✅ **Layered architecture** — UI → Logic (BLoC/Cubit) → Data (Repository) — applied consistently across 360 Dart files.
- ✅ **`Result<T, Failure>` pattern** — typed success/error returns at repository boundaries (`core/result/`, `core/error/failure.dart`).
- ✅ **`RepositoryResolver`** — runtime mock-vs-live repository selection driven by `AppConfig.useMocks`; mock graph tree-shaken out of release builds.
- ✅ **Scoped dependency injection** (`get_it`) — root scope (cross-cutting singletons) + per-mode scope (`customer`/`seller`); registration modularised into `core/di/*_module.dart`.
- ✅ **Runtime mode switch** — `AppModeCubit` + `flutter_phoenix`: DI scope swap + `Phoenix.rebirth()` flips customer ↔ seller without re-install.
- ✅ **`AppConfig` + fail-fast config** — no compiled-in secret defaults; `assertConfigured()` aborts a misconfigured build loudly.
- ✅ **Backbone refactor** — `service_locator` modularisation, `RealtimeService`, `AppSettings`, central `Result` type.

## 1.2 Authentication

- ✅ Email + OTP sign-in, registration, email verification, forgot-password flows.
- ✅ Auth bottom-sheet flow (email step → OTP step → profile step) with extracted widget sub-tree.
- ✅ Supabase `AuthException` codes mapped to localised user messages (`invalid_credentials`, `email_not_confirmed`, `over_email_send_rate_limit`).
- ✅ Forgot-password follows OWASP guidance — success state shown without revealing whether the email exists.
- ✅ Ghost-session recovery — a missing `profiles` row forces a clean sign-out.

## 1.3 Customer Surface

- ✅ Home screen — banners, premium blocks, categories grid, featured shops.
- ✅ Catalog, multi-level categories, per-category product list, product detail (gallery, attributes, expandable description).
- ✅ Search with debounced/restartable query handling.
- ✅ Favorites and Cart — **hybrid repositories** (Hive offline + Supabase sync).
- ✅ Checkout — multi-step flow with a Yandex-map address picker.
- ✅ Orders — list, detail, status timeline, **realtime tracking** via Supabase Realtime.
- ✅ Profile + address book (region picker, map preview, edit sheet, danger zone).
- ✅ Notifications inbox — realtime-backed.
- ✅ Onboarding tutorial (Hive-gated) and broadcast news (read-state in Hive).

## 1.4 Seller Surface

- ✅ Multi-step seller onboarding (welcome → business type → personal info → shop info → address → documents → review → done).
- ✅ KYC verification flow with passport/document upload.
- ✅ Dashboard with KPI cards and metrics.
- ✅ Product CRUD — multi-section product form (basic info, pricing, logistics, media, specs) + product preview.
- ✅ Seller orders, shop settings (working hours, services, visibility, brand), tariff upgrade, analytics, reviews, notifications.
- ✅ Mock-only seller surfaces gated behind `SELLER_FULFILLMENT_ENABLED` — a prod build never shows fake order/settings data.

## 1.5 Backend (Supabase)

- ✅ **23 ordered SQL migrations** — profiles, shops, products, categories, cart, favorites, notifications, device tokens, news.
- ✅ **Row-Level Security on every table**; policies consolidated, `auth.uid()` calls optimised, functions hardened (`SECURITY DEFINER` review).
- ✅ Missing foreign-key indexes backfilled.
- ✅ Realtime enabled for orders & notifications (CDC).
- ✅ `delete_user_account` RPC restricted to authenticated callers.
- ✅ `send-news-broadcast` Edge Function — FCM topic fan-out.
- ✅ **Supabase repositories** for banners, cart, categories, favorites, notifications, orders, products, seller dashboard, seller onboarding, seller orders, seller products, seller services, seller verification, shop settings, and tariff.

## 1.6 Routing & Navigation

- ✅ **`go_router` for both modes** — customer always; seller via `StatefulShellRoute` (`SELLER_USES_GO_ROUTER`, default ON).
- ✅ Push-tap deep links resolve into the correct screen, including across a mode flip (pending-route stash in Hive).
- ✅ Seller "god-screens" split into `widgets/` sub-trees + extracted controllers (no screen exceeds 1000 lines).

## 1.7 Notifications, Connectivity & Platform

- ✅ FCM push — topic broadcasts (`news`) + per-token personal pings; foreground display via `flutter_local_notifications`.
- ✅ Device-token sync wired to auth state; token removed before sign-out (RLS-safe ordering).
- ✅ Connectivity service — link-change detection + real reachability check, with an offline overlay.
- ✅ Platform facades — `FirebaseMessaging`, `Geolocator`, `ImagePicker`, connectivity — for testability.

## 1.8 Quality, Performance & Localization

- ✅ **192 tests** — BLoC/Cubit unit tests for all 33+ blocs, widget tests (cart, checkout, login, register, gallery), golden tests (auth, cart, gallery), repository contract tests, and one end-to-end integration test.
- ✅ `bloc_concurrency` event transformers on `SearchBloc`, `HomeBloc`, `OrdersBloc`.
- ✅ `memCacheWidth` on every `CachedNetworkImage`; Realtime channel disposal audited.
- ✅ Hand-rolled i18n complete across **uz / ru / en** (322 keys, 0 gaps) with a debug-only completeness guard.
- ✅ Error pipeline — `talker` → Sentry; silent `catch (_)` blocks in auth/core/repositories replaced with logged handlers.
- ✅ `dart analyze` — **0 issues**.

---

# Part 2 — Remaining Development Tasks

Pure coding, architectural-refinement, and bug-fix work only. **No DevOps, CI/CD, store-release, or marketing items appear here by design.** Items map to the technical-debt register in [`docs/PROJECT_STATE_ANALYSIS.md`](./docs/PROJECT_STATE_ANALYSIS.md) §4.

## 2.1 — Activate the seller fulfillment backend 🟠

The `SupabaseSeller*Repository` implementations exist but the surfaces stay gated behind `SELLER_FULFILLMENT_ENABLED` (default OFF).

- [ ] End-to-end verify each seller repository against live Supabase data: create product → receive order → accept → mark shipped → mark delivered.
- [ ] Confirm RLS policies cover every seller read/write path (`get_advisors` review).
- [ ] Flip `SELLER_FULFILLMENT_ENABLED` to `true` once the flows are verified.
- [ ] Remove the "coming soon" placeholder branches for the now-live surfaces.

**Done when:** a seller completes a full order lifecycle on real data with no mock fallback.

## 2.2 — Consolidate the checkout state holders 🟡

- [ ] Merge `CheckoutCubit` (step state) and `CheckoutBloc` (payment events) into a single `CheckoutBloc` with event-driven step transitions — or, if the split is kept, document the ownership boundary at the top of each file.

**Done when:** one obvious owner for each piece of checkout state.

## 2.3 — Retire the legacy seller navigation path 🟡

- [ ] Once `go_router` seller mode has soaked, delete the legacy imperative `sellerNavigatorKey` shell and the `AppConfig.sellerUsesGoRouter` flag.
- [ ] Remove the now-dead `onGenerateRoute` usage.

**Done when:** seller mode has exactly one routing implementation.

## 2.4 — Type-safe Hive access 🟡

- [ ] Add a typed `SettingsBox` wrapper exposing `appMode`, `tutorialSeen`, `locale`, `themeBrightness` as strongly-typed getters/setters.
- [ ] Replace raw string keys (`'app_mode'`, `'tutorial_seen'`, …) with the wrapper.

**Done when:** no raw string Hive keys remain in feature code.

## 2.5 — Lifecycle & cancellation hardening 🟡

- [ ] Add `dispose()` to `HybridCartRepository` / `HybridFavoritesRepository` to cancel their `onAuthStateChange` subscriptions (avoids listener stacking across Phoenix rebirths).
- [ ] Thread `Dio` `CancelToken`s through repository methods; cancel in-flight requests from `Bloc.close()` so a mid-flight mode switch can't deliver stale results.
- [ ] Cache the tutorial-seen flag in a `ValueNotifier<bool>` so the `go_router` redirect stops doing a Hive read on every navigation.

**Done when:** no leaked subscriptions/channels and no stale-result UI after a mode flip.

## 2.6 — Code-organisation cleanups 🔵

- [ ] Move `NotificationsCubit` from `customer/features/notifications/` to `lib/shared/bloc/` — it is root-scoped and consumed by both modes; its current location reads like a layering violation.
- [ ] Audit every `Equatable` `props` override — any field the UI consumes must be present (e.g. confirm `HomeState` includes refresh-timestamp-like fields).
- [ ] Optional: trim the remaining 600–880-line screens (`home`, `tariff`, `analytics`, `tutorial`, `reviews`) into smaller widgets — nice-to-have, not blocking.

## 2.7 — Repository & secrets hygiene 🔴 / 🔵

- [ ] **Untrack the Firebase Admin SDK key** — `git rm --cached woody-b3c1a-firebase-adminsdk-*.json` and re-activate the `*-firebase-adminsdk-*.json` rule in `.gitignore`. **The maintainer must also rotate the key in the Firebase Console** (see [`docs/PROJECT_STATE_ANALYSIS.md`](./docs/PROJECT_STATE_ANALYSIS.md) §6).
- [ ] Move stray repo-root files (`a.md`, `flutter_01.png`) into `docs/` or untrack them.

## 2.8 — Customer payment flow ⏸️ Deferred (Post-MVP)

A pure coding task, but a **deliberate strategic deferral**: V1 ships with offline P2P / cash-on-delivery only — no third-party payment SDK. Recorded here so it is not forgotten.

- [~] Choose a payment partner (Payme / Click / Octo / P2P-to-card).
- [~] Integrate the SDK or webview flow in `customer/features/checkout/`.
- [~] Add a `payment_intents` table + confirmation Edge Function; order stays `pending_payment` until the callback flips it to `paid`.

**Revisit after V1 launch.**

---

## Priority Order

| Order | Task | Severity |
| --- | --- | --- |
| 1 | 2.7 — untrack Admin SDK key (+ owner rotation) | 🔴 |
| 2 | 2.1 — activate seller fulfillment backend | 🟠 |
| 3 | 2.5 — lifecycle & cancellation hardening | 🟡 |
| 4 | 2.2 — consolidate checkout state holders | 🟡 |
| 5 | 2.4 — type-safe Hive access | 🟡 |
| 6 | 2.3 — retire legacy seller navigation | 🟡 |
| 7 | 2.6 — code-organisation cleanups | 🔵 |
| — | 2.8 — customer payment flow | ⏸️ deferred |

---

## Explicitly Out of Scope

Per the strategic pivot, the following are **not** on this roadmap and will not be tracked here:

- CI/CD pipelines (GitHub Actions or otherwise).
- Build flavors / code-signing automation.
- App Store / Play Store submission, listing assets, store review.
- Shorebird code-push integration.
- Analytics SDKs, observability dashboards, on-call / ops process.
- Marketing, ASO, growth.

These may be revisited in a future operations-focused planning cycle — they are intentionally absent so this document stays a pure engineering backlog.

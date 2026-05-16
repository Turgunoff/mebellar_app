# 14 — Roadmap va Bosqichlar (Mobile)

> Asl §13. Greenfield phasing — mobile dasturchisi uchun bosqichma-bosqich.

## Bosqich 0 — Tayyorgarlik (1 hafta)

- [ ] Apple Developer account ($99/yil — Individual yetadi V1'da)
- [ ] Play Console account ($25 one-time)
- [ ] OneSignal account + apps (iOS + Android)
- [ ] Sentry account
- [ ] Universal links / App Links uchun domain (`mebellar.uz`)
- [ ] Logo, app icon, splash screen design

## Bosqich 1 — Backend ishga tushishini kutish (2 hafta)

> Mobile bu bosqichda boshlanmaydi. Backend Bosqich 1 tugashini kutamiz: "auth ishlaydi, JWT verify ishlaydi".

## Bosqich 2 — Mobile skeleton (2 hafta)

> **Deliverable:** "Login → mode tanlash → ikkala mode ham ochiladi → switch ishlaydi"

- [ ] Flutter loyiha tozalash, dual entry point setup ([01-project-structure.md](./01-project-structure.md))
- [ ] `pubspec.yaml`: dependencies (bloc, go_router, get_it, dio, supabase_flutter, hive, easy_localization, onesignal_flutter, flutter_phoenix)
- [ ] `lib/main.dart` — root scope + mode scope ([02-dual-entry-mode-switching.md](./02-dual-entry-mode-switching.md))
- [ ] Hive boxes setup (settings, cache)
- [ ] Auth screens (login, register, email verify, forgot password) — [06-auth-flow.md](./06-auth-flow.md)
- [ ] AppMode switching (Phoenix.rebirth + scope manipulyatsiya)
- [ ] DI: AuthRepository, Dio, SupabaseClient
- [ ] Theming (customer + seller themes)
- [ ] Localization (uz/ru/en) skeleton
- [ ] Customer + Seller bottom navigation skeleton (placeholder screens)
- [ ] OneSignal integration (basic)
- [ ] Test: login → fetchMe → mode switch → seller app ochiladi

## Bosqich 3 — Customer features (3-4 hafta)

> **Deliverable:** "Customer app to'liq backend bilan ishlaydi"

- [ ] Home screen (banners, featured shops, featured products)
- [ ] Categories (drill-down)
- [ ] Catalog (filter, sort, pagination)
- [ ] Search (debounced)
- [ ] Product detail (gallery, shop card, services, attributes)
- [ ] Cart (multi-shop grouping)
- [ ] Checkout flow (address, delivery, services, mock payment)
- [ ] Orders list + detail + realtime status update ([04-realtime.md](./04-realtime.md))
- [ ] Cancel order
- [ ] Favorites (CRUD)
- [ ] Profile + addresses CRUD
- [ ] Language picker (`easy_localization.setLocale`)
- [ ] Notifications list, mark as read
- [ ] Push notification handler (foreground + tap)
- [ ] Empty states, error states

## Bosqich 4 — Seller features (3-4 hafta)

> **Deliverable:** "Seller app — onboarding'dan order fulfillment'gacha"

- [ ] Onboarding multi-step form (save progress to Hive)
- [ ] Verification screen + image upload (Supabase Storage private bucket)
- [ ] Status tracking (pending/in_review/approved/rejected)
- [ ] Dashboard (KPI cards, new orders realtime)
- [ ] Products list + create/edit/delete
- [ ] Image gallery (drag reorder, primary toggle)
- [ ] Tariff limit error handling
- [ ] Orders list (tabs: new/active/done/cancelled)
- [ ] Order action buttons (state machine: confirm/ship/deliver/cancel)
- [ ] Shop settings (logo, cover, info, brand color)
- [ ] Services configuration (toggle + config per service)
- [ ] Tariff page + P2P upgrade flow ([10-tariff-upgrade-ux.md](./10-tariff-upgrade-ux.md))
- [ ] Analytics (basic — line chart, top products)
- [ ] Mode switch back to customer

## Bosqich 5 — Cross-mode notification (1 hafta — alohida diqqat!)

> **Deliverable:** "Cross-mode push notification 6 holat (5.6.4 jadvali) muvaffaqiyatli ishlaydi"

- [ ] `NotificationHandler` ([05-notifications-deep-linking.md](./05-notifications-deep-linking.md))
- [ ] Pending route Hive saqlash
- [ ] Cold start `_checkInitialNotification()`
- [ ] `_consumePendingRoute()` har App'da
- [ ] Stale check 5 daqiqa
- [ ] Defensive guards (logged out, mode mismatch)
- [ ] **6 holat uchun manual test** (5.6.4 jadvali)

## Bosqich 6 — Polish + QA (2 hafta)

- [ ] Edge case handling
- [ ] Error states, empty states
- [ ] Performance: lazy loading, image caching, pagination
- [ ] Image upload progress (kerak bo'lsa)
- [ ] Offline behavior (cache fetch, retry)
- [ ] Translations review (native speakers)
- [ ] Deep link testing (universal/app links)
- [ ] Internal testing (5-10 friends/family) — TestFlight + Play Internal
- [ ] Sentry alerts
- [ ] Splash screen, app icon, launch screen polish

## Bosqich 7 — Launch prep (2 hafta)

- [ ] App Store assets (screenshots, descriptions, metadata, preview video)
- [ ] Play Store assets
- [ ] Privacy policy, ToS link in-app
- [ ] App Store + Play Store submission
- [ ] Onboarding tutorial (first-time user)
- [ ] Launch coordination with backend deploy

---

## Jami timeline (mobile)

**Optimistik:** ~14-17 hafta = 3.5-4 oy.

**Realistik (solo dev):** 6-8 oy.

> Backend Bosqich 1 (2 hafta) tugashini kutib, paralelga o'tamiz. Bosqich 2 va undan keyingi mobile ishlari backend bilan teng vaqtda boradi.

---

## Critical path

| Hafta | Backend | Mobile | Sinxron point |
|-------|---------|--------|---------------|
| 1-2 | Schema + skeleton | (kutadi) | Auth API kontrakti |
| 3-4 | Customer endpoints | Skeleton + auth | API contract muhrlanadi |
| 5-7 | Customer endpoints (davomi) | Customer features | Realtime channel test |
| 8-10 | Seller endpoints | Customer polish + Seller skeleton | Verification flow |
| 11-13 | Seller endpoints (davomi) | Seller features | Tariff payment flow |
| 14 | Admin endpoints | Notification handling | Cross-mode test |
| 15-16 | Admin tooling | Polish | Internal testing |
| 17-18 | Launch prep | Launch prep | Coordinated release |

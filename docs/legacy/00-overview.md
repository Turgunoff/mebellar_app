# 00 — Loyiha umumiy ko'rinishi (Mobile nuqtai nazaridan)

> Asl §0, §1, §2.

## Mebellar nima

Mebellar — O'zbekistondagi mebel marketplace platformasi. Ikki tomonli (two-sided):

- **Customer** — xaridor: catalog, search, cart, checkout, order tracking
- **Seller** — sotuvchi: shop, mahsulot CRUD, order fulfillment, dashboard, tariff

V1 hech qaysi store'ga chiqarilmagan, shuning uchun **greenfield rewrite**.

## Mobile texnologiyalar

| Komponent | Tanlov |
|-----------|--------|
| Framework | Flutter 3.41+ (single project, dual entry-point) |
| State | BLoC (`flutter_bloc`) |
| Routing | `go_router` (har AppMode uchun alohida router) |
| DI | `get_it` + scope pattern (root + mode scopes) |
| HTTP | `dio` |
| Local storage | `hive_flutter` (cache, settings) |
| Secure storage | `flutter_secure_storage` (refresh token) |
| Auth | Supabase SDK (`supabase_flutter`) |
| Realtime | Supabase Realtime (Postgres CDC) |
| Push | OneSignal SDK |
| App restart | `flutter_phoenix` |
| Localization | `easy_localization` |
| Deferred bundle | Flutter deferred imports (V2 optional) |

## Biznes-modeli (mobile uchun muhim)

- Xaridorlar **bepul**
- Sotuvchilar uchun subscription tariff (Free / Basic / Pro / Enterprise)
- V1 to'lovlari — **P2P pul o'tkazma** (skrinshot upload, admin manual tasdiq)
- Verification: jismoniy shaxs ham, YaTT/MChJ ham — yuridik shaxs **majburiy emas**
- Yetkazib berish — har sotuvchi o'zi tashkil qiladi (pickup / shop_delivery / courier)
- **Single-shop 1:1**: bitta sotuvchi = bitta do'kon
- **Mode switch**: bitta foydalanuvchi customer va seller bo'lishi mumkin (har xil app instance)

## V1 (MVP) mobile ichida

✅ Email/password auth (Supabase SDK)  
✅ Customer flow: catalog, search, product detail, cart, checkout (mock payment), order tracking  
✅ Seller flow: shop create (1:1, bitta shop), product CRUD, order fulfillment, basic analytics  
✅ Seller verification UI: passport upload, status tracking  
✅ Tariff: P2P pul o'tkazma uchun payment instructions UI  
✅ Multilingual UI (uz/ru/en) — easy_localization  
✅ Push notifications (OneSignal) — order status, new orders for seller  
✅ Realtime order updates (Supabase channels)  
✅ Mode switching: customer ↔ seller via Phoenix restart  
✅ Cross-mode deep linking via pending_route (notification handling)  

## V1 da MOBILE ichida YO'Q (qat'iy)

❌ Real to'lov flow (mock checkout)  
❌ SMS OTP — V2  
❌ MyID button (disabled — V2)  
❌ In-app chat — V2+  
❌ Multi-shop (har user uchun bitta shop)  
❌ Bulk product import  
❌ Promo code, kupon  
❌ Multi-currency (faqat UZS)  
❌ Web app (Flutter Web yoki Next.js — V2)  

## Yuqori darajadagi arxitektura (mobile angle)

```
┌─────────────────────────────────────────────┐
│  Flutter App (single project)               │
│                                             │
│   main.dart  ─→  AppMode detection          │
│       │                                     │
│       ├─→  Phoenix(child: CustomerApp())    │
│       │       └─→  customer GoRouter        │
│       │            └─→  customer features   │
│       │                                     │
│       └─→  Phoenix(child: SellerApp())      │
│               └─→  seller GoRouter          │
│                    └─→  seller features     │
└──────────────┬──────────────────────────────┘
               │
               │  HTTPS REST + Realtime WS
               │
       ┌───────▼────────────────┐
       │  FastAPI Backend       │
       │  (Frankfurt — fra)     │
       └───────┬────────────────┘
               │
       ┌───────▼────────────────┐
       │  Supabase (eu-central-1)│
       │  • Postgres + RLS      │
       │  • Auth (email/password)│
       │  • Storage (S3)        │
       │  • Realtime (Postgres CDC)│
       └────────────────────────┘
```

## Mode switching — qisqacha

```
1. Foydalanuvchi customer mode'da
2. Profile → "Sotuvchi rejimi" tugma
3. switchAppMode(context, AppMode.seller):
   - Hive'ga 'app_mode' = 'seller' saqlash
   - GetIt.popScope() — mode scope dispose
   - _initModeScope(seller) — seller dependencies register
   - Phoenix.rebirth(context) — widget tree rebuild
4. SellerApp ochiladi
```

Tafsilotlar: [02-dual-entry-mode-switching.md](./02-dual-entry-mode-switching.md)

## Auth flow — qisqacha

Mobile Supabase SDK orqali to'g'ridan-to'g'ri ishlaydi:

```
1. signUp(email, password, options: {data: {full_name, preferred_language}})
   → Postgres trigger profile yaratadi (atomik)
2. Email verify link
3. signIn → JWT + refresh token
4. Backend'ga `Authorization: Bearer <jwt>` bilan murojaat
5. GET /api/v1/me → profile + roles
```

Backend'da `POST /api/v1/auth/sync` endpoint **YO'Q** — trigger atomik. Tafsilotlar: [06-auth-flow.md](./06-auth-flow.md)

## Kritik mobile qoidalar

1. **Scoped DI** — `GetIt.I.reset()` to'g'ridan-to'g'ri ishlatmaydi (memory leak). Root + mode scope pattern. Tafsilotlar: [02-dual-entry-mode-switching.md](./02-dual-entry-mode-switching.md)
2. **Phoenix.rebirth() main()'ni qayta chaqirmaydi** — scope manipulyatsiya rebirth'dan oldin
3. **Pending route pattern** cross-mode notification uchun — Hive'ga saqlash, mode switch'dan keyin consume
4. **Stale check 5 daqiqa** pending route uchun — eski notification e'tiborga olinmasin
5. **Mobile signed URL'larni cache qilmaydi** — TTL muammosi. Har sessiyada qaytadan so'rash
6. **Hive box'lar root scope'da** — mode switch'da yopilmaydi, faqat user logout'da
7. **API kontrakti backend bilan sinxron** — `app/docs/07-api-reference.md` va `backend/docs/04-api-endpoints.md` bir xil

## Keyingi qadam

→ [01-project-structure.md](./01-project-structure.md) — `lib/` papkalar daraxti

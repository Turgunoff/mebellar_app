# Mebellar V2 — Flutter app hujjatlari

Bu papka **Flutter mobile app** uchun TZ v2.2 dan ajratib olingan barcha tegishli bo'limlarni saqlaydi.
Asl manba: `mebellar_v2_tz.md` (Eldor Turg'unov, 2026-05-01).

## Asosiy g'oya: Dual entry-point Flutter app

**Bitta loyiha** ichida **ikkita MaterialApp** (Customer / Seller) — `flutter_phoenix` orqali restart pattern bilan mode switch.

```
lib/main.dart  →  AppMode tanlanadi (customer / seller)
                ├─→  customer/customer_app.dart  (xaridor uchun MaterialApp)
                └─→  seller/seller_app.dart      (sotuvchi uchun MaterialApp)
```

## Maqsad

Flutter dasturchisi (yoki AI agenti) ushbu papkani o'qib chiqib:

1. Loyihaning umumiy konteksti, biznes-modeli va texnik qarorlarini tushunadi
2. Dual entry-point pattern, scoped DI, mode switching, notification handling tafsilotlarini biladi
3. Backend API kontraktini biladi (har endpoint mobile tomonidan qanday ishlatilishi)
4. Implementatsiyani boshlay oladi — har fayl bitta amaliy mavzuga bag'ishlangan

## Faylar tartibi

| # | Fayl | Mazmuni | Asl §-bo'limi |
|---|------|---------|----------------|
| 00 | [overview.md](./00-overview.md) | Executive summary, scope, V1/V2 chegaralari, mobile arxitekturasi | §0, §1, §2 |
| 01 | [project-structure.md](./01-project-structure.md) | `lib/` daraxti, core/shared/customer/seller bo'limlar | §5.1 |
| 02 | [dual-entry-mode-switching.md](./02-dual-entry-mode-switching.md) | `main.dart`, scoped DI, Phoenix.rebirth, switchAppMode | §5.2, §5.3, §19.2 |
| 03 | [deferred-components.md](./03-deferred-components.md) | Bundle size, deferred imports (V2 optimization) | §5.4 |
| 04 | [realtime.md](./04-realtime.md) | Supabase Realtime — order status, yangi orderlar, dispose pattern | §5.5 |
| 05 | [notifications-deep-linking.md](./05-notifications-deep-linking.md) | Cross-mode push notification, pending route, cold start | §5.6, §19.6 |
| 06 | [auth-flow.md](./06-auth-flow.md) | Supabase Auth (email/password) signup→login→profile, JWT | §4.3 (mobile angle), §19.1 |
| 07 | [api-reference.md](./07-api-reference.md) | Backend API endpoint xaritasi (mobile yangiklari) | §4.4 |
| 08 | [customer-features.md](./08-customer-features.md) | Customer flow ekranlari va data flow | §1.2 customer parts |
| 09 | [seller-features.md](./09-seller-features.md) | Seller onboarding, verification UX, shop, products, orders | §1.2 seller parts, §6 |
| 10 | [tariff-upgrade-ux.md](./10-tariff-upgrade-ux.md) | P2P to'lov UI, payment instructions, pending status | §7.2 mobile UX |
| 11 | [storage-image-upload.md](./11-storage-image-upload.md) | Image picker, client-side resize, Supabase Storage upload | §9 mobile parts |
| 12 | [localization.md](./12-localization.md) | easy_localization, MultilingualText, til o'zgartirish | §10 |
| 13 | [security.md](./13-security.md) | Token storage, secure storage, deep link xavfsizlik, mobile threats | §11 mobile parts |
| 14 | [roadmap-phases.md](./14-roadmap-phases.md) | Greenfield phasing — mobile vazifalari (Bosqich 0-7) | §13 |
| 15 | [glossary-open-questions.md](./15-glossary-open-questions.md) | Atamalar, ochiq savollar, refinements log | §16, §18, §19, §20 |

## Qaysi tartibda o'qish kerak

**Birinchi marta:** 00 → 01 → 02 → 06 → 07. Shu paytda allaqachon "auth, mode tanlash, ikkala app skeleton'i ochiladi" deyishingiz mumkin.

**Customer feature ustida ishlash:** 08 + 07 + 12 (UI strings).

**Seller feature ustida ishlash:** 09 + 10 + 11 + 07.

**Notification implementatsiyasi:** 05 — bu eng nozik mavzu, eng keyingi qadamda implement qilamiz.

## Backend qism qayerda

Mobile har request'da backend `api/v1/...` endpointlarini iste'mol qiladi. Backend dasturchi parallel `backend/docs/` papkasini o'qiydi. API kontrakti **ikki tomon uchun ham yagona shartnoma** — bu yerda va `backend/docs/04-api-endpoints.md` da bir xil aniqlikda yozilgan.

## Yangilash siyosati

- Asl TZ (`mebellar_v2_tz.md`) o'zgarsa — bu yerdagi tegishli faylni qo'lda yangilash
- Implementatsiya paytida yangi qaror bo'lsa — `15-glossary-open-questions.md`'ga qo'shish (yangi sub-section)
- API kontrakti o'zgarsa — backend va mobile docs ikkalasi sinxron bo'lishi shart

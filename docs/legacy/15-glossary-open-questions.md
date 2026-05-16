# 15 — Glossary, Open Questions, Refinements

> Asl §16, §18, §19, §20.

## 1. Atamalar

| Atama | Ma'no |
|-------|-------|
| **AppMode** | Mobile app rejimi: `customer` yoki `seller`. Mode switch — Phoenix.rebirth orqali |
| **Pending route** | Cross-mode notification handling uchun Hive'da saqlanadigan deep link |
| **Root scope** | GetIt'da app boot vaqtida yaratiladigan, mode switch'da saqlanadigan singleton'lar |
| **Mode scope** | GetIt'da har AppMode uchun yaratiladigan, switch'da dispose qilinadigan singleton'lar |
| **handle_new_user** | Postgres trigger: `auth.users` ga insert bo'lganda `public.profiles` ga ham insert qiladi (atomik) — backend qismidagi joriy holat |
| **JWKS** | JSON Web Key Set — Supabase JWT'larni offline verify qilish uchun public keys |
| **JWT-based shop resolution** | URL'da `{shop_id}` o'rniga JWT'dan user_id → seller_profile → shop (1:1) |
| **P2P payment** | Peer-to-peer karta-karta pul o'tkazma (V1'da tarif to'lovi uchun) |
| **Verification status** | `pending`/`in_review`/`approved`/`rejected` |
| **Multilingual JSONB** | `{"uz": "...", "ru": "...", "en": "..."}` formatdagi text maydonlar |
| **Tariff** | Sotuvchi obuna paketi: Free / Basic / Pro / Enterprise |
| **Shop services** | Sotuvchi taklif qiladigan xizmatlar (yetkazib berish, montaj, garantiya, ...) |
| **Signed URL** | Private bucket'dan vaqtinchalik (1 soat) ruxsat URL — verification hujjatlari uchun |
| **Soft delete** | `deleted_at` to'ldirish (DB'dan o'chirish o'rniga) |
| **Phoenix.rebirth** | `flutter_phoenix` paketining widget tree'ni qayta yaratish metodi (lekin `main()`'ni qayta chaqirmaydi) |

## 2. Asosiy mobile fayllari va maqsadi

| Fayl | Maqsad |
|------|--------|
| `lib/main.dart` | Bootstrap, root scope, initial mode detection, cold start notification check |
| `lib/customer/customer_app.dart` | Customer MaterialApp + GoRouter |
| `lib/seller/seller_app.dart` | Seller MaterialApp + GoRouter |
| `lib/core/notifications/notification_handler.dart` | Cross-mode deep linking logic |
| `lib/core/auth/auth_repository.dart` | Supabase Auth + Backend `/me` |
| `lib/core/network/api_client.dart` | Dio + Bearer token interceptor |
| `lib/core/storage/hive_boxes.dart` | settings, cache, pending_route boxes |
| `lib/shared/models/multilingual_text.dart` | uz/ru/en JSONB rendering |
| `assets/translations/*.json` | UI strings |

---

## 3. Open Questions

> Ushbu savollarga javob bo'lmasdan TZ to'liq emas (asl §16). Implementatsiyaga ta'siri bor savollarini bu yerda saqlaymiz.

### 3.1 Biznes savollari

1. **Komissiya foizi:** Free 5%, Basic 3%, Pro 2% — tasdiqlash kerak
2. **Dispute resolution:** customer order'dan norozi bo'lsa kim qaror qabul qiladi?
3. **Sotuvchiga to'lov modeli (V2):** escrow yoki direct flow?

### 3.2 Texnik savollar

4. **Foydalanuvchi soni 1-yil ichida prognozi?**
5. **Geolokatsiya:** O'zbekiston / Markaziy Osiyo?
6. **Web app kerakmi (V2)?** Flutter Web yoki Next.js?

### 3.3 Yuridik / operatsion

7. Privacy Policy / ToS — yurist
8. Verification hujjatlari saqlash muddati
9. P2P to'lov soliq holati
10. Sotuvchini telefon orqali intervyu — UX ta'siri

### 3.4 UX qarorlari (mobile-specific, hali ochiq)

11. **Tariff downgrade UX:** Free'ga downgrade bo'lganda mahsulotlar archived bo'ladi. Foydalanuvchiga qaysi mahsulotlar arxivlangani aniq ko'rsatish — modal, banner yoki email?
12. **In-app onboarding tutorial** — birinchi marta foydalanuvchi yo'l-yo'riq olishi kerakmi (skip qilsa bo'ladigan slides)?
13. **Yagona mode'da boshlash:** birinchi marta seller bo'lganda customer mode'ga qaytish UX'i — qachon va qanday eslatma?

---

## 4. Hal qilingan savollar (arxiv)

| Savol | Qaror | Joyi |
|-------|-------|------|
| Yetkazib berish modeli | Har sotuvchi o'zi (decentralized) | overview, seller-features |
| Multi-shop (bir sotuvchi → ko'p shop) | Yo'q, qat'iy 1:1 | overview |
| In-app chat (customer ↔ seller) | Yo'q (V1), telefon/Telegram orqali aloqa | customer-features (product detail) |
| YaTT/MChJ majburiymi | Yo'q (V1), jismoniy shaxs P2P bilan ishlay oladi | seller-features (onboarding) |
| Tariff to'lov usuli (V1) | P2P pul o'tkazma + skrinshot | tariff-upgrade-ux |
| Real to'lov gateway (V1) | Mock checkout | customer-features (checkout) |
| MyID integration (V1) | Yo'q, manual verification | seller-features (verification) |
| SMS OTP (V1) | Yo'q, faqat email | auth-flow |

---

## 5. Architectural Refinements (Mobile bo'limlar)

### 5.1 Auth Sync race condition — HAL QILINDI (backend)

Mobile'ga ta'siri: `POST /api/v1/auth/sync` endpoint **YO'Q**. Login bo'lgandan keyin to'g'ridan-to'g'ri `GET /me` chaqirish — profile albatta mavjud (Postgres trigger atomik yaratadi).

### 5.2 GetIt + memory leaks — HAL QILINDI

Ikki qatlamli DI (root + mode scope). Har singleton `dispose:` callback bilan. Tafsilot: [02-dual-entry-mode-switching.md](./02-dual-entry-mode-switching.md).

### 5.3 Single-shop 1:1 — DB DARAJASIDA MAJBURLANDI

Mobile'ga ta'siri: seller endpoint'larida URL'da `{shop_id}` YO'Q. Backend JWT'dan resolve qiladi.

### 5.4 Cross-mode notification handling — PATTERN BELGILANDI

"Pending route" pattern — Hive'ga saqlash, mode switch, consume. Stale check 5 daqiqa. Cold start handle. Tafsilot: [05-notifications-deep-linking.md](./05-notifications-deep-linking.md).

### 5.5 Phoenix.rebirth `main()` chaqirmaydi — bilish kerak

Scope manipulyatsiya **rebirth'dan oldin** qilinishi shart. Aks holda yangi widget tree eski mode dependencies bilan ishlaydi.

### 5.6 Inclusive seller onboarding — JISMONIY SHAXS QO'LLAB-QUVVATLANDI

`business_type == 'individual'` — alohida hujjatlar branch. UI'da aniq matn: "Jismoniy shaxs ham to'liq sotuvchi bo'la oladi".

### 5.7 P2P pul o'tkazma to'lov modeli — UI QO'SHILDI

Tariff upgrade — bottom sheet payment instructions, skrinshot upload, pending status. Telegram alternativ link. Tafsilot: [10-tariff-upgrade-ux.md](./10-tariff-upgrade-ux.md).

### 5.8 Mobile signed URL'larni cache qilmaydi

TTL muammosi — har sessiyada qaytadan signed URL olish. `cached_network_image` URL bo'yicha cache qiladi, lekin har URL har xil bo'lgani uchun real cache hit yo'q.

---

## 6. Keyingi qadamlar (asl §20 mobile angle)

1. TZ v2.2 ni o'qib chiq, savollar yoz
2. Backend Bosqich 1 tugashini kutib, mobile Bosqich 2 boshlash
3. Hafta 3-4 plan: Mobile dual-entry skeleton + scoped DI.
   **Deliverable:** "login → mode tanlash → ikkala mode ham ochiladi → switch ishlaydi"
4. Pilot foydalanuvchilar (3-5 ta tanish sotuvchi) — verification UX testi uchun
5. Har hafta retro — scope o'zgarishi, yangi qarorlar bu fayl 5.x sifatida saqlash

---

> Eslatma: bu hujjatlar "starting point". Implementatsiya paytida yangi savollar paydo bo'ladi — hujjatlarga qaytib kiritib bor.

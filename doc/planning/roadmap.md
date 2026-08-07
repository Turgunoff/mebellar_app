# Woody / Mebellar — Roadmap

> **Status:** Living · **Versiya:** 1.0 · **Sana:** 2026-06-12
> Mahsulot spetsifikatsiyasi: [TZ.md (master)](../TZ.md) · Arxitektura: [architecture/system_design.md](../architecture/system_design.md)
> Texnik qarz (kod bazasidan o'lchangan): [tech_debt_roadmap.md](./tech_debt_roadmap.md)

Bu hujjat avval tarqalgan `mebellar_app/ROADMAP.md` (Supabase davri) o'rnini bosadi. Ushbu yo'l xaritasi nima **rasman bajarilgani** va nima **kelajakda** ekanini aniq ajratadi.

## Holat belgilari

| Belgi | Ma'no |
|---|---|
| ✅ | Bajarilgan, ishlab chiqarishda (kod bilan tasdiqlangan) |
| 🟡 | Bajarilgan, lekin go-live uchun operatsion qadam kerak |
| 🔧 | Ochiq texnik qarz / yarashtirish kerak |
| 🔜 | Rejalashtirilgan (kelajak bosqich) |

---

## Phase 0–2 — Asos va platforma (✅ BAJARILGAN)

### Platforma migratsiyasi
- ✅ Supabase'dan to'liq chiqish (uchala repo, 2026-05-31). Mustaqil FastAPI backend + o'z Postgres + Cloudflare R2 + o'z WebSocket. `grep -i supabase` = nol.
- ✅ OneSignal → Firebase FCM; Sentry → Crashlytics; email+parol → telefon+OTP (Eskiz); Telegram bot → admin panel.

### Autentifikatsiya va identitet
- ✅ Telefon + OTP (Eskiz), parolsiz. JWT HS256 (access/refresh, jti replay himoyasi). Cooldown + urinish chegaralari + hash saqlash.
- ✅ Soft-delete + qaytariladigan bloklash + kaskad (migration 0025).
- ✅ RBAC: super_admin / manager + scoped moderatorlar (8 ta delegatsiya sohasi).

### Customer sirti
- ✅ Katalog + qidiruv/filtr/saralash; mahsulot detali; o'xshash mahsulotlar.
- ✅ **Hybrid guest cart** (Hive lokal → server merge on login, 2026-06-07); checkout login-gate; smart CTA tugmalari; qty 1–99; majburiy rang.
- ✅ Favorites (server + optimistic + auth-sync).
- ✅ Buyurtmalar (bir do'kon = bir buyurtma, server-avtoritar narx, COD); status mashinasi.
- ✅ Buyurtma bo'yicha chat (lazy-create, abadiy ochiq, realtime + FCM fallback).
- ✅ Sharhlar (+ sotuvchi javobi).
- ✅ **3-tier network UX** (kesh → shimmer → 5s timeout → bloklovchi `FlashscoreNetworkModal`, single-owner pop).

### Seller sirti
- ✅ Onboarding + verifikatsiya (admin moderatsiyasi).
- ✅ Do'kon + mahsulot CRUD + atribut sxemasi.
- ✅ **AI fill-from-photos** (`/seller/products/ai-suggest`, Azure OpenAI gpt-5-mini vision).
- ✅ Buyurtma bajarish (status o'tishlari).
- ✅ Dashboard, analitika, yutuqlar, leaderboard.

### Pul tizimi
- ✅ **Tarif tizimi** (migration 0013): plan CRUD, free default, kvitansiya moderatsiyasi.
- ✅ **Trial bonus** (migration 0020): 30-kun 0% komissiya, birinchi tasdiqda bir marta.
- ✅ **Seller wallet + soft-freeze** (migration 0027): kredit limitlar, 48h grace, avto-suspension/tiklash, komissiya `delivered`da yechiladi, top-up moderatsiyasi, admin qo'lda tuzatish.
- ✅ Tarif expiry sweeper (limitdan oshган mahsulotni arxivlash, free'ga qaytarish, 5-kun ogohlantirish).

### Internatsionalizatsiya
- ✅ Dinamik kontent i18n (migration 0026): no-'uz' kontrakti, read-only fallback, Accept-Language uchala qatlamda.

### Admin va marketing
- ✅ woody_admin (Next.js 16): moderatsiya, tariflar, hamyonlar, broadcast, managerlar, RBAC mirror.
- ✅ woody_frontend (Next.js 14): uch tilli marketing landing, app skrinshot pipeline.

---

## Joriy holat — go-live va yarashtirish (🟡 / 🔧)

Bular bajarilgan, lekin operatsion qadam yoki yarashtirish talab qiladi:

| # | Element | Holat | Kerakli harakat |
|---|---|---|---|
| 1 | FCM real push go-live | 🟡 | Firebase service-account JSON + iOS APNs kalitini prod'ga qo'shish (`FCM_SERVICE_ACCOUNT_PATH`) |
| 2 | Deploy hujjat drift'i (backend/admin) | 🔧 | CLAUDE.md/TZ'dagi systemd flow'ni haqiqiy Docker (`deploy.yml`) bilan yarashtirish |
| 3 | Admin sahifa-guard'lari | 🔧 | `/products,/orders,/customers,/reviews,/categories,/analytics,/shops` uchun `requirePermission` (AUDIT bloker) |
| 4 | R2 bucket soni drift'i (6 vs 7) | 🔧 | `user-avatars` mavjudligini tasdiqlash, TZ↔CLAUDE.md yarashtirish |
| 5 | Realtime chat subscription'lari | 🔧 | Hozir refresh + FCM fallback; to'liq WS subscription qolgan |
| 6 | Admin tarif CRUD fan-out | 🔧 | `/tariffs`, `/notifications` UI yakunlash |
| 7 | CSP enforce (marketing) | 🔧 | report-only → enforce o'tkazish |
| 8 | Unsplash → real R2 fotolar (marketing) | 🔧 | Placeholder rasmlarni almashtirish |
| 9 | Enum sinxron validatsiyasi | 🔧 | OrderStatus/VerificationStatus/ProductStatus uch repo drift'ini avtomatik tekshirish (OpenAPI codegen ko'rib chiqilmoqda) |
| 10 | `.claude/rules/i18n.md` | 🔧 | i18n kontraktini rasmiy rules fayliga yozish (hozir faqat kodda) |
| 11 | woody_admin/README.md | 🔧 | create-next-app boilerplate'ni almashtirish |

---

## Phase 3 — Onlayn to'lovlar (🔜 REJALASHTIRILGAN)

> Maqsad: COD-only'dan haqiqiy onlayn to'lovga o'tish.

- 🔜 **Payme** integratsiyasi (webhook, idempotent yarashtirish, refund oqimi).
- 🔜 **Click** integratsiyasi.
- 🔜 Buyurtma ↔ to'lov holat mashinasi (paid/pending/refunded).
- 🔜 Komissiya hisoblash to'lov bilan bog'lanishi (hozir hamyon ledger'i mavjud — to'lov ushlanmasini avtomatik kreditlash).
- 🔜 Xarid, refund, dispute uchun audit izi.

**Bog'liqliklar:** hamyon ledger'i (✅ tayyor), buyurtma holat mashinasi (✅ tayyor).

---

## Phase 4 — Referral va Cashback (Growth Engine) (🔜 REJALASHTIRILGAN)

> Maqsad: organik o'sish va ushlab turish.

- 🔜 **Referral tizimi:** taklif kodlari (foydalanuvchi + sotuvchi), konversiya attribution, mukofot ledger'i.
- 🔜 **Cashback:** xaridorga sotuvdan qaytim (hamyon-kredit yoki promo sifatida).
- 🔜 Anti-fraud (o'z-o'zini taklif qilish, ko'p akkaunt aniqlash).
- 🔜 Kampaniya konfiguratsiyasi (admin: stavkalar, muddatlar, byudjet).
- 🔜 Admin attribution dashboard'i.

**Bog'liqliklar:** Phase 3 (cashback uchun to'lov), hamyon ledger'i kengaytmasi.

---

## Phase 5+ — Kengaytmalar (🔜 KELAJAK)

- 🔜 **MyID KYC** integratsiyasi (seller verifikatsiyasini avtomatlashtirish).
- 🔜 To'liq realtime chat subscription'lari.
- 🔜 BI / analitika dashboard'lari (sotuv, kohort, LTV).
- 🔜 Strukturali backend observability (metrics, tracing).
- 🔜 OpenAPI'dan mijoz tip codegen (enum drift'ni yo'q qilish).
- 🔜 Store release pipeline (CI/CD), App Store / Play Store.

---

## Doiradan tashqari (hozircha)

- Web customer ilovasi (faqat mobil + marketing landing).
- Ko'p-do'konli sotuvchi (1 seller = 1 shop invariant).
- Xalqaro yetkazib berish / ko'p valyuta.

---

## O'zgarishlar tarixi

| Sana | O'zgarish |
|---|---|
| 2026-06-12 | Birlashtirilgan roadmap yaratildi; eski Supabase-davri `ROADMAP.md` o'rnini bosdi. Bajarilgan vs kelajak aniq ajratildi (trial/wallet/soft-delete/i18n/AI/network-UX ✅ deb belgilandi). |

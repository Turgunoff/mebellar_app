# Woody / Mebellar — Roadmap

> **Status:** Living · **Versiya:** 1.1 · **Sana:** 2026-09-17
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

### AR / 3D va AI (2026-06 … 2026-08)
- ✅ **Per-part AR pipeline** — qulflangan 3-fotolik skan → R2 (`product-ar-scans`) → **Meshy** foto-to-3D (backend). `Product.arParts`, per-part `arStatus`. Monetizatsiya: 1 bepul skan, keyin AR token.
- ✅ **Uch xil ko'rish yo'li** — inline `model_viewer_plus`, **native ARCore/ARKit** ko'p-obyektli sahna (`ar_flutter_plugin_plus`), va AR'siz qurilma uchun 2D fallback. iOS'da AR Quick Look.
- ✅ **AI Interior Designer** — chat (RAG, root-scope cubit, FAB), rasm yuklash `ai-chat-images` bucket'i orqali.
- ✅ **Support chat** (`/support/*`) — foydalanuvchi ↔ platforma, **ovozli xabar** bilan (`record` + `just_audio`). Buyurtma chatidan alohida.

### Seller yuridik va KYC (2026-08)
- ✅ **Dinamik ko'p tilli Oferta** — `legal_documents` (uz/ru/en, migration **0093**, `version 1.1`), `GET /legal/oferta?lang=`, oxirigacha scroll qilmasdan qabul qilib bo'lmaydi, `contract_accepted_at` / `contract_version` DB'ga muhrlanadi, GPD tartibidagi PDF (Inter TTF — kirill uchun majburiy).
- ✅ **KYC draft persistence** — pasport rasmlari **tanlangan payt** WebP'ga siqiladi va Documents + Hive'ga yoziladi, ilova o'ldirilsa ham qayta yuklash shart emas.

### Marketing va maxfiylik (2026-08)
- ✅ **Meta App Events** + ATT gate; Advanced Matching **default OFF** flag ortida.
- ✅ **Analitika maxfiyligi** — Sozlamalardagi "Foydalanish statistikasi" tugmasi Firebase Analytics + Crashlytics + Meta hodisalarini o'chiradi (darhol va sovuq startda).
- ✅ **Dual analitika** — GA4 sessiyalar uchun + `PresenceService` → `POST /me/presence` (migration **0094**).
- ✅ **Katalog ishlashi** — 7-kunlik ko'rish rollup'i + browse/search indekslari (migration **0100**).

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
| 1 | FCM real push go-live | 🟡 | Firebase service-account JSON + iOS APNs kalitini prod'ga qo'shish (`FCM_SERVICE_ACCOUNT_PATH`). iOS qadamlari: [`release_checklist.md`](../release_checklist.md) |
| 2 | Deploy hujjat drift'i (backend/admin) | 🔧 | TZ §2 dagi systemd flow'ni haqiqiy Docker (`deploy.yml`) bilan yarashtirish |
| 3 | Admin sahifa-guard'lari | ✅ | **Yopildi (2026-09-17 tasdiqlandi).** `products`, `orders`, `customers`, `reviews`, `categories`, `analytics`, `shops` — hammasida `requirePermission`. ⚠️ Qolgan tekshiruv: `notifications`, `tariffs`, `wallets` da `requirePermission` **yo'q** — layout darajasida himoyalanganmi yoki ataylabmi, aniqlansin |
| 4 | R2 bucket soni drift'i | ✅ | **Yopildi.** Yagona haqiqat manbai — `R2Bucket` enum (`lib/core/storage/r2_upload_client.dart`): **9 ta** bucket (`product-images`, `shop-assets`, `chat-attachments`, `seller-documents`, `verification-docs`, `payment-receipts`, `user-avatars`, `product-ar-scans`, `ai-chat-images`) |
| 5 | Realtime chat subscription'lari | ✅ | **Yopildi.** `WoodyRealtimeService` `chat_message` / `chat_read_receipt` / `order_status_changed` / `notification_created` hodisalarini `eventsOfType()` orqali uzatadi; soket uzilganda refresh + FCM fallback **ataylab** saqlangan |
| 6 | Admin tarif CRUD fan-out | 🔧 | `/tariffs`, `/notifications` UI yakunlash |
| 7 | CSP enforce (marketing) | 🔧 | report-only → enforce o'tkazish |
| 8 | Unsplash → real R2 fotolar (marketing) | 🔧 | Placeholder rasmlarni almashtirish |
| 9 | Enum sinxron validatsiyasi | 🔧 | OrderStatus/VerificationStatus/ProductStatus uch repo drift'i. **Diqqat:** ilovada CI yo'q (2026-09-17), ya'ni avtomatlashtirilsa backend yoki admin pipeline'ida bo'lsin |
| 10 | `.claude/rules/i18n.md` | ✅ | **Yopildi** — rules fayli mavjud va yangilangan |
| 11 | woody_admin/README.md | ✅ | **Yopildi** — haqiqiy mazmun yozilgan, boilerplate emas |
| 12 | `1.0.40+40` relizsiz | 🟡 | **YANGI, shoshilinch.** iOS ITMS-91064 tuzatmasi `main` da, lekin chiqmagan → [tech_debt_roadmap T-01](./tech_debt_roadmap.md) |
| 13 | Ilova CI'si | ⏭️ | **Ataylab olib tashlandi (2026-09-17).** Gate endi mahalliy: `dart analyze lib/ test/` + `flutter test` → T-03 |

---

## Phase 3 — Onlayn to'lovlar (✅ BAJARILDI)

> Maqsad edi: COD-only'dan haqiqiy onlayn to'lovga o'tish. **Bajarildi** —
> Payme va Click ikkalasi ham jonli.

- ✅ **Payme** integratsiyasi — Merchant webhook + 6 RPC + fiskalizatsiya
  **backend tomonda** (`woody_backend`). Ilovada webhook ham, JSON-RPC ham yo'q.
- ✅ **Click** integratsiyasi.
- ✅ Buyurtma ↔ to'lov holat mashinasi. Onlayn to'lov oynasi cheklangan —
  `orders.payment_expires_at` (migration **0095**, 30 daqiqa + "muddati tugayapti"
  push turi).
- ✅ **Komissiya to'lov bilan bog'landi** — `delivered` da
  `settle_wallet_on_delivery`: onlayn buyurtmada Woody pulni ushlab turgan,
  yetkazilgach sotuvchiga `order_income` (brutto − komissiya) kreditlanadi.
  Bu **ichki escrow**, Payme Safe Trade / Split API **emas**.
- ✅ Sotuvchi kartaga yechib olishi — `wallet_withdrawals` (admin tasdiqlaydi).
- ✅ **Ilova tomonidagi deep-link + tiklash relslari** (`lib/shared/payments/`):
  `PaymentRepository.checkoutUrl()` → `launchUrl` → Payme/Click ilovasi →
  qaytganda `PaymentRecoveryGate`. `PendingPaymentStore` **SharedPreferences**
  da (OS ilovani o'ldirsa ham omon qoladi). `PendingPaymentKind` to'rtta relsni
  qamraydi: `order`, `arTokens`, `subscription`, `walletDeposit`.
  `PaymentOutcome.unknown` **hech qachon** muvaffaqiyat deb hisoblanmaydi.
- ✅ Audit izi — hamyon ledger'i (`wallet_transactions`).

**Ochiq cheklov (hujjatlashtirilgan, bug emas):** ko'p-do'konli savat
har do'kon uchun alohida buyurtma yaratadi, lekin **faqat birinchisiga**
to'lov havolasi bog'lanadi.

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
- 🔜 BI / analitika dashboard'lari (sotuv, kohort, LTV).
- 🔜 Strukturali backend observability (metrics, tracing).
- 🔜 OpenAPI'dan mijoz tip codegen (enum drift'ni yo'q qilish).
- 🔜 Store release pipeline, App Store / Play Store. *(Ilova uchun analyze/test CI'si 2026-09-17 da ataylab olib tashlandi — bu band faqat **reliz** avtomatlashtirish haqida, gate haqida emas.)*

---

## Doiradan tashqari (hozircha)

- Web customer ilovasi (faqat mobil + marketing landing).
- Ko'p-do'konli sotuvchi (1 seller = 1 shop invariant).
- Xalqaro yetkazib berish / ko'p valyuta.

---

## O'zgarishlar tarixi

| Sana | O'zgarish |
|---|---|
| 2026-06-12 | Birlashtirilgan roadmap yaratildi; eski Supabase-davri `ROADMAP.md` o'rnini bosdi. |
| 2026-09-17 | **v1.1 — kod bilan yarashtirildi.** Phase 3 (onlayn to'lovlar) 🔜 dan **✅** ga: Payme + Click jonli, ichki escrow ishlayapti. 2026-06 dan beri chiqqan, lekin roadmap'da umuman yo'q bo'lgan sirtlar qo'shildi: AR/3D (Meshy), AI Designer, support chat (ovozli), dinamik Oferta + KYC persist, Meta/maxfiylik, dual analitika. Ochiq bandlar jadvalidan 5 tasi yopildi (#3 #4 #5 #10 #11), 2 tasi qo'shildi (#12 relizsiz versiya, #13 CI olib tashlanishi). |

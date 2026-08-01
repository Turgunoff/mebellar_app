# Woody V2 — Umumiy Texnik Topshiriq (Master TZ)

**Versiya:** 2.0 (Reality-aligned — Supabase-free, woody_backend bo'yicha)
**Sana:** 2026-06-04
**Status:** Living specification — hozirgi holat + kelajak yo'l xaritasi
**Muallif:** Eldor Turg'unov
**Loyiha:** Woody — O'zbekiston uchun premium mebel marketplace

---

> **Bu hujjat nima?**
> `mebellar_v2_tz (1).md` (v2.1, 2026-05-01) **eski arxitektura**ni tasvirlaydi:
> Supabase + email/parol auth + MyID-deferred. Bu rejaning katta qismi
> amalga oshirildi, lekin **asosiy texnologik qarorlar o'zgardi**. Bu hujjat
> (`woody_v2_tz.md`) loyihaning **bugungi haqiqiy holatini** va **kelajak
> bosqichlarini** jamlaydi. Har bir komponentning chuqur TZ'si o'z papkasida:
> - **Backend** → [`woody_backend/woody_backend_tz.md`](woody_backend/woody_backend_tz.md)
> - **Admin panel** → [`woody_admin/woody_admin_tz.md`](woody_admin/woody_admin_tz.md)
> - **Mobil ilova** → [`mebellar_app/woody_mobile_tz.md`](mebellar_app/woody_mobile_tz.md)

---

## 0. Executive Summary

Woody (kod nomi `Woody`) — O'zbekistonda **faqat mebelga ixtisoslashgan**
ikki tomonlama (two-sided) onlayn marketplace. Xaridor va tasdiqlangan
sotuvchini bir platformada bog'laydi.

**Bugungi holat (2026-06-04):** uchala komponent ham **production-ready** va
bitta o'z backend'i atrofida birlashgan. Supabase to'liq olib tashlangan.
Loyiha MVP launch'ga texnik jihatdan tayyor; qolgan asosiy bo'shliq — **real
to'lov integratsiyasi** (hozircha manual/naqd).

| Komponent | Repo | Stack | Deploy | Holat |
|---|---|---|---|---|
| Backend (yagona) | `woody_backend/` | FastAPI · Python ≥3.11 · asyncpg · Alembic · PyJWT · Eskiz · R2 · Redis | `api.woody.uz` (:4001) | ✅ Live |
| Admin panel | `woody_admin/` | Next.js 16 · React 19 · TS · Tailwind v4 · shadcn | `admin.woody.uz` (:3002) | ✅ Live |
| Mobil ilova | `mebellar_app/` | Flutter · Dart ^3.11.5 · flutter_bloc · GetIt · go_router · Firebase | Play / App Store | ✅ v1.0.5+6 |

**Asosiy biznes-modeli:** xaridorlar uchun bepul; daromad sotuvchilardan —
obuna (tarif) + tranzaksiya komissiyasi. Reklama/featured va moliyaviy
xizmatlar V2'da.

---

## 1. Vizyon va Biznes Modeli

*(Manba: Woody Investor Deck — Seed bosqichi, MVP 2026.)*

### 1.1 Muammo

O'zbekistonda mebel asosan oflayn — bozor, ko'rgazma zali, Instagram/Telegram
orqali sotiladi. Yagona, ishonchli raqamli kanal yo'q:

- **Xaridorlar:** narx/sifat/variantlarni solishtirib bo'lmaydi; sharh, reyting,
  kafolat yo'q; "ko'rmasdan" sotib olish xavfli.
- **Sotuvchilar:** barqaror vitrina yo'q (IG/TG'ga bog'liq); buyurtma/mahsulot/
  mijozni qo'lda yuritish; yangi mijoz jalb qilish qimmat va tasodifiy.

### 1.2 Bozor imkoniyati

- $1.2 mlrd — O'zbekiston e-commerce hajmi (2024), chakana savdoning ~3.8%
- 41–47% — yillik o'sish (CAGR 2023–2027, KPMG)
- 32.7 mln internet foydalanuvchi (~87%), aholining 60% — 30 yoshgacha
- Mebel — onlayn xaridda eng kam raqamlashgan yirik kategoriya (ochiq nisha)
- 2027'ga e-commerce $1.8–2.2 mlrd'ga yetishi kutilmoqda

### 1.3 Yechim — vertikal mutaxassis

Umumiy platformalar (Uzum, BirBir) hamma narsani sotadi; Woody faqat mebelni,
lekin **chuqurroq va ishonchliroq**:

- **Tasdiqlangan sotuvchilar** — hujjat asosida KYC + "Verified" belgisi
- **Mebelga xos xizmatlar** — yetkazib berish, montaj, kafolat, buyurtma asosida
- **Saralangan premium katalog** — kategoriyalar, uch til (uz/ru/en), qidiruv+filtr
- **Oddiy va shaffof xarid** — savat, buyurtma kuzatuvi, bildirishnoma, chat

### 1.4 Biznes modeli va daromad oqimlari

| # | Oqim | Holat | Tafsilot |
|---|---|---|---|
| 1 | **Obuna (asosiy)** | ✅ Schema + UI bor, to'lov manual | Free → Basic → Pro → Enterprise oylik tarif |
| 2 | **Komissiya** | ⏳ Schema bor (`commission_rate`), hisoblash V2 | Har sotuvdan 2–5%, GMV bilan o'sadi |
| 3 | **Featured / reklama** | ❌ V2 | Bosh sahifa + qidiruvda pulli joylar |
| 4 | **Qo'shimcha xizmatlar** | ❌ V2 | Pulli yetkazish, bo'lib to'lash ulushi |

**Tarif rejalari (boshlang'ich, `subscription_plans` jadvalida):**

| Tarif | Narx/oy | Mahsulot | Komissiya | Imkoniyatlar |
|---|---|---|---|---|
| Free | 0 so'm | 10 ta | 5% | Asosiy joylashuv |
| Basic | ~99 000 so'm | 100 ta | 3% | + Ustuvor qo'llab-quvvatlash |
| Pro | ~299 000 so'm | Cheksiz | 2% | + Analitika, Featured |
| Enterprise | Kelishuv | Cheksiz | Kelishuv | + Shaxsiy menejer |

> Narxlar illyustrativ — yakuniy tarif `app_settings` + `/admin/tariffs` orqali
> sozlanadi. `tariff_enabled` master-switch tarif tizimini butunlay yoqib/o'chiradi.

### 1.5 Birlik iqtisodiyoti (investor prognozi)

- O'rtacha chek (AOV) ~$200 (≈2.4 mln so'm) — mebel yuqori cheklik
- Platforma take-rate ~4% (obuna + komissiya)
- 1 to'lovchi sotuvchidan oylik ~$40–100
- Marjinal xarajat past (managed infra)

### 1.6 Moliyaviy prognoz (3 yil, konservativ)

| Ko'rsatkich | Yil 1 | Yil 2 | Yil 3 |
|---|---|---|---|
| Ro'yxatdan o'tgan sotuvchilar | 300 | 1 200 | 3 000 |
| To'lovchi sotuvchilar | 60 | 300 | 900 |
| Faol xaridorlar | 8 000 | 40 000 | 130 000 |
| GMV | $1.2 mln | $7.9 mln | $28.8 mln |
| Daromad | $47K | $320K | $1.35 mln |
| EBITDA | –$63K | –$20K | +$350K |

**Investitsiya so'rovi:** $150K–$250K seed, ~18–24 oy runway.

---

## 2. Yuqori darajadagi Arxitektura (hozirgi)

```
┌──────────────────────────┐        ┌──────────────────────────┐
│   mebellar_app (Flutter)  │        │   woody_admin (Next.js)   │
│   customer + seller       │        │   super_admin + manager   │
│   bitta binary, 2 rejim   │        │   admin.woody.uz:3002  │
└────────────┬─────────────┘        └────────────┬─────────────┘
             │  REST (/api/v1) + WebSocket realtime + presigned R2
             │                                     │
             └──────────────────┬──────────────────┘
                                │
                  ┌─────────────▼──────────────┐
                  │     woody_backend (FastAPI) │
                  │     api.woody.uz :4001      │
                  │  • OTP + own JWT (HS256)    │
                  │  • RBAC (roles + scopes)    │
                  │  • asyncpg → Postgres       │
                  │  • Alembic migrations       │
                  │  • WebSocket + Redis fan-out│
                  │  • NotificationDispatcher   │
                  └──────┬───────────┬──────────┘
                         │           │
          ┌──────────────▼──┐   ┌────▼─────────────┐   ┌──────────────┐
          │ Postgres (30 tbl)│   │ Cloudflare R2    │   │ Eskiz / FCM  │
          │ asyncpg, no RLS  │   │ 7 bucket         │   │ SMS / push   │
          └──────────────────┘   └──────────────────┘   └──────────────┘
```

**Asosiy printsip:** `woody_backend` — **yagona** xavfsizlik chegarasi va
ma'lumot manbai. Admin va mobil — sof REST klientlar; ikkalasida ham DB
credential **yo'q**. Realtime — WebSocket feed (`wss://api.woody.uz/api/v1/realtime/ws`),
graceful fallback (refresh-on-open + FCM).

---

## 3. TZ v2.1 → Hozirgi Holat: O'zgarishlar Jadvali (DELTA)

Bu eng muhim bo'lim — eski TZ'dan farqlarni aniq ko'rsatadi.

| Sohа | Eski TZ v2.1 (2026-05-01) | **Hozirgi haqiqat (2026-06-04)** |
|---|---|---|
| **Backend** | "Supabase + Python hybrid" | **Mustaqil FastAPI** — Supabase butunlay olib tashlangan |
| **DB** | Supabase Postgres + RLS | **O'z Postgres** (asyncpg), **RLS yo'q**, Alembic migration |
| **Auth provider** | Supabase Auth | **O'z auth** — PyJWT HS256, backend o'zi token chiqaradi |
| **Auth usuli** | Email + parol (V1), OTP (V2) | **Telefon + OTP (Eskiz)** — birlamchi va yagona usul |
| **Profil yaratish** | Postgres trigger (`handle_new_user`) | OTP verify'da `find_or_create` — `auth.users` yo'q |
| **Storage** | Supabase Storage | **Cloudflare R2** (boto3), 7 bucket, presigned PUT/GET |
| **Realtime** | Supabase Realtime (Postgres CDC) | **O'z WebSocket** + Redis pub/sub fan-out |
| **Signed URL** | Supabase signed URL + Redis cache | R2 presigned (PUT 300s / GET 600s), server-side PUT |
| **Verification** | Manual + MyID (V2) | **Manual KYC** (submission history) — MyID hali yo'q |
| **Push** | OneSignal | **Firebase FCM** (real klient Phase 9 scaffolding) |
| **RBAC** | admin / seller / customer rollar | **super_admin + manager** + delegable scope'lar |
| **Telegram bot** | Rejada bor edi (aiogram) | **Yo'q** — admin panel bu rolni bajaradi |
| **Til (UI matn)** | easy_localization (.json) | Dart `Map` bundle'lar (.arb yo'q), boot-time parity guard |
| **Admin framework** | Next.js 15 + Refine.dev (ehtimol) | **Next.js 16** + shadcn, server components, Refine yo'q |
| **Hosting** | Supabase `eu-central-1` + Fly.io | O'z server (nginx + systemd), `api.woody.uz` |
| **Real to'lov** | V1'da yo'q (mock) | Hali yo'q — manual/naqd; Click/Payme V2 |

**Xulosa:** eski TZ'ning **biznes-mantig'i, schema dizayni, feature scope'i**
asosan saqlanib qoldi. **Infratuzilma butunlay almashtirildi** — vendor
lock-in'dan mustaqillikka o'tildi.

---

## 4. Cross-Repo Invariantlar (uchala repo'da bir xil bo'lishi shart)

Bu qoidalar dizayn bo'yicha takrorlangan. Bittasini o'zgartirsangiz —
qolganlarini ham grep qilib tekshiring. (Manba: umbrella `CLAUDE.md`.)

1. **RBAC** — `ROLE_RULES` (owner-only yo'llar) + `MODERATOR_SCOPES` (delegable
   sohalar) `woody_backend/app/security/rbac.py` **va** `woody_admin/lib/auth/roles.ts`'da
   ko'zgu. Backend — xavfsizlik chegarasi; admin nusxasi faqat nav + tez redirect.
2. **Status enum'lar** — `OrderStatus`, `VerificationStatus`, `ProductStatus`
   uch joyda: `woody_backend/app/domain/enums.py`, `woody_admin/lib/enums.ts`,
   `mebellar_app/lib/`'dagi Dart enum'lar. Nom + transition bir xil.
3. **`SUPER_ADMIN_PHONE`** — yagona manba: `woody_backend` env var. `super_admin`
   ning yagona granti. Rotatsiya oldingi egasini chiqaradi — barcha callerlar bilan
   muvofiqlashtiring.
4. **Eskiz SMS template + `OTP_LENGTH=5`** — `woody_backend` egasi, Eskiz
   dashboard'dagi tasdiqlangan template bilan **belgima-belgi** mos. Qayta
   tasdiqlash soatlar oladi.
5. **Banner field mapping** — `woody_admin/.../banner-form.tsx` ↔ Flutter
   `glass_banner.dart`. DB `title` = kichik eyebrow, `subtitle` = katta sarlavha.
   Tap = `action_type` + `action_value`.
6. **API kontrakt** — `woody_backend` yagona manba. Endpoint qo'shsangiz/o'zgartirsangiz,
   admin `lib/queries|actions` va app `Woody*Repository`'larni moslang.

---

## 5. Hozirgi Implementatsiya Holati (umumiy matritsa)

| Soha | Backend | Admin | Mobile | Izoh |
|---|---|---|---|---|
| Auth (telefon+OTP+JWT) | ✅ | ✅ | ✅ | OTP autofill (iOS QuickType / Android SMS Consent) |
| RBAC (rol + scope) | ✅ | ✅ | — | super_admin + scoped manager |
| Katalog (kategoriya/mahsulot/banner/news) | ✅ | ✅ | ✅ | uz/ru/en multilingual |
| Dinamik kontent i18n (tarjima boshqaruvi) | ✅ (0026) | ✅ (2026-06-11) | ⚠️ o'qish ✅ (`Accept-Language`), seller tarjima kiritish yo'q | `uz` faqat base kolonkalarda; admin uz/ru/en formalar + «Tarjimalar» kartasi, raw i18n o'qiydi |
| Qidiruv + filtr | ✅ | — | ✅ | adaptiv facet visibility |
| Savat | ✅ | — | ✅ | server-side (`/customer/cart`) |
| Sevimlilar | ✅ | — | ✅ | server-side sync |
| Checkout / buyurtma yaratish | ✅ (`POST /customer/orders`) | — | ✅ | manzil: Yandex map + fallback |
| Buyurtma kuzatuvi | ✅ | ✅ (view) | ✅ | status banner |
| Buyurtma bekor qilish | ✅ | — | ✅ | `pending`/`confirmed` dan |
| Per-order chat | ✅ | — | ✅ | matn + rasm, realtime, read receipt |
| Reviews | ✅ (yozish+o'qish) | ✅ (moderatsiya) | ✅ | mijoz yozadi, sotuvchi javob beradi |
| Seller onboarding + KYC | ✅ | ✅ (queue) | ✅ | submission history, manual approve |
| Seller mahsulot CRUD | ✅ | ✅ (moderatsiya) | ✅ | R2 image upload, atributlar |
| Seller buyurtma boshqaruvi | ✅ | — | ✅ | status transition |
| Seller analitika | ✅ | ✅ (global) | ✅ | fl_chart |
| Seller dashboard | ✅ | ✅ (admin KPI) | ✅ | KPI snapshot |
| Tarif / obuna | ✅ | ⚠️ (display+toggle) | ✅ | to'lov manual (screenshot) |
| Bildirishnoma (inbox) | ✅ | ✅ (broadcast) | ✅ | realtime + FCM fallback |
| Push fan-out (FCM real) | ⚠️ NoOp default | ⚠️ kutilmoqda | ✅ klient tayyor | `FCM_SERVICE_ACCOUNT_PATH` gated |
| Storage (R2) | ✅ | ✅ | ✅ | 7 bucket, presigned |
| Realtime (WebSocket) | ✅ | — | ✅ | Redis fan-out, graceful fallback |
| **To'lov gateway** | ❌ | ❌ | ❌ | Click/Payme/Uzum — V2 |
| **MyID verifikatsiya** | ❌ | ❌ | ❌ | manual KYC — V2 |
| **Featured / reklama** | ❌ | ❌ | ❌ | V2 |

✅ tayyor · ⚠️ qisman/scaffolding · ❌ yo'q

---

## 6. Asosiy Bo'shliqlar (next-stage uchun)

Quyidagilar — keyingi bosqichda ishlab chiqiladigan aniq ishlar:

1. **Real to'lov integratsiyasi** — Click va/yoki Payme. Kerak: payment webhook
   router'lari, `payments` jadvali (hozir faqat `subscription_receipts` manual),
   buyurtma to'lovi va tarif to'lovi uchun avtomatik tasdiqlash.
2. **FCM real klient** — backend'da `FcmClient` (firebase-admin) `NoOpFcmClient`
   o'rniga; `FCM_SERVICE_ACCOUNT_PATH` o'rnatilganda yoqiladi. Mobil klient tayyor.
3. **Realtime chat subscriptions** — `/realtime/ws` hozir `subscribe_chat` frame'larini
   e'tiborsiz qoldiradi (Phase 8.1 placeholder). Chat realtime hozir
   `notification_created` orqali ishlaydi.
4. **Admin tarif CRUD** — `/tariffs` faqat display + master-switch; reja CRUD
   "keyingi sprint" deb belgilangan. Backend `POST/PATCH/DELETE /admin/tariffs` kerak.
5. **Admin broadcast push fan-out** — in-app bildirishnoma yuboriladi; mobil
   qurilmalarga push FCM real klientga bog'liq.
6. **Mobil broadcast ekranlari** — `/promo/:id`, `/news/:id`, `/system-alert/:id`
   hozir `BroadcastPlaceholderScreen` (routing tayyor, UI kerak).
7. **MyID verifikatsiya** — manual KYC ishlaydi; MyID OAuth/Document API V2.
8. **Komissiya hisoblash** — `commission_rate` schema'da bor, lekin buyurtmada
   komissiya hisoblanmaydi/yig'ilmaydi — to'lov bilan birga keladi.
9. **Guest cart / offline** — savat hozir faqat server-side; mehmon savati keyinroq.
10. **Seller tomonda tarjima kiritish** — dinamik kontent i18n'ning
    kontent-boshqaruv (admin) tomoni **2026-06-11'da shipped** (migration
    `0026` + admin tarjima formalari, `PATCH /admin/products/{id}/translations`).
    Qolgan bo'shliq: seller (Flutter) tomonda o'z mahsulotiga ru/en tarjima
    kiritish — keyingi bosqich.

---

## 7. Yo'l Xaritasi (Roadmap)

Investor deck GTM bosqichlari + texnik holatga moslangan.

### Faza 1 — Launch (0–3 oy) — **deyarli tayyor**
- ✅ MVP texnik tayyor (uchala komponent)
- ✅ Manual KYC verifikatsiya, naqd/manual to'lov
- ⏳ Dastlabki 50–100 sotuvchi (IG/TG mebel sotuvchilari) — operatsion
- ⏳ Play Console / App Store submission, marketing landing
- ⏳ FCM real klientni yoqish (push)

### Faza 2 — O'sish (3–9 oy)
- **Click / Payme to'lov integratsiyasi** (buyurtma + tarif)
- MyID verifikatsiya (manual fallback bilan)
- Komissiya hisoblash va sotuvchi hisob-kitobi
- Realtime chat subscriptions (to'liq WebSocket)
- Admin tarif CRUD, broadcast push fan-out
- 3–4 yirik shahar qamrovi

### Faza 3 — Masshtab (9–18 oy)
- Featured / reklama daromadi (bosh sahifa + qidiruvda pulli joylar)
- Bo'lib to'lash / moliyalashtirish
- Butun respublika qamrovi
- Advanced analitika, multi-shop (schema tayyor)
- Mehmon savati, web app (ehtimol)

---

## 8. Texnologiya Stack Xulosasi

| Layer | woody_backend | woody_admin | mebellar_app |
|---|---|---|---|
| Til | Python ≥3.11 | TypeScript (strict) | Dart ^3.11.5 |
| Framework | FastAPI | Next.js 16 (App Router) | Flutter |
| UI | — | React 19 + Tailwind v4 + shadcn | flutter_bloc + go_router |
| DB/Data | asyncpg → Postgres | apiFetch → backend | Woody*Repository → REST |
| Auth | PyJWT HS256 + Eskiz OTP | httpOnly cookie + /me | TokenStore + OTP |
| Storage | Cloudflare R2 (boto3) | presigned (server-side PUT) | R2UploadClient |
| Realtime | WebSocket + Redis | — | WoodyRealtimeService |
| Push | FCM (NoOp default) | — | firebase_messaging |
| Migration | Alembic | — | — |
| Test | pytest (~215) | tsc + lint | flutter test (41 fayl) |
| Deploy | nginx+systemd, GH Actions | nginx+systemd, GH Actions | build_release.sh → store |

---

## 9. Deployment va Infratuzilma

| Komponent | URL / Port | Deploy oqimi |
|---|---|---|
| Backend | `api.woody.uz` :4001 | push→main → GH Actions → SSH → `git reset --hard` → `pip install -e '.[dev]'` → `woody migrate` → `systemctl restart woody-backend` → health-check |
| Admin | `admin.woody.uz` :3002 | push→main → SSH → `npm ci` → `npm run build` → `systemctl restart woody-admin` |
| Mobile | Play / App Store | `./tools/build_release.sh` (AAB, obfuscated, split-debug-info) |

- **Migration** prod'da `woody migrate` diskret CI qadami sifatida, restart'dan
  oldin. `AUTO_MIGRATE=true` prod'da **emas**.
- Mahsulot rasmi/banner/KYC — barchasi R2 presigned PUT orqali.

---

## 10. Risklar va Ochiq Savollar (yangilangan)

| Risk / savol | Holat | Izoh |
|---|---|---|
| Real to'lov yo'qligi | **Ochiq** | Faza 2 blokeri; manual to'lov launch uchun yetadi |
| FCM real klient | Scaffolding | Service account + `FCM_SERVICE_ACCOUNT_PATH` kerak |
| MyID yuridik shaxs talabi | Ochiq | API uchun YaTT/MChJ + 2–4 hafta approval |
| Komissiya yig'ish mexanizmi | Ochiq | Online to'lov bilan keladi (escrow yoki direct?) |
| Solo dev yuk | Doimiy | MVP scope qattiq, scope creep'ga "yo'q" |
| App Store / Play moderatsiya | Ochiq | Privacy Policy, ToS, test akkaunt kerak |
| Dispute / refund siyosati | Ochiq | Kim qaror qiladi — admin? refund flow? |
| Yetkazib berish modeli | Hal | Har sotuvchi o'zi (V1); umumiy logistika V2 |

---

## 11. Komponent TZ'lariga Yo'naltirgich

Har bir komponentning to'liq, chuqur texnik topshirig'i o'z papkasida:

| Hujjat | Joylashuv | Mazmun |
|---|---|---|
| **Backend TZ** | [`woody_backend/woody_backend_tz.md`](woody_backend/woody_backend_tz.md) | API surface (60+ endpoint), 30 jadval schema, RBAC, integratsiyalar, migration'lar, test |
| **Admin TZ** | [`woody_admin/woody_admin_tz.md`](woody_admin/woody_admin_tz.md) | Sahifa/route xaritasi, RBAC wiring, data layer, feature matritsa, styling |
| **Mobile TZ** | [`mebellar_app/woody_mobile_tz.md`](mebellar_app/woody_mobile_tz.md) | Customer + seller feature'lar, shared modullar, core infra, API klient, build/release |

---

**Hujjat oxiri.**

> Eslatma: bu "living spec". Har bosqichdan keyin shu hujjatni va tegishli
> komponent TZ'sini yangilab boring. Eski `mebellar_v2_tz (1).md` tarixiy
> manba sifatida saqlanadi (biznes-mantiq + schema dizayn fikrlash).

# Mebellar — To'liq Texnik Topshiriq (TZ)

> **Loyiha:** Mebellar — O'zbekiston bozori uchun ikki tomonli (B2C/C2C) mebel marketplace.
> **Ichki kod nomi:** `woody_app` (`pubspec.yaml` → `name:`)
> **Brend:** Mebellar (`uz.mebellar.app` / `com.mebellar.app`)
> **Hujjat sanasi:** 2026-05-19
> **Versiya:** V1 (MVP) — Code Complete bosqichida (`dart analyze` toza, 192 test o'tadi)
> **Maintainer:** Eldor Turg'unov (`Turgunoff`)

---

## Kirish — Ushbu Hujjat Haqida

Ushbu hujjat ikki qismdan iborat:

- **1-QISM — INVESTORLAR UCHUN.** Loyihaning biznes-mohiyati, bozor imkoniyati, monetizatsiya modeli, raqobat muhiti, joriy holati va keyingi yo'l xaritasi. Texnik chuqurlikka kirmaydi.
- **2-QISM — DASTURCHILAR UCHUN.** To'liq texnik spetsifikatsiya: tech stack, arxitektura, har bir feature, qolgan ishlar, ma'lum bug'lar va texnik qarz reestri, build/test/release qoidalari. Yangi qo'shilgan dasturchi loyihani 1-2 kun ichida tushunib olishi uchun yetarli.

Ikkala qism **bitta loyihani** turli o'qish prizmasidan tasvirlaydi — kontekst birxil, lekin chuqurlik va terminologiya farqli.

---

# 1-QISM — INVESTORLAR UCHUN

## 1.1 Executive Summary

**Mebellar** — O'zbekistonda mebel sotib olish va sotishni raqamlashtiradigan ikki tomonli mobil marketplace. Bir tomonida xaridorlar — istalgan joydan mebel topa olish, narxlar taqqoslay olish va buyurtma kuzatib borish imkoniyatiga ega. Boshqa tomonida sotuvchilar — mahalliy do'kondorlar va ishlab chiqaruvchilar — yagona ilova orqali do'konini boshqarish, mahsulot joylash, buyurtmalarni qabul qilish va analitika ko'rish imkoniyatiga ega.

Asosiy farqli xususiyat: **bitta foydalanuvchi** ham xaridor, ham sotuvchi bo'la oladi, va ilovani qayta o'rnatmasdan, real-time rejimida ikki interfeys o'rtasida almashtira oladi.

**Joriy holat:** V1 (MVP) versiyasi funksional darajada **kod yozib bo'lingan**, statik analiz toza, 192 ta avtomatik test o'tadi. Backend Supabase'da to'liq joylashtirilgan (RLS bilan himoyalangan, 23 ta migratsiya bajarilgan). Asosiy texnik qarz — sotuvchi tomonidagi mahsulot/buyurtma jo'natish flow'larini test holatidan jonli backend'ga ulash (taxminan 1-2 hafta ishi).

## 1.2 Bozor Imkoniyati

### 1.2.1 Maqsadli bozor

- **Geografiya:** O'zbekiston (Markaziy Osiyo bozoriga kengayish potentsiali bilan)
- **Aholi:** ~36 mln; shaharlashish darajasi 50%+; o'sib borayotgan o'rta sinf
- **Mobil penetratsiya:** O'zbekistonda smartfon penetratsiyasi >85%, mobile-first audience
- **E-commerce kuchayishi:** Uzum, Sello, Olcha kabi platformalar bozorni "tarbiya" qildi; foydalanuvchilar onlayn sotib olishga ko'nikkan

### 1.2.2 Mebel niche'ining xususiyatlari

- **Yuqori chek (high AOV).** Bitta mebel buyurtmasi o'rtacha $200–$2,000 oralig'ida — universal marketplace'lardagi $10–$30 chekka qaraganda har bir tranzaksiya komissiyasi yuqori
- **Vizual kategoriya.** Mahsulot fotosurati va o'lchamlari muhim — bu mobil ilovaga ishlash uchun yaxshi mos keladi
- **Mahalliy logistika.** Mebel jo'natish murakkab, bu markazlashgan logistikani majburlamaydi — sotuvchilar o'z yetkazib berishini o'zlari uyushtiradi (Mebellar logistik xarajat ko'tarmaydi)
- **Hozir to'g'ridan-to'g'ri raqobatchi yo'q.** O'zbekistonda **faqat mebel'ga ixtisoslashgan** marketplace yo'q — universal platformalardagi mebel bo'limi sayoz va ishonchsiz

### 1.2.3 Sotuvchi tomoni (B2B uchun motivatsiya)

Mahalliy mebel sotuvchilarining katta qismi:

- Instagram va Telegram orqali sotadi — buyurtmalarni qo'lda qabul qiladi
- O'z onlayn-do'koni yo'q (texnik to'siq + xarajat)
- Mahsulot, buyurtma, mijoz ma'lumotlarini tizimli yuritmaydi

Mebellar bu sotuvchilarni bir necha daqiqada onlayn-faol qiladi: ro'yxatdan o'tish → do'kon yaratish → mahsulot joylash → buyurtma qabul qilish. **DIY tariffidagi Free plan** texnik to'siqni butunlay olib tashlaydi.

## 1.3 Mahsulot Ko'rinishi

### 1.3.1 Xaridor uchun (Customer surface)

- Katalog: ko'p darajali kategoriyalar, banner'lar, premium home bloklari, tanlangan do'konlar
- Search: real-time, debounced, full-text
- Mahsulot sahifasi: rasm galereya, ta'rif, xususiyatlar, do'kon kartasi, "Verified ✓" rozetka
- Cart va Favorites: oflayn ishlaydi (Hive cache) + login bo'lgan zahoti backend'ga sinxronlash
- Checkout: Yandex map'da manzil tanlash, ko'p qadamli flow
- Buyurtmalar: ro'yxat, holat timeline, **real-time tracking** (Supabase Realtime)
- Profil: manzillar daftari, tilni almashtirish, sotuvchi rejimiga o'tish
- Onboarding tutorial (ilk kirishda)
- Bildirishnomalar (push + ilovadagi inbox)

### 1.3.2 Sotuvchi uchun (Seller surface)

- Multi-step onboarding (welcome → biznes turi → shaxsiy ma'lumot → do'kon → manzil → hujjat → tasdiq)
- KYC verifikatsiya (passport / hujjat yuklash)
- Dashboard: KPI kartalar, asosiy metrikalar
- Mahsulot CRUD: ko'p bo'limli forma (asosiy ma'lumot, narx, logistika, media, xususiyat)
- Buyurtmalar boshqaruvi (real-time yangi buyurtma signali bilan)
- Do'kon sozlamalari: ish vaqti, xizmatlar (yetkazib berish/montaj/garantiya/bo'lib to'lash), ko'rinish, brending
- **Tarif rejasi** va yangilash flow'i
- Analitika va sharhlar
- Bildirishnomalar

### 1.3.3 Texnik o'ziga xoslik (qisqacha)

- **Bir ilova, ikki tomon.** Mobil ilova qayta o'rnatishni talab qilmaydi — Profile'dagi tugma orqali real-time tomonga o'tish (DI scope almashtirish + `flutter_phoenix` orqali widget tree qayta qurish)
- **Ko'p tilli.** uz / ru / en — to'liq tarjima (322 ta kalit, drift 0)
- **Oflayn-tolerantli.** Cart va Favorites internet yo'qligida ham ishlaydi; ulanish tiklanganda avtomatik sinxron
- **Real-time.** Buyurtma holati va yangi buyurtmalar push qilinmasdan, websocket orqali yangilanadi

## 1.4 Biznes Modeli va Monetizatsiya

V1'da daromad oqimi **birlamchi sotuvchi tarifidan** olinadi. Xaridorlar uchun ilova **bepul** (komissiyasiz).

### 1.4.1 Sotuvchi tarif rejalari

| Tarif | Narx | Asosiy imkoniyat |
| --- | --- | --- |
| **Free** | 0 so'm | 10 ta mahsulot, 5% komissiya |
| **Basic** | 99,000 so'm/oy | 100 ta mahsulot, 3% komissiya |
| **Pro** | 299,000 so'm/oy | Cheksiz mahsulot, 2% komissiya, Analytics |
| **Enterprise** | Custom | Custom imkoniyatlar (yirik retailer'lar uchun) |

> Komissiya foizlari hozircha taxminiy; jonli pilot davomida tasdiqlash kerak.

### 1.4.2 To'lov modeli (V1 muvaqqat)

V1'da **rasmiy to'lov gateway YO'Q**. Sotuvchi:

1. Platformaning Humo/Uzcard kartasiga **P2P pul o'tkazadi**
2. To'lov skrinshotini ilovaga yuklaydi
3. Admin qo'lda tasdiqlaydi → tarif yangilanadi

Bu V1 uchun ataylab tanlangan vaqtinchalik yechim: gateway integratsiyasi (Click/Payme/Octo) **V2 strategik kechiktirish** sifatida yo'l xaritasida — pilot foydalanuvchilar bilan dastlabki tasdiqdan keyin amalga oshiriladi.

### 1.4.3 Xaridor to'lovi (V1)

Naqd to'lov yetkazib berishda (Cash on Delivery) yoki sotuvchi bilan P2P kelishuv. **V1 customer payment gateway integratsiyasini ham qamramaydi** — bu ham V2.

### 1.4.4 Bo'lajak daromad oqimlari (V2+)

- **Tranzaksiya komissiyasi** (gateway integratsiyasidan keyin)
- **Premium listing** (top-of-search joylash, reklama bannerlar)
- **Featured shops** (homepage tanlanishi)
- **Sotuvchi uchun qo'shimcha xizmatlar** (kreditga sotish, reklama, biznes-kreditlar)
- **Data/analytics** (sotuvchilar uchun bozor tahlili — premium)

## 1.5 Joriy Texnik Holat

> Quyidagi metrikalar **2026-05-16 holatiga ko'ra** olindi.

| Ko'rsatkich | Qiymat |
| --- | --- |
| Dart fayllar | 360 ta (`lib/` ostida) |
| Kod hajmi | ~59,800 qator |
| Statik analiz (`dart analyze`) | **0 issue** |
| Avtomatik testlar | **192/192 yashil** (45 ta test fayli) |
| Backend migratsiyalar | 23 ta ordered SQL migration |
| RLS qamrovi | Har bir jadval uchun yoqilgan |
| Tarjima qamrovi | uz/ru/en — 322 kalit, 0 drift |
| TODO/FIXME/HACK markerlari | `lib/` ostida 0 ta |

**Xulosa:** Loyiha V1 funksional doirasi uchun **kod yozib bo'lingan**. Qolgan ish — sotuvchi tomonini test holatidan jonli backend'ga ulash, lifecycle hardening, va bir nechta kod-tashkiliy yaxshilanishlar. Hech qaysisi V1'ni blok qilmaydi.

## 1.6 Strategik Yo'l Xaritasi

Yo'l xaritasi **ataylab uch fazaga** bo'lingan:

### 1.6.1 V1 — Pilot Launch (joriy faza)

Hozir tugatilayotgan. Qolgan ishlar:

1. **Sotuvchi backend'ini faollashtirish** (1-2 hafta): jonli buyurtma lifecycle'ini end-to-end tekshirish; mock'lardan jonli Supabase'ga o'tkazish
2. **Xavfsizlik tozalovi** (1 kun): tasodifan commit qilingan Firebase Admin SDK kalitini rotatsiya qilish
3. **Stabillik hardening** (3-4 kun): lifecycle/cancellation tozalovi
4. **Pilot foydalanuvchilar:** 5-10 ta tanish sotuvchi va 20-30 ta xaridor bilan invitatsion test
5. **Store submission:** Play Store va App Store'ga yuborish

**V1 vaqt belgisi:** Pilot uchun tayyor — 2-3 hafta. Store submission — qo'shimcha 2-4 hafta (store review davriga bog'liq).

### 1.6.2 V2 — Public Launch (taxminan 3-6 oy)

- **Real to'lov gatewayi** (Click / Payme / Octo / P2P-to-card — partner tanlash)
- **Web ilova** (Flutter Web yoki Next.js — qaror qabul qilinmagan)
- **Featured/Premium listing** monetizatsiya kanali
- **Promo kodlar, kuponlar**
- **SMS OTP** (faqat email'ga qo'shimcha)
- **MyID integratsiya** (verifikatsiyani avtomatlashtirish)
- **In-app chat** (xaridor ↔ sotuvchi)
- **Multi-currency** (UZS dan tashqari USD/RUB ko'rsatish)

### 1.6.3 V3 — O'sish va Kengayish (6-12 oy)

- **Markaziy Osiyo bozori** (Qozog'iston, Qirg'iziston, Tojikiston)
- **B2B (ulgurji) modul** — ishlab chiqaruvchilar uchun
- **Logistika hamkorliklari** (uchinchi tomon yetkazib berish operatorlari)
- **Reklama platformasi** (sotuvchilar uchun)
- **AI-powered katalog tasnif/qidiruv**

### 1.6.4 Ataylab QAMRALMAGAN (loyiha asoschisi tomonidan)

Quyidagilar joriy yo'l xaritasidan **chiqarib tashlangan**:

- CI/CD pipeline (GitHub Actions va boshqalar)
- Shorebird code-push integratsiyasi
- App Store / Play Store avtomatlashtirilgan release flow'i
- Marketing, ASO, growth hacking
- On-call / DevOps jarayoni

Sababi: joriy strategik pivot **faqat kod sifati va funksional to'liqligiga** qaratilgan. Operational konvert keyingi planning siklida ochiladi.

## 1.7 Raqobat Tahlili

| Raqobatchi | Mebellar uchun tahdid darajasi | Izoh |
| --- | --- | --- |
| **Uzum Market** | O'rta | Universal marketplace; mebel — kichik bo'lim; CX general |
| **Sello / OLX** | Past | Klassifayd model — sotuvchi-shop tushunchasi yo'q, ishonch past |
| **Olcha** | Past | Asosan elektronika |
| **Yandex Market** | Past | Hali O'zbekistonda kuchli emas |
| **Instagram + Telegram** | Yuqori (joriy lider) | Hozir sotuvchilarning 70-80%i shu yerda; lekin tartibsiz, kuzatib bormaydi |
| **IKEA, Hoff (offline)** | O'rta | Premium segment, narx bilan raqobat qila olmaydi |

**Differentsiatsiya yo'lboshlari:**

1. **Niche fokus** — universal'lardan ko'ra chuqurroq mebel-specific UX (xona o'lchami filtri, montaj turi, garantiya muddati va h.k.)
2. **Sotuvchi'larga past texnik to'siq** — 5 daqiqada faol bo'lish
3. **Mahalliylashtirish** — uz/ru tarjima, mahalliy to'lov, Yandex Maps
4. **Ikki tomonli arxitektura** — bir foydalanuvchi ham xaridor, ham sotuvchi (ko'p kichik biznes oilada)

## 1.8 Asosiy Risklar

| Risk | Ehtimollik | Ta'sir | Yumshatish strategiyasi |
| --- | --- | --- | --- |
| **Sotuvchilar Instagram'dan ko'chmaslik** | Yuqori | Yuqori | Free plan + qo'lda onboarding (concierge); video tutorials |
| **To'lov gateway integratsiyasi cho'zilishi** | O'rta | O'rta | V1'da P2P bilan ishlash, V2'da gateway — bu shuni to'sa olmaydi |
| **Universal marketplace mebel bo'limini kuchaytirishi** | O'rta | Yuqori | Niche UX afzalligi; mebel-specific feature'lar (size visualizer, AR room preview V3) |
| **Verifikatsiya manual jarayon, scaling** | O'rta | O'rta | V2'da MyID integratsiya; admin tooling |
| **Yagona maintainer bog'liqligi (bus factor 1)** | Yuqori | Yuqori | Hujjatlar to'liq; ikkinchi muhandis qo'shilishi tavsiya etiladi |
| **Mahalliy logistika sifati past** | Yuqori | O'rta | Sotuvchining o'z logistikasi modeli — Mebellar logistic xarajat ko'tarmaydi |

## 1.9 Jamoa va Operatsion Holat

- **Lead developer:** Eldor Turg'unov (`Turgunoff`) — yagona muhandis (full-stack: Flutter + Supabase + DB)
- **Hozirgi quvvat:** 1 FTE
- **Tavsiya:** Pilot phasedan keyin 1 ta backend muhandis va 1 ta QA/manual tester qo'shish

## 1.10 Investitsiya Imkoniyati va Foydalanish

> Bu bo'lim **investor-bog'liq raqamlar bilan to'ldirilishi kerak** — loyiha asoschisi tomonidan investitsiya kerakli summa, evaluation, exit strategiya va investor uchun stake taklif qilinmagan. Pastdagi struktur namuna sifatida saqlangan.

Investitsiya quyidagilarga sarflanishi mumkin (prioritet tartibida):

1. **Ikkinchi muhandis** (bus factor 1 risk yumshatish) — backend + DB
2. **Mahsulot menejeri / dizayner** — UX iteratsiya, pilot fikrlarga ishlov
3. **Sotuvchi onboarding** — concierge model uchun community manager
4. **Marketing kanali** — Telegram/Instagram kampaniyasi (mebel sotuvchilari aud.)
5. **To'lov gateway sertifikatsiya** — Click/Payme partner kelishuvi va integratsiyasi
6. **Server xarajatlari** — Supabase Pro plan, FCM, Yandex Geocoder kvota
7. **Yuridik** — Privacy Policy, ToS, foydalanuvchi shartnomasi (yurist)

## 1.11 Investor uchun Yakuniy Tezis

- ✅ **Mahsulot tayyor** — kod yozib bo'lingan, test'lar yashil
- ✅ **Aniq monetizatsiya yo'li** — sotuvchi tarifi, ishlab chiqilgan biznes modeli
- ✅ **Aniq bozor bo'shlig'i** — O'zbekistonda mebel-specific marketplace yo'q
- ✅ **Past CAPEX** — logistika va inventar bog'liqligi yo'q
- ⚠️ **Yagona muhandis (bus factor 1)** — diversifikatsiya talab qilinadi
- ⚠️ **Gateway integratsiyasi V2'ga kechiktirilgan** — V1'da daromad faqat tarif'dan
- ⚠️ **Validatsiya hali yo'q** — pilot foydalanuvchilar bilan early signal kerak

---

# 2-QISM — DASTURCHILAR UCHUN

> **Maqsad:** Bu qism yangi qo'shilgan dasturchini 1-2 kun ichida kodbazaga to'liq jalb qilish uchun yetarli kontekst beradi. Har bir bo'lim aniq fayllar, qator raqamlari va arxitektura qarorlariga havola qiladi.

## 2.1 Boshlash — 30 Daqiqada Kodbazaga Kirish

### 2.1.1 Talablar

- Flutter `3.11+`, Dart `3.11+`
- Android SDK 21+ yoki Xcode 15+
- Supabase project'iga kirish (URL + anon key)
- Firebase project'iga kirish (FCM uchun)

### 2.1.2 Klon va o'rnatish

```bash
git clone <repo-url> mebellar_app
cd mebellar_app
flutter pub get
```

### 2.1.3 Ishga tushirish

```bash
# Yagona env fayli (prod.json) bilan ishga tushirish
flutter run --dart-define-from-file=env/prod.json

# Statik analiz — har doim 0 issue qaytarishi kerak
dart analyze

# To'liq test to'plami — 192 ta test
flutter test
flutter test --coverage          # coverage report bilan
flutter test integration_test    # end-to-end test (qurilma kerak)

# Format
dart format lib/ test/
```

### 2.1.4 Birinchi navbatda nima o'qish

Kodga chuqur kirmasdan oldin quyidagi tartibni rioya qiling:

1. `README.md` — loyiha haqida umumiy ma'lumot
2. `docs/PROJECT_STATE_ANALYSIS.md` — joriy holat va texnik qarz
3. `ARCHITECTURE.md` — chuqur sistema dizayni
4. `ROADMAP.md` — qolgan ishlar
5. `lib/main.dart` → `lib/core/di/service_locator.dart` — bootstrap va DI

## 2.2 Tech Stack

| Qatlam | Tanlov | Versiya |
| --- | --- | --- |
| Framework / til | Flutter / Dart | `3.11+` |
| State management | `flutter_bloc` | `^9` |
| Event transformer'lar | `bloc_concurrency` | — |
| DI | `get_it` | `^8` |
| Routing | `go_router` | `^14` |
| Backend SDK | `supabase_flutter` | `^2.8` |
| Push | `firebase_messaging` + `flutter_local_notifications` | — |
| Local DB | `hive` + `flutter_secure_storage` | — |
| Networking | `dio` / `http` | — |
| Map / location | `yandex_mapkit`, `geolocator`, `permission_handler` | — |
| Logging | `talker_flutter` | — |
| Crash reporting | `sentry_flutter` | — |
| Runtime restart | `flutter_phoenix` | — |
| Charts / UI | `fl_chart`, `cached_network_image`, `flutter_staggered_grid_view`, `shimmer`, `iconsax_flutter` | — |

**Dev tooling:** `flutter_lints`, `bloc_test`, `mocktail`, `integration_test`, `flutter_native_splash`, `flutter_launcher_icons`.

### 2.2.1 ATAYLAB STACK'DA EMAS

Ba'zi eski hujjatlarda eslatilgan bo'lishi mumkin, lekin **hozirgi kodbaza ulardan foydalanmaydi**:

- ❌ `easy_localization` — qo'lda yozilgan i18n bilan almashtirilgan (`lib/core/i18n/`)
- ❌ `onesignal_flutter` — FCM bilan almashtirilgan
- ❌ `google_fonts` paketi — shriftlar (`Inter`, `Manrope`, `PlayfairDisplay`, `PlusJakartaSans`) **bundle'da TTF** sifatida ko'mil­gan

> Yangi paket qo'shsangiz, avval `pubspec.yaml` va `ARCHITECTURE.md` §2 ni o'qing — bu qarorlar ataylab.

## 2.3 Arxitektura Umumiy Ko'rinishi

Ilova **uch qatlamli (UI → Logic → Data)** + **dual-mode runtime** patterni asosida qurilgan.

### 2.3.1 Qatlamlar

```
UI (Screens / Widgets)
     │   reads state · dispatches events
     ▼
Logic (BLoC / Cubit)               ← flutter_bloc
     │   awaits
     ▼
Data (Repository interface)
     │   resolved by RepositoryResolver
     ├── Supabase*Repository       ← jonli backend
     └── Mock*Repository           ← canned data
```

### 2.3.2 Yangi dasturchi bilishi shart bo'lgan patternlar

| Pattern | Joylashuv | Ma'no |
| --- | --- | --- |
| **`Result<T, Failure>`** | `lib/core/result/result.dart`, `lib/core/error/failure.dart` | Repository metodlari `Ok` / `Err` qaytaradi, exception tashlamaydi. Caller pattern-match qiladi. |
| **`RepositoryResolver`** | `lib/core/di/repository_resolver.dart` | `AppConfig.useMocks` bo'yicha `Mock*` yoki `Supabase*` impl tanlaydi. Release build mock graph'ini tree-shake qiladi. |
| **Scoped DI (`get_it`)** | `lib/core/di/` | **root scope** (cross-cutting singletonlar) + **mode scope** (`customer` / `seller` — har mode switchda almashtiriladi). Registratsiya `*_module.dart` fayllariga bo'lib chiqilgan. |
| **Runtime mode switch** | `AppModeCubit` + `flutter_phoenix` | `popScope()` → `initModeScope(mode)` → `Phoenix.rebirth()` |
| **Qo'lda yozilgan i18n** | `lib/core/i18n/` | Pure-Dart map; debug-only guard ru/en uz baseline'dan past tushganda boot'ni to'xtatadi |

## 2.4 Loyiha Struktura

```
mebellar_app/
├── android/ · ios/            # native projects (incl. FCM config)
├── assets/                    # bundle'dagi font + brand logo
├── docs/
│   ├── PROJECT_STATE_ANALYSIS.md
│   ├── supabase_rls_policies.sql.md
│   └── legacy/                # arxivga olingan eski uz-deep dive'lar
├── env/
│   ├── example.json           # commit qilingan template
│   └── prod.json              # yagona ishlovchi env fayli
├── supabase/
│   ├── migrations/            # 23 ordered SQL migrations
│   └── functions/             # send-news-broadcast Edge Function
├── lib/
│   ├── main.dart              # bootstrap → Firebase → DI → Phoenix mode router
│   ├── config/                # AppConfig + AppMode enum
│   ├── core/                  # DI, auth, network, i18n, theme, result, logging…
│   ├── shared/                # cross-mode models, repositories, mocks, widgets
│   ├── auth/                  # shared login / register / verify / OTP screens
│   ├── customer/              # customer surface — features/, services/, widgets/
│   └── seller/                # seller surface — features/, services/, widgets/
├── test/                      # lib/ ni AYNAN MIRROR qiladi
│   └── goldens/               # golden baseline PNG'lar — flat folder
└── integration_test/          # end-to-end happy-path test
```

> **Test layout:** `test/` papkasi `lib/` ning aniq mirror'i. Masalan `lib/customer/features/cart/bloc/cart_bloc.dart` uchun test `test/customer/features/cart/bloc/cart_bloc_test.dart`. Yagona istisno — `test/goldens/` (baseline PNG'lar flat folder). **`test/` ildiziga yangi fayl qo'shmang.**

### 2.4.1 `lib/` ichki struktura

```
lib/
├── main.dart
├── firebase_options.dart      # flutterfire orqali generated
├── config/
│   ├── app_config.dart        # --dart-define gateway
│   └── app_mode.dart          # AppMode enum + AppModeCubit
├── core/                      # CROSS-MODE infra (root DI scope)
│   ├── auth/
│   ├── connectivity/
│   ├── deep_links/
│   ├── di/                    # service_locator.dart + modullar
│   ├── error/                 # sealed Failure
│   ├── i18n/                  # qo'lda yozilgan tarjima
│   ├── logging/               # talker + nav observers
│   ├── maps/                  # YandexMapKitInitializer
│   ├── network/               # Dio, supabase_client, error_handler
│   ├── notifications/         # PushService, NotificationHandler
│   ├── storage/               # HiveBoxes, SecureStorage, CacheStore
│   ├── theme/                 # AppTheme, SellerTheme, ThemeCubit
│   └── widgets/               # AppSplashScreen, NetworkOverlay
├── shared/                    # CROSS-MODE domain
│   ├── bloc/                  # NotificationsCubit (root-scoped)
│   ├── models/                # ~17 ta entity
│   ├── repositories/          # 15+ ta interfeys
│   ├── mock/                  # canned data + mock repo'lar
│   ├── utils/                 # image_upload helpers
│   └── widgets/               # cross-mode UI atom'lar
├── auth/                      # shared login / register / verify / reset
├── customer/
│   ├── customer_app.dart      # MaterialApp.router + GoRouter
│   ├── router.dart            # GoRouter config
│   ├── features/              # home, cart, checkout, ...
│   ├── services/              # OrderTrackingService
│   └── widgets/               # CustomerHomeShell + GlassBottomNav
└── seller/
    ├── seller_app.dart        # MaterialApp + GoRouter
    ├── router.dart            # buildSellerRouter() — StatefulShellRoute
    ├── features/              # dashboard, products, tariff, ...
    ├── services/              # NewOrdersListener
    └── widgets/               # SellerHomeShell + SellerBottomNav
```

### 2.4.2 Folder konvensiyalar

- Har bir feature: `bloc/` yoki `cubit/`, `screens/`, ixtiyoriy `widgets/`, ixtiyoriy `data/`
- Modellar, repository interfeys'lari, mocklar, va keng qayta ishlatiladigan widget'lar `lib/shared/`'da — ikkala mode ham `customer → seller` circular dependency yaratmasdan import qila oladi
- `lib/core/` HECH QACHON `lib/customer/`, `lib/seller/`, `lib/auth/`, yoki `lib/shared/`'dan import qilmaydi

## 2.5 Dual-Mode Runtime — Phoenix + Scoped DI

Bu loyihaning **eng o'ziga xos arxitektura xususiyati** — process restart'siz runtime'da mode almashtirish.

### 2.5.1 Bootstrap ketma-ketligi (`lib/main.dart`)

```
WidgetsFlutterBinding.ensureInitialized()
    │
    ▼
SystemChrome.setSystemUIOverlayStyle(...)   ← splash'da quyuq icon
    │
    ▼
Firebase.initializeApp(...)
FirebaseMessaging.onBackgroundMessage(...)
    │
    ▼
initRootScope()                              ← Hive, Supabase, Dio, repo'lar, root cubit'lar
    │
    ▼
initModeScope(getInitialMode())              ← per-mode BLoC'lar, listener'lar
    │
    ▼
PushService.bootstrap()                      ← FCM foreground listener
_wireAuthToPushTokens()                      ← AuthCubit → FCM token sinxron
_wirePushToInboxRefresh()                    ← FCM payload → NotificationsCubit.load()
    │
    ▼
AppLocaleController.fromBox(settingsBox)
AppTranslations.setInstance(forLocale(...))
    │
    ▼
runApp(MultiBlocProvider(
  ThemeCubit / AuthCubit / AppModeCubit,
  child: _AppRoot,                            ← Phoenix-wrapped
))
```

### 2.5.2 Mode switch flow'i

```
button taps cubit.switchMode(seller)
                │
                ▼
AppModeCubit emits AppMode.seller (Hive 'app_mode'ga persist)
                │
                ▼
BlocListener inside Phoenix:
  if (sl.currentScopeName == mode.name) return;   ← idempotency guard
  await sl.popScope();                            ← customer mode singleton'larini dispose
  await initModeScope(mode);                      ← seller mode singleton'larini register
  Phoenix.rebirth(context);                       ← widget tree'ni qaytadan qurish
                │
                ▼
_ModeRouter rebuilds with fresh key:
  switch (getInitialMode()) {
    AppMode.customer => CustomerApp(),
    AppMode.seller   => SellerApp(),
  }
```

### 2.5.3 Nima uchun Phoenix, `Navigator.pushReplacement` emas?

- Ikki mode — **mustaqil `MaterialApp`'lar** (turli tema, turli router, turli BLoC tree)
- Phoenix `main()`'ni qayta chaqirmasdan, toza unmount/remount sikli beradi — shu sababli Firebase, Supabase va Hive mode flip'dan keyin ham ishlamoqda qoladi
- DI scope swap **`Phoenix.rebirth`'dan oldin** sodir bo'ladi; yangi tree mount bo'lganda `sl<SomeCubit>()` allaqachon yangi mode instance'ni qaytaradi

### 2.5.4 Cold-start splash dwell

`_ModeRouter` 1400 ms minimum splash davomiyligini va 360 ms crossfade'ni majburlaydi:

1. Tez qurilmada brand splash o'qiy oladigan vaqt qoladi
2. Mode switch'da bir xil splash DI swap visual jitter'ini niqoblaydi

### 2.5.5 Magic raqamlar (texnik qarz)

`_minSplashDuration = 1400ms`, `_crossfadeDuration = 360ms` hozir `_ModeRouter` ichida. **TODO:** `lib/core/theme/durations.dart`'ga ko'chirish.

## 2.6 Dependency Injection — `get_it` Named Scopes

DI markazlashgan `lib/core/di/service_locator.dart` (~556 qator) faylda. Container **ikki nomli scope'ga** ega.

### 2.6.1 Root scope — `initRootScope()`

Mode switch'larda ham yashaydigan singleton'lar:

- Barcha Hive boxlar (named: `settings`, `cache`, `pendingRoute`, `onboardingDraft`, `favorites`, `cart`, `newsReads`)
- `SupabaseClient` (faqat `AppConfig.hasSupabase` bo'lsa)
- `Dio` (lazy singleton, `dio.close(force: true)` orqali dispose)
- `ThemeCubit`, `AppModeCubit`, `AuthCubit`, `ConnectivityService`, `NetworkCubit`
- `PushService`, `NotificationHandler`, `DeepLinkService`, `CacheStore`, `SecureStorage`
- Barcha shared repository'lar va data source'lar

### 2.6.2 Mode scope — `initModeScope(mode)`

Faqat berilgan mode faol bo'lganda mavjud singleton'lar:

| Mode | Registratsiyalar |
| --- | --- |
| `customer` | `HomeBloc` (auto-yuklanadi), `CartBloc`, `FavoritesBloc`, `CategoriesBloc`, `ProfileCubit`, `ProfileOrdersCubit`, `OrderTrackingService` |
| `seller` | `SellerDashboardCubit` (**factory**, singleton emas), `NewOrdersListener` |

### 2.6.3 Registratsiya pattern'lari

```dart
// Eager singleton + auto-dispose
sl.registerSingleton<ThemeCubit>(
  ThemeCubit(boxes.settings),
  dispose: (c) => c.close(),
);

// Lazy singleton (birinchi lookup'da quriladi)
sl.registerLazySingleton<Dio>(
  buildDioClient,
  dispose: (dio) => dio.close(force: true),
);

// Factory (har resolve'da yangi — qisqa muddatli cubit'lar uchun)
sl.registerFactory<SellerDashboardCubit>(
  () => SellerDashboardCubit(sl<SellerDashboardRepository>()),
);

// Named instance (7 ta Hive box uchun)
sl.registerSingleton<Box>(boxes.settings, instanceName: HiveBoxes.settings);
final box = sl<Box>(instanceName: HiveBoxes.settings);
```

### 2.6.4 Mock vs jonli tanlov

`AppConfig.useMocks` — `bool.fromEnvironment('USE_MOCKS', defaultValue: true)`. DI wiring shunga qarab branch qiladi:

- `useMocks == true` → `MockXRepository` (katalog tipidagi endpoint'lar uchun)
- `useMocks == false` → `RemoteXRepository(dio)` yoki `SupabaseXRepository(supabase)`
- `useMocks == true` bo'lsa ham, ba'zi repository'lar Supabase mavjud bo'lsa **Supabase'ni afzal ko'radi** (banner, cart, favorites, orders)

Tafsilot matritsasi: `service_locator.dart` qatorlar **267–460**.

### 2.6.5 Cross-scope kirish guard

```dart
if (sl.isRegistered<NotificationsCubit>()) {
  sl<NotificationsCubit>().load();
}
```

Bu callback boshqa scope'da fire bo'lishi mumkin bo'lgan har qachon ishlatilsin (masalan: customer-scoped cubit'ga ulangan push tap seller mode faol bo'lganda).

## 2.7 Backend — Nima Uchun Supabase VA Firebase?

Bu dual-backend qaroridan ataylab. Har provayder **eng yaxshi bilan tanilgan ishida ishlatiladi**:

### 2.7.1 Supabase — data plane

| Mahsulot | Foydalanish | Fayl |
| --- | --- | --- |
| Postgres | Barcha domain ma'lumotlari: `products`, `categories`, `orders`, `carts`, `favorites`, `notifications`, `device_tokens` | `shared/repositories/supabase_*.dart` |
| Auth (email/password) | User identity uchun yagona manba. Ikkala modeda bir xil session | `core/auth/auth_repository.dart` |
| Realtime (Postgres CDC) | Order status (customer), yangi buyurtmalar (seller), bildirishnoma inbox | `customer/services/order_tracking_service.dart`, `seller/services/new_orders_listener.dart` |
| Storage | Mahsulot rasmlari, passport KYC | `shared/utils/image_upload.dart`, `seller/features/verification/` |
| Edge Functions | Jadval orqali model qilib bo'lmagan endpoint'lar uchun | `core/network/api_client.dart` |
| RLS | Har bir foydalanuvchi uchun row visibility. **Anon key ochiq bo'lgani uchun bu yagona himoya** | Hamma Supabase repo'lar shunga tayanadi |

### 2.7.2 Firebase — faqat push

| Mahsulot | Foydalanish |
| --- | --- |
| FCM | Topic broadcastlar (`news`) + per-device personal ping'lar. Token Supabase `device_tokens` jadvalida saqlanadi |
| `flutter_local_notifications` | FCM payload'ni foreground display qilish |

> Firestore, Firebase Auth, Firebase Storage **ishlatilmaydi**.

### 2.7.3 Push flow (cross-mode aware)

```
FCM tap (cold start / background / foreground)
        │
        ▼
PushService._onMessageTapped(message)
        │
        ├── extract { route, mode, kind } from data payload
        │
        ▼
NotificationHandler.savePendingRoute(route, mode, ts)
        │
        ▼
if (mode != currentMode) → AppModeCubit.switchMode(mode)
        │                  → scope swap + Phoenix.rebirth
        ▼
new shell.initState() → consumePendingRoute()
        │                → 5 daqiqadan kechikkan bo'lsa, drop
        ▼
GoRouter.go(route)
```

## 2.8 State Management — `flutter_bloc`

Kodbaza `Cubit` va `Bloc`'larni `flutter_bloc ^9`'dan ishlatadi. Qoida:

- **`Cubit`** — state'lar oddiy to'g'ridan-to'g'ri chaqirilganda (`load()`, `markRead()`, `toggleTheme()`)
- **`Bloc`** — state'lar event-driven bo'lganda, ayniqsa event transformer (`droppable`, `restartable`) kerak bo'lsa

### 2.8.1 Inventory

| Qatlam | Cubit'lar | Bloc'lar |
| --- | --- | --- |
| Root (cross-mode) | `ThemeCubit`, `AuthCubit`, `AppModeCubit`, `NetworkCubit`, `NotificationsCubit` | — |
| Customer mode | `ProfileCubit`, `ProfileOrdersCubit`, `ProductListCubit`, `CheckoutCubit` | `HomeBloc`, `CatalogBloc`, `CategoriesBloc`, `ProductDetailBloc`, `CartBloc`, `FavoritesBloc`, `CheckoutBloc`, `AddressesBloc`, `OrdersBloc`, `OrderDetailBloc` |
| Seller mode | `AddProductCubit`, `SellerDashboardCubit` (factory) | `DashboardBloc`, `SellerProductsBloc`, `ProductFormBloc`, `SellerOrdersBloc`, `SellerOrderDetailBloc`, `ShopSettingsBloc`, `ServicesBloc`, `TariffUpgradeBloc`, `VerificationBloc` |

### 2.8.2 Sealed state class'lar

```dart
sealed class AppAuthState extends Equatable { const AppAuthState(); }
class AppAuthUnauthenticated extends AppAuthState { ... }
class AppAuthAuthenticated extends AppAuthState {
  final String userId;
}
```

### 2.8.3 Scoping qoidalari

| Scope | Wired via | Yashaydi |
| --- | --- | --- |
| Root `BlocProvider.value` (in `main.dart`) | `ThemeCubit`, `AuthCubit`, `AppModeCubit` | Butun ilova hayoti |
| Mode singleton'lar (in `service_locator`) | `HomeBloc`, `CartBloc`, `FavoritesBloc`, `CategoriesBloc`, `SellerDashboardCubit` | Keyingi mode swap'gacha |
| Screen-local `BlocProvider(create: ...)` | `ProductListCubit`, `ProductDetailBloc`, `CheckoutBloc`, `AddProductCubit` | Route pop'gacha |

### 2.8.4 Realtime → BLoC bridge

Uzun yashovchi Supabase Realtime subscription'lar **service'larda** (cubit'da emas) yashaydi — bu screen change'lar bo'ylab davom etadi:

- `OrderTrackingService` (customer mode) — `orders` row'lariga `user_id == auth.uid()` filter bilan subscribe
- `NewOrdersListener` (seller mode) — `orders` row'lariga `shop_id == myShop.id` filter bilan
- `NotificationsCubit` (root scope) — `public.notifications` foydalanuvchi filter bilan

Service'lar cubit'larga state push qiladi; cubit'lar immutable snapshot'larni widget'ga ko'rsatadi.

## 2.9 Routing

### 2.9.1 Customer mode — `go_router` (declarative)

`lib/customer/router.dart`:

- `navigatorKey: customerNavigatorKey` (push handler outside-context navigatsiya uchun)
- Ikki observer: `TalkerRouteObserver(talker)` + `ConsoleNavObserver()`
- Top-level `redirect` `/tutorial`'ni guard qiladi

```dart
redirect: (context, state) {
  final atTutorial = state.matchedLocation == '/tutorial';
  if (!isTutorialSeen() && !atTutorial) return '/tutorial';
  if (isTutorialSeen() && atTutorial) return '/';
  return null;
},
```

**Route'lar:**

```
/                       → CustomerHomeShell (bottom nav)
/tutorial               → CustomerTutorialScreen
/categories             → CategoriesScreen
/catalog?category=...   → CatalogScreen
/product-list           → ProductListScreen
/product-detail/:id     → SupabaseProductDetailScreen
/search                 → SearchScreen
/products/:slug         → SupabaseProductDetailScreen (slug-based)
/cart                   → CartScreen
/favorites              → FavoritesScreen
/checkout               → CheckoutScreen
/orders                 → OrdersHistoryScreen
/orders/:id             → OrderDetailScreen
/profile/addresses      → AddressesScreen
/seller/onboarding      → SellerOnboardingScreen
```

### 2.9.2 Seller mode — `go_router` (default ON), legacy fallback

Joriy holatda **seller mode ham `go_router`** ishlatadi (`buildSellerRouter()` / `StatefulShellRoute`). `AppConfig.sellerUsesGoRouter` flag'i default ON.

Legacy `sellerNavigatorKey` shell hali ham kompilatsiya qilinmoqda — debug uchun escape hatch. **TODO (2.3-task):** `go_router` soak bo'lgandan keyin legacy branch va flag'ni o'chirish.

### 2.9.3 Auth guard'lar

**Aniq route-level auth guard yo'q.** O'rniga:

- Customer profile screen'lar `AuthCubit.state is AppAuthUnauthenticated` bo'lsa guest CTA ko'rsatadi
- `AppModeCubit` boot'da `seller_approved == false` bo'lsa, foydalanuvchini customer mode'ga qaytaradi

## 2.10 Repository Layer — Multi-Backend Strategy

Har bir cross-mode repository bir xil pattern: **abstract interfeys → ko'p implementatsiya → DI `AppConfig.useMocks` + Supabase mavjudligi bo'yicha tanlaydi**.

### 2.10.1 Misol: `ProductRepository`

```
ProductRepository (abstract)
├── MockProductRepository       — canned data, client-side filtering
├── RemoteProductRepository     — Dio orqali; FastAPI / Edge Functions
└── SupabaseProductRepository   — supabase_flutter orqali to'g'ridan-to'g'ri Postgres
```

### 2.10.2 Hybrid pattern — cart va favorites

`HybridCartRepository` va `HybridFavoritesRepository` mavjud, chunki ular:

- **Sign in'dan oldin ishlashi shart** (anonim cart)
- **Tarmoq uzilishidan omon qolishi shart** (Hive cache)

```
HybridCartRepository
├── HiveCartRepository      — local cache (offline source of truth)
├── SupabaseCartRepository  — auth bo'lgan zahoti remote source of truth
└── on auth state change:   — sign-in'da local item'larni remote'ga push,
                              sign-out'da local-only fallback
```

Bu yagona joy bo'lib, Hive **backend'ning peeri** sifatida qaraladi, passive cache emas.

### 2.10.3 Repository inventar

| Domain | Interface | Impl'lar |
| --- | --- | --- |
| Products (read) | `ProductRepository` | Mock / Remote / Supabase |
| Products (data source) | `SupabaseProductDataSource` | Faqat Supabase |
| Categories | `CategoryRepository` | Mock / Supabase |
| Shops | `ShopRepository` | Mock / Supabase |
| Banners | `BannerRepository` | Mock / Supabase |
| Cart | `CartRepository` | Mock / Remote / Hive / Supabase / Hybrid |
| Favorites | `FavoritesRepository` | Mock / Remote / Hive / Supabase / Hybrid |
| Orders | `OrderRepository` | Mock / Remote / Supabase |
| Addresses | `AddressRepository` | Mock |
| Regions | `RegionRepository` | Mock |
| Notifications | `NotificationDataSource` | Mock / Supabase |
| Seller — products (read) | `SellerProductRepository` | Mock / Supabase |
| Seller — products (write) | `AddProductRepository` | Supabase |
| Seller — dashboard | `SellerDashboardRepository` | Supabase (always) |
| Seller — orders | `SellerOrderRepository` | Mock + Supabase (gated) |
| Seller — shop settings | `ShopSettingsRepository` | Mock + Supabase (gated) |
| Seller — services | `SellerServicesRepository` | Mock + Supabase (gated) |
| Seller — verification | `SellerVerificationRepository` | Mock + Supabase (gated) |
| Seller — tariff | `TariffRepository` | Mock + jonli plan catalog |

> Seller tomon hozir **mock-heavy**. `SELLER_FULFILLMENT_ENABLED` flag ostida; `SupabaseSeller*Repository`'lar mavjud, lekin E2E verify bo'lmaguncha gating qoldi. **Bu — qolgan eng katta ish (`ROADMAP.md` 2.1-task).**

## 2.11 Authentication

- Email + parol (Supabase Auth)
- Email + OTP sign-in
- Ro'yxatdan o'tish, email verification, parol tiklash
- Auth bottom-sheet flow (email step → OTP step → profile step) extracted widget sub-tree bilan
- Supabase `AuthException` kodlari lokalizatsiya qilingan xabarlarga maplangan (`invalid_credentials`, `email_not_confirmed`, `over_email_send_rate_limit`)
- Forgot-password OWASP qoidasi bo'yicha — email mavjudligini ko'rsatmaydi (success state bir xil)
- "Ghost-session recovery" — yetishmagan `profiles` row toza sign-out'ga majburlaydi

## 2.12 Notifications, Connectivity va Platform

- FCM push — topic broadcastlar (`news`) + per-token personal ping'lar; foreground display `flutter_local_notifications` orqali
- Device-token sinxronizatsiya auth state'ga ulangan — sign-out'dan oldin token o'chiriladi (RLS-safe tartib)
- Connectivity service — link-change detection + real reachability tekshiruv, offline overlay bilan
- Platform facade'lar — `FirebaseMessaging`, `Geolocator`, `ImagePicker`, connectivity — testability uchun

> **Notification kanal id `news`** — `AndroidManifest.xml` `com.google.firebase.messaging.default_notification_channel_id` meta va `flutter_local_notifications` orqali yaratilgan kanal **bir xil bo'lishi shart**.

## 2.13 Localization — Qo'lda Yozilgan Sistema

`easy_localization` o'chirilib, `lib/core/i18n/` ostida qo'lda yozilgan sistema bilan almashtirildi.

**Sabab:** Tarjimalarni pure Dart konstantalar sifatida saqlash — Shorebird code-push'da copy edit'larni binary qayta qurmasdan OTA jo'natish imkonini beradi (oldindan o'ylangan kelajak).

### 2.13.1 Struktur

```
core/i18n/
├── i18n.dart                  — ommaviy yuza: tr(), context.tr, AppLocalizationsContext extension
├── app_translations.dart      — singleton; forLocale(...); .tr(key, args, namedArgs)
├── app_translations_delegate.dart — LocalizationsDelegate<AppTranslations>
├── app_locale_controller.dart — ValueNotifier<Locale>, Hive 'settings' box backed
└── translations/
    ├── all_translations.dart  — aggregator (uzTranslations, ruTranslations, enTranslations)
    ├── address_translations.dart
    ├── auth_translations.dart
    ├── cart_translations.dart
    ├── catalog_translations.dart
    ├── checkout_translations.dart
    ├── common_translations.dart
    ├── home_translations.dart
    ├── mode_translations.dart
    ├── notifications_translations.dart
    ├── onboarding_translations.dart
    ├── orders_translations.dart
    ├── product_translations.dart
    ├── seller_orders_translations.dart
    ├── seller_translations.dart
    ├── shop_settings_translations.dart
    ├── shop_translations.dart
    ├── system_translations.dart
    ├── tariff_translations.dart
    └── tutorial_translations.dart
```

### 2.13.2 Qamrov

- 322 kalit
- uz / ru / en — har birida to'liq
- Debug-only completeness guard (`_missing_keys_check.dart`) ru yoki en uz baseline'dan tushganda boot'ni to'xtatadi

### 2.13.3 Yangi tarjima qo'shish

1. Tegishli `<domain>_translations.dart` faylga **uchta tilga** kalit qo'shing
2. `tr('your.key')` yoki `context.tr('your.key')` ishlatish
3. Debug rejimida ishga tushiring — agar drift bo'lsa, boot ataylab to'xtaydi

## 2.14 Theming

- `core/theme/app_theme.dart` — customer tema (cream brand palette `#FBF1E8`)
- `core/theme/seller_theme.dart` — seller tema (business-neutral)
- `ThemeCubit` (root) — brightness preferensiyasini `settings` Hive box'da saqlaydi
- Native splash + launcher icon bir xil cream palette'da — cold-start visual'lar bir xil

## 2.15 Native Bridges

### 2.15.1 Yandex MapKit

`lib/core/maps/yandex_mapkit_initializer.dart` plugin lifecycle quirk'larini hal qiladi:

- **Android** — plugin'ning `onAttachedToActivity` `MapKitFactory.getInstance().onStart()`'ni eager chaqiradi va location permission'dan oldin logcat'ni `SecurityException`'lar bilan to'ldiradi. `MainActivity.kt` boot'da `onStop()` qiladi; bu Dart helper `onStart()`'ni `MethodChannel('com.mebellar.app/yandex_mapkit')` orqali permission prompt'idan **keyin** chaqiradi
- **iOS** — plugin `register(with:)` `YMKMapKit.mapKit`'ni darhol resolve qiladi va API kalitini `AppDelegate.swift`'da `GeneratedPluginRegistrant`'dan **oldin** o'rnatish shart

Bu kodbaza ichida **yagona `MethodChannel`** ishlatadigan joy.

## 2.16 Logging

- `talker_flutter` — yagona logging yuza
- `lib/` da **`print()` chaqiruvi yo'q**
- `talker.info()`, `talker.handle(e, st, msg)` keng ishlatiladi
- Debug-only overlay: `core/logging/debug_talker_overlay.dart`
- `TalkerRouteObserver` nav event'larini bir xil talker stream'ga yo'naltiradi

## 2.17 Storage Map

| Box / fayl | Foydalanish |
| --- | --- |
| Hive `settings` | `theme`, `locale`, `app_mode`, `tutorial_seen` |
| Hive `cache` | response cache (`CacheStore`) |
| Hive `pendingRoute` | mode flip kutayotgan cross-mode push route'lari |
| Hive `onboardingDraft` | seller onboarding wizard progress |
| Hive `favorites` | offline favorites snapshot (HybridFavoritesRepository) |
| Hive `cart` | offline cart snapshot (HybridCartRepository) |
| Hive `newsReads` | broadcast inbox o'qish holati |
| `flutter_secure_storage` | refresh token (SecureStorage wrapper) |

> **Texnik qarz (TD-4):** `'app_mode'`, `'tutorial_seen'` kabi xom string kalitlar `HiveBoxes` typing'ini chetlab o'tadi. Tipli `SettingsBox` wrapper bilan o'rab chiqish kerak.

## 2.18 Atrof-muhit (Environment) Konfiguratsiyasi

Barcha runtime config build vaqtida `--dart-define-from-file` orqali inject qilinadi. **Hech bir secret'da compiled-in default qiymat yo'q** — `AppConfig.assertConfigured()` `main()` boshida ishlaydi va biror talab qilingan kalit yetishmasa **build'ni baland to'xtatadi**.

### 2.18.1 Bitta env fayli — `env/prod.json`

Avvalgi `env/dev.json` olib tashlangan. Bitta `prod.json` har bir local run, har bir build, va har bir test fixture'ni boshqaradi.

| Fayl | Roli |
| --- | --- |
| `env/example.json` | Commit qilingan template — to'liq kalit shakli bo'sh secret qiymatlari bilan |
| `env/prod.json` | Yagona ishlovchi env fayli. Bu **shaxsiy** repo'ga commit qilingan (maintainer'ning machine'lari o'rtasida sync uchun) |

### 2.18.2 Kalitlar

| Kalit | Majburiy | Izoh |
| --- | --- | --- |
| `SUPABASE_URL` | ✅ | Project URL |
| `SUPABASE_ANON_KEY` | ✅ | Public anon JWT — client'da xavfsiz, RLS bilan himoyalangan |
| `YANDEX_GEOCODER_API_KEY` | ✅ | Yandex Cloud console'da package/referrer bo'yicha cheklash kerak |
| `SENTRY_DSN` | — | Bo'sh ⇒ Sentry disabled rejimda boshlanadi |
| `APP_ENV` | — | `dev` (default) yoki `prod` |
| `USE_MOCKS` | — | `true` ⇒ canned catalog data; `false` ⇒ jonli backend |
| `SELLER_FULFILLMENT_ENABLED` | — | `false` (default) ⇒ mock-only seller surface'lar "coming soon" placeholder ko'rsatadi |
| `SELLER_USES_GO_ROUTER` | — | `true` (default) ⇒ seller mode `go_router`'da ishlaydi |

### 2.18.3 Secrets gigiyena

⚠️ `env/prod.json` ataylab commit qilingan (shaxsiy repo, RLS-guarded anon key — past risk). **AMMO** Firebase **Admin SDK** service-account kalit hech qachon commit qilinmasligi kerak. Hozir `woody-b3c1a-firebase-adminsdk-*.json` fayli **tasodifan repo'ga kiritilgan** — bu **kritik xavfsizlik nuqsoni** (pastdagi 2.21 §1.1'ga qarang).

## 2.19 Testing

### 2.19.1 Qamrov xaritasi

| Qatlam | Qamrov |
| --- | --- |
| BLoC / Cubit | Keng — har bir bloc/cubit'ning test fayli bor |
| Repository kontrakt | `b1_repository_contract_test.dart` — mock + jonli interfeys'lar bo'yicha parameterized |
| Widget'lar | cart, checkout, login, register, mahsulot galereya |
| Golden | auth, cart, mahsulot galereya (baseline'lar `test/goldens/`) |
| Integration | `integration_test/app_test.dart` — launch → browse → cart → checkout happy path |

### 2.19.2 Test layout konvensiyasi (MAJBURIY)

`test/` papkasi `lib/` ning **aniq mirror'i**. Misol:

```
lib/customer/features/cart/bloc/cart_bloc.dart
→ test/customer/features/cart/bloc/cart_bloc_test.dart
```

`test/goldens/` istisno: baseline PNG'lar bitta flat papkada. **`test/` ildiziga yangi fayl qo'shmang.**

### 2.19.3 Buyruqlar

```bash
flutter test                     # 192/192 yashil
flutter test --coverage          # lcov report bilan
flutter test integration_test    # qurilma kerak
```

## 2.20 Release Build'lari

```bash
# Android App Bundle
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json

# iOS IPA
flutter build ipa --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json
```

## 2.21 QOLGAN ISHLAR — Texnik Qarz va Vazifalar

> Manba: `ROADMAP.md` 2-qism + `BUGS_AND_ISSUES.md` 2026-05-12 sweep + maintainer audit.
> Prioritet tartibida.

### 2.21.1 🔴 KRITIK — Firebase Admin SDK kalit (2.7-task)

**Vaziyat:** `woody-b3c1a-firebase-adminsdk-fbsvc-bbab5cd45d.json` repo'ga commit qilingan (2026-05-12'dan beri). Bu private key Firebase project'ga to'liq nazorat beradi. `.gitignore` qoidasi (`*-firebase-adminsdk-*.json`) **commented out**.

**Bajarish:**

1. Repo gigiyena:
   ```bash
   git rm --cached woody-b3c1a-firebase-adminsdk-*.json
   ```
   `.gitignore`'da `*-firebase-adminsdk-*.json` qoidasini qayta yoqing.

2. **Kalitni rotatsiya qiling** (faqat loyiha egasi qila oladi):
   - Firebase Console → Project Settings → Service Accounts
   - Yangi kalit generate qiling
   - Eski kalitni revoke qiling
   - Eski kalitni kompromaytirib bo'lgan deb hisoblang (git history'da qoladi)

3. `a.md`, `flutter_01.png` kabi stray fayl'larni `docs/`'ga ko'chiring yoki untrack qiling.

### 2.21.2 🟠 YUQORI — Seller fulfillment backend faollashtirish (2.1-task)

**Vaziyat:** `SupabaseSeller*Repository` impl'lari mavjud, lekin `SELLER_FULFILLMENT_ENABLED=false` bilan gating. Mock data ko'rinmoqda.

**Bajarish ketma-ketligi:**

1. **RLS politikalarni qo'llash.** `docs/supabase_rls_policies.sql.md`'dagi SQL'ni Supabase SQL editor'da ishga tushiring. Bu quyidagilarni qamraydi:
   - `shop_services` (yangi jadval) — owner write, public read
   - `shops` — owner update/insert, public read
   - `orders` — customer read/insert, seller read/update (order_items orqali)
   - `order_items` — participant read
   - `verification_documents` + `seller_verifications` — owner-only
   - `subscription_receipts` + `subscriptions` — owner read/insert
   - Storage bucket'lari: `verification-docs`, `payment-receipts` — PRIVATE

2. **`is_shop_owner` SECURITY DEFINER helper'ni yaratish** (RLS policy'lar shunga tayanadi).

3. **`get_advisors(type: security)`'ni ishga tushiring** — hech qanday "RLS disabled" yoki "policy allows public write" topilmasligi kerak.

4. **End-to-end verify** har bir seller repo'ni jonli Supabase'ga qarshi:
   - Mahsulot yarating → buyurtma keldi → qabul qildi → jo'natildi → yetkazildi
   - Manual smoke: Seller A Seller B'ning buyurtmasini, xizmatlarini, verifikatsiya hujjatini, kvitansiyasini o'qiy olmasligini tasdiqlang
   - `orders` jadvalini `supabase_realtime` publikatsiyasiga qo'shing:
     ```sql
     alter publication supabase_realtime add table public.orders;
     ```

5. **`SELLER_FULFILLMENT_ENABLED=true`'ga flip qiling.**

6. **"Coming soon" placeholder branch'larini olib tashlang** endi jonli bo'lgan surface'lar uchun.

**Tugallandi:** Sotuvchi real ma'lumotda to'liq buyurtma lifecycle'ini mock fallback'siz tugatsa.

### 2.21.3 🟡 O'RTA — Lifecycle va cancellation hardening (2.5-task)

**Bajarish:**

- `HybridCartRepository` / `HybridFavoritesRepository`'da `dispose()` qo'shing — `onAuthStateChange` subscription'lari bekor qilinishi shart (Phoenix rebirth bo'ylab listener stacking'ni oldini olish)
- `Dio` `CancelToken`'larini repository metodlari orqali o'tkazing; `Bloc.close()`'da bekor qiling — mode switch o'rtasida stale natija olmaslik uchun
- Tutorial-seen flag'ni `ValueNotifier<bool>`'da cache qiling — `go_router` redirect har navigatsiyada Hive read qilmaslik uchun

**Tugallandi:** Hech qanday leaked subscription/channel yo'q va mode flip'dan keyin stale UI yo'q.

### 2.21.4 🟡 O'RTA — Checkout state holder'lar konsolidatsiyasi (2.2-task)

**Vaziyat:** `CheckoutCubit` (step state) va `CheckoutBloc` (payment events) bir vaqtda mavjud. Ikkisining ham qonuniy sabablari bor, lekin ownership chegarasi noaniq.

**Bajarish opsiyalar:**

- **A) Birlashtirish:** Hammasini bir `CheckoutBloc`'ga event-driven step transition'lar bilan o'tkazing
- **B) Hujjatlash:** Har fayl boshida ownership chegarasini aniq tushuntiring

### 2.21.5 🟡 O'RTA — Legacy seller navigation'ni o'chirish (2.3-task)

**Vaziyat:** `go_router` seller mode default ON; legacy imperative `sellerNavigatorKey` shell hali ham kompilatsiya qilinadi (`AppConfig.sellerUsesGoRouter=false` bilan fallback).

**Bajarish:**

- `go_router` seller mode soak bo'lganini tasdiqlang (kamida 1 oy production'ga teng test)
- Legacy `sellerNavigatorKey` shell va `AppConfig.sellerUsesGoRouter` flag'ni o'chiring
- O'lik `onGenerateRoute` ishlatishini olib tashlang

**Tugallandi:** Seller mode uchun aniq bir routing implementation.

### 2.21.6 🟡 O'RTA — Type-safe Hive kirish (2.4-task)

**Bajarish:**

- Tipli `SettingsBox` wrapper qo'shing:
  ```dart
  class SettingsBox {
    SettingsBox(this._box);
    final Box _box;
    AppMode get appMode => /* parse from string */;
    set appMode(AppMode value) => _box.put('app_mode', value.name);
    bool get tutorialSeen => _box.get('tutorial_seen', defaultValue: false);
    set tutorialSeen(bool value) => _box.put('tutorial_seen', value);
    // ...
  }
  ```
- Xom string kalitlarni (`'app_mode'`, `'tutorial_seen'`, …) wrapper bilan almashtiring

**Tugallandi:** Feature kod'da xom string Hive kaliti qolmagan.

### 2.21.7 🔵 PAST — Kod-tashkiliy tozalov (2.6-task)

- `NotificationsCubit`'ni `customer/features/notifications/`'dan `lib/shared/bloc/`'ga ko'chiring — u root-scoped va ikkala mode tomonidan iste'mol qilinadi
- Har bir `Equatable` `props` override'ni audit qiling — UI iste'mol qiladigan har bir maydon present bo'lishi shart (masalan: `HomeState`'da refresh-timestamp'ga o'xshash maydonlar)
- Ixtiyoriy: 600–880 qatorli ekranlarni (`home`, `tariff`, `analytics`, `tutorial`, `reviews`) kichikroq widget'larga bo'ling — nice-to-have, blok qilmaydi

### 2.21.8 ⏸️ KECHIKTIRILGAN — Customer payment flow (2.8-task)

**Strategik kechiktirish.** V1 offline P2P / cash-on-delivery bilan ship qilinadi. V1 launch'dan keyin qayta ko'rib chiqing.

**Hujjatlangan ish:**

- To'lov partner tanlash (Payme / Click / Octo / P2P-to-card)
- SDK yoki webview flow integratsiyasi `customer/features/checkout/`'da
- `payment_intents` jadvali + tasdiqlash Edge Function; buyurtma `pending_payment` callback `paid`'ga flip qilmaguncha

### 2.21.9 Prioritet tartibi

| Tartib | Vazifa | Og'irlik |
| --- | --- | --- |
| 1 | 2.7 — Admin SDK kalit (+ egasi rotatsiya) | 🔴 |
| 2 | 2.1 — seller fulfillment backend faollashtirish | 🟠 |
| 3 | 2.5 — lifecycle & cancellation hardening | 🟡 |
| 4 | 2.2 — checkout state holder'lar konsolidatsiyasi | 🟡 |
| 5 | 2.4 — type-safe Hive kirish | 🟡 |
| 6 | 2.3 — legacy seller navigation o'chirish | 🟡 |
| 7 | 2.6 — kod-tashkiliy tozalov | 🔵 |
| — | 2.8 — customer payment flow | ⏸️ kechiktirilgan |

## 2.22 Ma'lum Tarixiy Muammolar va Hal Qilinganlar (Konteks)

Quyidagi muammolar **avvalgi audit'lar paytida topilgan va tuzatilgan** — yangi dasturchiga konteks beradi:

- ✅ Hardkod qilingan Supabase credentials `app_config.dart`'dan olib tashlandi (compiled-in default'lar yo'q, fail-fast)
- ✅ `dev.json` o'chirildi — bitta `prod.json` qoldi
- ✅ Ko'p `catch (_)` blok'lar `catch (e, st)` + `talker.handle(...)` bilan almashtirildi
- ✅ Dead Sentry test block `main.dart`'dan olib tashlandi
- ✅ `ProfileCubit.load()` va `ProfileOrdersCubit.load()` silent failure'lari tuzatildi
- ✅ `service_locator` modulyarizatsiya qilindi (`*_module.dart`'larga bo'lib chiqilgan)
- ✅ `Result<T, Failure>` repository pattern joriy etildi
- ✅ `bloc_concurrency` `SearchBloc`, `HomeBloc`, `OrdersBloc`'da
- ✅ `CachedNetworkImage`'da `memCacheWidth` har joyda
- ✅ Realtime channel disposal audit qilindi
- ✅ Sotuvchi "god-screen"'lar `widgets/` sub-tree'larga bo'lib chiqildi (hech bir fayl 1000 qatordan oshmaydi)
- ✅ uz/ru/en i18n to'liq, drift guard joriy etildi

> **Manba:** `BUGS_AND_ISSUES.md` (tarixiy reestr — joriy holat uchun nuqtai nazardan ahamiyatli emas, lekin yangi dasturchi uchun kontekst).

## 2.23 SOLID/DRY/Scalability Refactor Imkoniyatlari (Kelajak)

> Manba: `REFACTORING.md`. Bu V1'ni **blok qilmaydigan** ish — kelajakdagi sprint'lar uchun saqlangan.

### 2.23.1 Eng katta refaktor maqsadlari (qiymat bo'yicha)

Faqat hozir 600+ qatorli ekran'lar (oldingi 1000+ god-screen'lar allaqachon bo'lib chiqilgan):

- `home_screen.dart` — 880 qator (eng katta)
- `tariff`, `analytics`, `tutorial`, `reviews` — 600-800 qator oralig'ida

Bu nice-to-have refaktor — bo'lish step'i: BlocBuilder'ni chuqurroq surish va `const` constructor'larni ko'tarish.

### 2.23.2 SOLID kuzatuvlari

- **SRP:** `service_locator.dart` allaqachon modullarga bo'lib chiqilgan
- **OCP:** `RepositoryResolver` mock vs jonli tanlashni bitta auditable joyga jamlaydi
- **LSP:** `HybridCartRepository`'ning auth side-effect'i interfeys orqali ko'rinmaydi. **Refaktor:** auth-sync'ni alohida `CartSyncService` qiling, repository implementation interchangeable qoldiring
- **ISP:** `ProductRepository` keng — `ProductListSource`, `ProductDetailSource`, `ProductSearchSource`'ga bo'lish mumkin
- **DIP:** Ba'zi Supabase repo'lar `Supabase.instance.client`'ni to'g'ridan-to'g'ri oladi — har doim constructor orqali inject qilish kerak

### 2.23.3 DRY/Scalability levers

- **`AppDurations` / `AppSizing` / `AppAnimations`** — magic raqamlar markazlashtirish (splash dwell, crossfade, debounce vaqtlari)
- **Feature flag'lar Supabase'da** — `feature_flags` jadval, root-scoped `FeatureFlags` singleton, kill-switch va A/B test imkoniyati
- **Modulyarizatsiya** — 80–100k LOC'dan keyin multi-package monorepo'ga (melos)
- **OpenAPI / `openapi_generator`** — Edge Function'lar uchun schema discipline
- **Branded type'lar** — `extension type ProductId(String value) {}` orqali ID type confusion'ni oldini olish

### 2.23.4 Testability refaktor'lari

- `Clock` inject qilish (`DateTime.now()` o'rniga)
- `FcmFacade`, `GeolocatorFacade`, `ImagePickerFacade`, `ConnectivityFacade`'lar
- Repository uchun parameterized contract test'lar (mock va jonli o'rtasidagi drift'ni oldini olish)

## 2.24 Coding Standards

### 2.24.1 Tavsiya etilgan lint qoidalari (`analysis_options.yaml`)

```yaml
analyzer:
  errors:
    invalid_annotation_target: ignore
linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - avoid_redundant_argument_values
    - prefer_const_constructors
    - prefer_const_literals_to_create_immutables
    - prefer_final_locals
    - unawaited_futures
    - use_super_parameters
```

> `public_member_api_docs`'ni yoqmang — ilova kodbazasi uchun shovqin keltiradi.

### 2.24.2 Umumiy konvensiyalar

- **BLoC event'lar:** Pozitsion `bool`'lar o'rniga named parameter (default bilan):
  ```dart
  class HomeRequested extends HomeEvent {
    const HomeRequested({this.forceRefresh = false});
    final bool forceRefresh;
  }
  ```
- **`Equatable` props:** UI iste'mol qiladigan har bir maydon `props`'da bo'lishi shart
- **Repository return type:** Har doim `Future<Result<T, Failure>>` — exception throw qilish o'rniga
- **Logging:** `print()` taqiq. `talker.info()` / `talker.handle()` ishlatish
- **No silent catches:** `catch (_)` faqat aniq hujjatlangan best-effort yo'llarda ruxsat etiladi (har bir qoldiq `catch (_)` izoh bilan)
- **Hive kalitlari:** Xom string emas — `HiveBoxes` enum + tipli wrapper (kelajakda `SettingsBox`)

### 2.24.3 Naming

- Internal package nomi: **`woody_app`** (`pubspec.yaml`'da)
- Brend / bundle id: **`uz.mebellar.app`** / **`com.mebellar.app`**
- Bu **ataylab** asimmetriya — `CONTRIBUTING.md` bunda hujjatlanadi (yangi muhandis 5-15 daqiqa noaniqlikdan o'tadi)

## 2.25 Backend (Supabase) — Tezkor Spravochnik

### 2.25.1 Migratsiya'lar

- **23 ta ordered SQL migration** `supabase/migrations/` ostida
- Hammasi: profiles, shops, products, categories, cart, favorites, notifications, device_tokens, news
- **Har bir jadvalda RLS yoqilgan**
- `auth.uid()` chaqiruvlari optimallashtirilgan
- `SECURITY DEFINER` funksiyalar audit qilingan
- Yetishmagan FK index'lar to'ldirilgan
- Orders va notifications uchun Realtime yoqilgan (CDC)
- `delete_user_account` RPC faqat authenticated callerlar uchun

### 2.25.2 Edge Functions

- **`send-news-broadcast`** — FCM topic fan-out

### 2.25.3 Storage bucket'lar

| Bucket | Maqom | Foydalanish |
| --- | --- | --- |
| `product-images` | Public | Mahsulot rasmlari |
| `verification-docs` | **Private** | Passport / KYC hujjatlari |
| `payment-receipts` | **Private** | Tarif P2P to'lov skrinshotlari |

> Storage path konventsiyasi: `<bucket>/<user_uid>/<file_name>`. RLS policy `(storage.foldername(name))[1] = auth.uid()::text` orqali owner-only kirishni majburlaydi.

### 2.25.4 Asosiy biznes qoidalari (DB'da majbur qilingan)

1. **Bitta sotuvchi = bitta do'kon** (1:1, qat'iy). URL'da `{shop_id}` YO'Q; backend JWT'dan `user_id → seller_profile → shop`'ni resolve qiladi
2. **Multilingual JSONB** — `{"uz": "...", "ru": "...", "en": "..."}` formatdagi text maydonlar (mahsulot nomi, ta'rifi)
3. **Soft delete** — DB'dan o'chirish o'rniga `deleted_at` to'ldirilgan
4. **Verification status'lar:** `pending` / `in_review` / `approved` / `rejected`
5. **Tariff plan'lari** `subscription_plans` server-side curated, sotuvchi tomonidan o'zgartirilmaydi

## 2.26 Loyiha O'ziga Xosligi va Tarixiy Qarorlar

> Bu bo'lim **nima uchun shunday qilinganligini** tushuntiradi. Yangi dasturchi tasodifan bu qarorlardan biri buzmasligi uchun.

1. **`woody_app` ichki nomi va `mebellar` brendi** — re-branding paytida package rename'ni kechiktirib qoldirgan. `flutter create` regenerate qilishi xavfli — qattiq rioya qiling.

2. **Yagona `prod.json` env fayli** — `dev.json` ataylab olib tashlangan. "dev profile" mavjud emas, "private repo bilan maintainer machine'lari o'rtasida sync" prinsipi tanlangan.

3. **Supabase + Firebase dual backend** — auth va data uchun Supabase, push uchun Firebase. **Auth'ni Firebase'ga ko'chirish noto'g'ri** — RLS Supabase JWT'ga tayanadi.

4. **Qo'lda yozilgan i18n** — `easy_localization` o'chirilgan. Sabab: Shorebird code-push'da copy edit'larni OTA jo'natish imkonini saqlash.

5. **Phoenix mode switch, `Navigator.pushReplacement` emas** — ikki mode mustaqil `MaterialApp` (turli tema, router, BLoC tree); toza unmount/remount sikli kerak.

6. **Seller mode `go_router`'ga ko'chirish davom etmoqda** — legacy `sellerNavigatorKey` shell hali ham debug escape hatch sifatida saqlangan.

7. **`SELLER_FULFILLMENT_ENABLED=false` default** — mock-only seller surface'lar prod build'da "coming soon" ko'rsatadi. Bu ataylab — Supabase repo'lar mavjud, lekin E2E verify bo'lmagunch flip qilinmaydi.

8. **Customer cart va favorites Hybrid pattern'da** — auth bo'lguncha local, auth bo'lganda Supabase'ga merge. Boshqa repository'lar bunga rioya qilmaydi.

9. **Splash dwell 1400ms** — DI swap visual jitter'ni niqoblash uchun ataylab. O'zgartirilmasin.

10. **Anon Supabase key client'da** — bu xavfsizmi? Faqat **RLS o'qib bo'ladigan barcha jadvallar uchun yoqilgan bo'lsa**. RLS yagona himoya devori — yangi jadval qo'shganda RLS yoqishni unutmang.

## 2.27 Resurslar va Havolalar

### 2.27.1 Yangi dasturchi uchun o'qish tartibi

1. `README.md` — onboarding
2. `docs/PROJECT_STATE_ANALYSIS.md` — joriy holat va texnik qarz
3. `ARCHITECTURE.md` — chuqur sistema dizayni
4. `ROADMAP.md` — qolgan ishlar
5. `BUGS_AND_ISSUES.md` — tarixiy reestr (kontekst uchun)
6. `REFACTORING.md` — SOLID/DRY notes
7. `docs/supabase_rls_policies.sql.md` — Seller backend uchun RLS SQL
8. `docs/legacy/` — eski uz-deep dive'lar (arxivga olingan, hozirgi stack'dan oldin)

### 2.27.2 Asosiy fayllar va maqsad

| Fayl | Maqsad |
| --- | --- |
| `lib/main.dart` | Bootstrap, root scope init, mode router |
| `lib/customer/customer_app.dart` | Customer MaterialApp + GoRouter |
| `lib/seller/seller_app.dart` | Seller MaterialApp + GoRouter |
| `lib/core/notifications/notification_handler.dart` | Cross-mode deep linking |
| `lib/core/auth/auth_repository.dart` | Supabase Auth + `/me` |
| `lib/core/network/api_client.dart` | Dio + Bearer token interceptor |
| `lib/core/storage/hive_boxes.dart` | settings, cache, pending_route box'lar |
| `lib/shared/models/multilingual_text.dart` | uz/ru/en JSONB rendering |
| `lib/core/di/service_locator.dart` | DI orkestratsiya (root + mode) |
| `lib/core/result/result.dart` | `Result<T, Failure>` pattern |

### 2.27.3 Atamalar (Glossary)

| Atama | Ma'no |
| --- | --- |
| **AppMode** | Mobile app rejimi: `customer` yoki `seller` |
| **Pending route** | Cross-mode notification handling uchun Hive'da saqlanadigan deep link |
| **Root scope** | GetIt'da app boot vaqtida yaratilgan, mode switch'da saqlanadigan singleton'lar |
| **Mode scope** | Har AppMode uchun yaratilgan, switch'da dispose qilinadigan singleton'lar |
| **handle_new_user** | Postgres trigger: `auth.users`'ga insert bo'lganda `public.profiles` ham atomik insert qiladi |
| **JWT-based shop resolution** | URL'da `{shop_id}` o'rniga JWT'dan user_id → seller_profile → shop (1:1) |
| **P2P payment** | Peer-to-peer karta-karta pul o'tkazma (V1'da tarif to'lovi uchun) |
| **Verification status** | `pending` / `in_review` / `approved` / `rejected` |
| **Multilingual JSONB** | `{"uz": "...", "ru": "...", "en": "..."}` formatdagi text maydonlar |
| **Tariff** | Sotuvchi obuna paketi: Free / Basic / Pro / Enterprise |
| **Shop services** | Sotuvchi taklif qiladigan xizmatlar (yetkazib berish, montaj, garantiya) |
| **Signed URL** | Private bucket'dan vaqtinchalik (1 soat) ruxsat URL |
| **Soft delete** | `deleted_at` to'ldirish (DB'dan o'chirish o'rniga) |
| **Phoenix.rebirth** | `flutter_phoenix` widget tree'ni qayta yaratish — `main()`'ni qayta chaqirmaydi |
| **`Result<T, Failure>`** | Typed success/error returnlash patterni — exception throw qilish o'rniga |

## 2.28 Ochiq Savollar (Maintainer'ga)

> Quyidagilar **biznes / strategik qarorlar** — kod darajasida emas, mahsulot darajasida hal qilinishi shart.

1. **Komissiya foizlari:** Free 5%, Basic 3%, Pro 2% — pilot davomida tasdiqlash kerak
2. **Dispute resolution:** customer order'dan norozi bo'lsa kim qaror qabul qiladi?
3. **Sotuvchiga to'lov modeli (V2):** escrow yoki direct flow?
4. **Tariff downgrade UX:** Free'ga downgrade'da mahsulotlar archived bo'ladi — qaysi mahsulotlar arxivlangani aniq ko'rsatish — modal, banner yoki email?
5. **Web ilova kerakmi (V2)?** Flutter Web yoki Next.js?
6. **Verification hujjatlari saqlash muddati** — yuridik bilan kelishish
7. **P2P to'lov soliq holati** — yurist
8. **Privacy Policy / ToS** — yurist
9. **In-app onboarding tutorial slide'lari** — UX iteratsiya kerakmi?
10. **Ikkala mode'da boshlash** — yangi sotuvchi customer mode'ga qaytarish UX

## 2.29 Done Definition — V1 uchun

V1 quyidagilar bajarilganda **launch-ready** deyiladi:

- [x] `dart analyze` 0 issue
- [x] 192/192 test yashil
- [ ] **2.7-task** — Firebase Admin SDK kalit rotatsiya qilingan va untrack qilingan
- [ ] **2.1-task** — Seller fulfillment backend faollashtirilgan va E2E verify
- [ ] **2.5-task** — Lifecycle/cancellation hardening tugatilgan
- [ ] 5-10 ta sotuvchi va 20-30 ta xaridor bilan **pilot test** o'tkazilgan
- [ ] Kritik bug'lar pilot fikrlari asosida tuzatilgan
- [ ] App Store + Play Store listing tayyor
- [ ] **2.2 — 2.6-task'lar** ixtiyoriy (kontekstga qarab) — V1 launch'ni blok qilmaydi

V2 keyingi iteratsiyada:
- Real to'lov gateway
- Web ilova
- Premium listing / monetizatsiya kanali kengayishi
- 2.8 — Customer payment flow

---

# Yakuniy Eslatmalar

Ushbu hujjat **manba sifati joriy 7 ta hujjatdan to'plangan**:

- `README.md`
- `ARCHITECTURE.md`
- `ROADMAP.md`
- `PROJECT_STATE_ANALYSIS.md`
- `BUGS_AND_ISSUES.md`
- `REFACTORING.md`
- `supabase_rls_policies.sql.md`
- `docs/legacy/` — kontekst ma'lumotlari uchun

**Yangi'lash siyosati:**

Kodbaza o'zgargan sayin (yangi feature, ya'na bir migratsiya, ya'na bir refaktor) ushbu hujjat ham yangilanishi shart. Tavsiya:

1. Har sprint oxirida `ROADMAP.md` 2-qism'ni yangilang
2. Har 2-3 oyda butun TZ'ni qayta o'qing va dreft'larni topib oling
3. Yangi qaror qabul qilinganda (texnik yoki biznes) 2.26 "O'ziga Xosligi va Tarixiy Qarorlar" bo'limiga qo'shing — boshqa dasturchilar tasodifan buzmasin

> **Maintainer izohi:** Ushbu hujjat yo'qotilgan yoki bilmagan joylarni ham qamrashga harakat qilingan, lekin **siz (loyiha asoschisi sifatida) tarixiy qarorlarni eng yaxshi bilasiz**. Agar TZ'da noto'g'ri yoki yetishmagan joy topsangiz, to'g'ridan-to'g'ri tahrirlang — bu hujjat statik emas, jonli.

# Woody / mebellar_app — Texnik qarz roadmap

> **Status:** Living · **Versiya:** 1.0 · **Sana:** 2026-08-07
> Mahsulot roadmap'i: [roadmap.md](./roadmap.md) · Backlog: [backlog.md](./backlog.md)
> Master spec: [TZ.md](../TZ.md) · Operatsion brain: [CLAUDE.md](../../CLAUDE.md)

Bu hujjat **kod bazasining o'lchangan holatidan** kelib chiqqan — har bir band
2026-08-07 kuni repo'da tekshirilgan, taxmin emas. Boshlang'ich o'lchovlar
[§ Baseline](#baseline--2026-08-07) da.

## Holat belgilari

| Belgi | Ma'no |
|---|---|
| ⬜ | Boshlanmagan |
| 🔄 | Jarayonda |
| ✅ | Bajarilgan (tekshirish buyrug'i o'tgan) |
| ⏭️ | Ataylab o'tkazib yuborilgan (sabab yozilsin) |

**Commit konventsiyasi:** `fix(debt): T-03 PremiumTokens core/theme ga ko'chirildi`

---

## Sprint 0 — Bloklovchi (relizni to'sib turibdi)

> Bu uchtasiz yangi versiya chiqmaydi. Bir kunlik ish.

### ⬜ T-01 · Versiya bump + yangi store relizi

**Muammo.** `1.0.37+37` (sha `46cb842`) relizidan keyin 5 ta commit bor va
ular ichida `pubspec.yaml` + `ios/Podfile.lock` o'zgargan (`device_info_plus`
qo'shilgan, commit `918eec6`). Ya'ni hozirgi `main` **Shorebird patch bilan
yetkazib bo'lmaydi** — native diff bor. Lekin `pubspec.yaml` hali ham
`1.0.37+37` da turibdi.

Qo'shimcha: [tools/shorebird/releases.md](../../tools/shorebird/releases.md)
ga ko'ra **iOS uchun 1.0.37 umuman chiqmagan** — faqat `android` yozilgan.

**Bajarish:**

- [ ] `pubspec.yaml` → `version: 1.0.38+38`
- [ ] `./tools/shorebird.sh check` — blocker'larni ko'rish (native diff kutilyapti)
- [ ] `./tools/shorebird.sh release android`
- [ ] `./tools/shorebird.sh release ios`
- [ ] Ledger'da ikkala platforma ham qayd etilganini tasdiqlash

**Tekshirish:**
```bash
grep '^version:' pubspec.yaml
tail -3 tools/shorebird/releases.md
```

---

### ✅ T-02 · 5 ta sinib turgan testni tuzatish — BAJARILDI (2026-08-07)

**Muammo edi.** `flutter test` → **845 ✅ / 4-6 ❌** (yugurishlar orasida
o'zgaruvchi — tartibga bog'liq flaky).

**Haqiqiy sabab har biri uchun boshida yozilgandan farq qildi** (kod o'qilgach
aniqlandi):

| Test | Dastlabki taxmin | Haqiqiy sabab |
|---|---|---|
| `checkout_screen_widget_test.dart` | dizayn bug, keyinga qoldiriladi | `_PaymentCard.initState` → `refreshPaymentRemoteConfig()` → `sl<WoodyApiClient>()` sinxron chaqiriladi, testda ro'yxatdan o'tmagan. **Test bug** — repo mock'lari qatorida shu ikkitasi ham ro'yxatdan o'tishi kerak edi |
| `onboarding_bloc_test.dart` (×2) | Hive draft box testlar orasida oqmoqda | Oqish yo'q edi. Commit `46cb842` (2026-08-03) `_onStarted`ni **qasddan** o'zgartirgan: endi `businessType == null` bo'lsa ham `individual`ga majburlaydi (rad etilgan arizani qayta ochishda bo'sh KYC formani tuzatish uchun — `business_type_step.dart` ham faqat `individual`ni tanlashga ruxsat beradi). **Kod to'g'ri, testlar eski xulq-atvorni tekshirar edi** — CLAUDE.md testing qoidasiga ko'ra ("decide whether the test or the code is wrong") testlar yangilandi, `canAdvance`ning null-businessType guard'i esa alohida sof state-testida saqlab qolindi |
| `push_service_token_refresh_test.dart` | `_onTokenRefreshed`dagi `catch` siniq | `catch` to'g'ri ishlayotgan edi (izolyatsiyada har doim o'tadi). To'liq to'plam ostida **50ms qattiq kutish** yuklama tagida yetarli emas edi — real flaky sabab shu |

**Bonus topilma:** xuddi shu `sl<WoodyApiClient>()` dizayn muammosi
`wallet_screen.dart`dagi `_TopUpSection.initState`da ham bor edi —
`wallet_screen_test.dart`ning 2 ta testi T-02 ro'yxatida yo'q edi, lekin
to'liq to'plamda muntazam qulab turardi. Xuddi shu naqsh bilan tuzatildi.

**Qilingan o'zgarishlar (faqat testlar, production kod tegilmadi):**

- [x] `checkout_screen_widget_test.dart` — `_MockApi implements WoodyApiClient`
      + `_MockSettingsBox implements Box` ro'yxatdan o'tkazildi (`.get()` xato
      qaytaradi, `refreshPaymentMethods`ning o'zi ushlab oladi)
- [x] `wallet_screen_test.dart` — xuddi shu naqsh (T-02 ro'yxatida yo'q edi,
      qo'shimcha topildi)
- [x] `onboarding_bloc_test.dart` — 2 ta test yangi (to'g'ri) xulq-atvorga
      moslandi + `canAdvance` null-guard uchun alohida sof-state testi qo'shildi
- [x] `push_service_token_refresh_test.dart` — fixed 50ms → poll loop
      (100×10ms ceiling), yuklama ostida barqaror

**Tekshirish natijasi — 3 marta ketma-ket:**
```
Run 1: 02:07 +851: All tests passed!
Run 2: 02:01 +851: All tests passed!
Run 3: 02:11 +851: All tests passed!
```
845 → **851** (yangi `canAdvance` state-testi qo'shildi). `flutter analyze lib/
test/` — o'zgarishsiz, 1 issue (T-02'ga aloqasi yo'q, oldindan bor).

**T-07 (keyingi qadam):** bu ikki fix `sl<>`ni testda "aylanib o'tdi", lekin
`refreshPaymentRemoteConfig()`ning o'zi hali ham widget `initState`i ichida
DI'ga to'g'ridan-to'g'ri murojaat qiladi — bu T-07'ning aynan diagnoz qilgan
muammosi. Bu safar unga tegilmadi (production kod o'zgarmadi).

---

### ✅ T-03 · CI'ni qaytarish — BAJARILDI (2026-08-07)

**Muammo edi.** `.github/` da **workflow fayli yo'q** edi (commit `918eec6` —
"drop GitHub CI/build"), lekin `analysis_options.yaml:5` hali ham *"CI runs
it blocking on every push/PR (see .github/workflows/ci.yml)"* deb turardi —
yolg'on hujjat.

**Qilingan ish.** `.github/workflows/ci.yml` qayta yaratildi — commit
`918eec6`dan oldingi (`918eec6^`) versiyaga asoslangan, `flutter analyze` →
`flutter analyze lib/ test/`ga aniqlashtirilgan (T-02'dagi tekshiruv buyrug'i
bilan bir xil qamrov). Minimal gate: `checkout` → `subosito/flutter-action`
(`channel: stable`) → `flutter pub get` → `flutter analyze lib/ test/` →
`flutter test`.

**Env bandi kerak emas edi.** Roadmap'ning dastlabki bajarish ro'yxatida
"`env/example.json` bilan `--dart-define-from-file` ishlatish" bandi bor
edi — lekin empirik tekshirilgach (to'liq 851-testlik to'plam bir necha
marta hech qanday env fayli bermay **muvaffaqiyatli** o'tdi, chunki testlar
`main.dart`ni yugurtirmaydi, shuning uchun `AppConfig.assertConfigured()`
hech qachon ishga tushmaydi) bu band ortiqcha ekani aniqlandi va qo'shilmadi.
Workflow izohida bu holat va kelajakda kerak bo'lsa nima qilish kerakligi
yozib qo'yildi.

**`analysis_options.yaml`ga tegilmadi** — undagi CI izohi (`.github/workflows/ci.yml`ga
ishora) fayl qayta yaratilgach **avtomatik to'g'ri bo'lib qoldi**, alohida
tahrir kerak emas edi.

**"Qizil bo'lish" tekshiruvi — GitHub'ga push qilmasdan mahalliy simulyatsiya
qilindi** (haqiqiy PR ochish uchun repo'ga push kerak — bu jamoaviy/ko'rinadigan
amal, alohida ruxsatsiz qilinmadi):

```bash
# lib/r.dart ga vaqtinchalik sintaksis xatosi qo'shildi, keyin git checkout bilan qaytarildi
flutter analyze lib/ test/
# → 17 issues found (o'zdan qo'shilgan xato + 1 oldindan bor info), EXIT CODE: 1
```

CI'ning "Analyze" bosqichi aynan shu buyruqni ishlatadi — GitHub Actions har
qanday nolmas chiqishda job'ni siniq (qizil) deb belgilaydi, ya'ni gate real
sintaksis xatosida ishlaydi. `git checkout -- lib/r.dart` bilan qaytarilgandan
so'ng `flutter analyze` yana toza (1 oldindan bor issue).

**Qoldi (foydalanuvchi qaror qiladi):** `.github/`ni commit qilib push qilish
va GitHub Actions'da birinchi haqiqiy yugurishni ko'rish — bu push/PR
harakati, shu sessiyada amalga oshirilmadi.

---

## Sprint 1 — App hajmi (biznes ta'siri eng katta)

> arm64 qurilma uchun hozirgi install ≈ **110 MB**. O'zbekistonda mobil
> internet bilan bu konversiyani o'ldiradi. Maqsad: **< 70 MB**.

### ✅ T-04 · Demo 3D modellarni R2'ga ko'chirish — BAJARILDI (2026-08-07)

**Muammo edi.** 33 MB demo model **har bir foydalanuvchi** bundle'ida —
hatto AR demo tugmasini hech qachon bosmasa ham.

```
assets/models/3d_model_demo.usdz    26.0 MB   ← faqat AR demo
assets/models/3d_model_demo.glb      6.6 MB   ← faqat AR demo
assets/models/onboarding_chair.glb   5.7 MB   ← onboarding page 1
```

Ishlatilish joyi: [ar_demo_launcher.dart](../../lib/customer/features/home/ar_demo_launcher.dart),
[onboarding_screen.dart](../../lib/customer/features/onboarding/screens/onboarding_screen.dart).

**R2 yuklash — inson qo'lda bajardi.** Bu sessiyada R2 credential/CLI mavjud
emas edi (`woody_backend/.env`dagi barcha `R2_*` qiymatlar bo'sh), shuning
uchun 2 faylni jismonan yuklash operator tomonidan Cloudflare dashboard'dan
qo'lda bajarildi — mavjud `product-ar-models` bucket'iga, `demo/` prefiksi
ostida (Meshy pipeline'ning avtomatik mahsulot modellaridan ajratish uchun):

```
https://pub-5877377885304bd181ef407bdc523224.r2.dev/demo/3d_model_demo.glb
https://pub-5877377885304bd181ef407bdc523224.r2.dev/demo/3d_model_demo.usdz
```

**Backend (`woody_backend`) — kod + ma'lumot, ikkalasi ham production'da
tasdiqlangan:**

- [x] Yangi `demo_models` `app_settings` kaliti:
      [`app/domain/settings.py`](../../../woody_backend/app/domain/settings.py)
      `DemoModelsSettings` (`demo_glb_url`/`demo_usdz_url`, http(s)
      validatsiya), typed admin `GET/PUT /admin/settings/demo-models`
      (super_admin), public `GET /catalog/settings/demo_models`
      (`_PUBLIC_SETTING_KEYS`). Testlar yashil (`test_admin_settings_endpoints.py`
      + `test_catalog_endpoints.py`). Migratsiya `0096_seed_demo_models` (bo'sh
      seed) — commit `1c56b06`, push qilindi, GitHub Actions deploy #246 orqali
      production'ga chiqdi.
- [x] Migratsiya `0097_set_demo_models_urls` — haqiqiy R2 URL'larini
      `ON CONFLICT DO UPDATE` bilan yozadi (0096'ning bo'sh seedini yangilaydi).
      Commit `8436c10`, push → deploy → tasdiqlangan:
      `GET https://api.woody.uz/api/v1/catalog/settings/demo_models` →
      `{"demo_glb_url": "https://pub-....r2.dev/demo/3d_model_demo.glb",
      "demo_usdz_url": "https://pub-....r2.dev/demo/3d_model_demo.usdz"}`.

**Flutter (`mebellar_app`):**

- [x] **`RemoteConfig`** (`lib/config/remote_config.dart`) — `demoGlbUrl` /
      `demoUsdzUrl`, Hive kesh, mavjud pattern bo'yicha `_refreshDemoModels`.
- [x] **`ar_demo_launcher.dart`** — endi **faqat R2 URL'dan** ishlaydi
      (bundled fallback **olib tashlandi**, foydalanuvchi qarori bo'yicha:
      "hozircha assetsdan qabul qilmasin"). `RemoteConfig.demoGlbUrl`/`demoUsdzUrl`
      to'g'ridan-to'g'ri `Product3DPreviewScreen`ga uzatiladi — mavjud
      `GlbCacheService`/`ArModelLoadingOverlay` orqali yuklanadi + keshlanadi
      (progress — mavjud loading overlay). **Muhim trade-off:** URL bo'sh
      bo'lgan holatda (masalan, birinchi marta hech qachon `RemoteConfig.refresh()`
      muvaffaqiyatli o'tmagan offline yangi o'rnatish) AR demo endi bundled'ga
      qaytmaydi — yuklash xatosi ko'rsatiladi (mavjud retry overlay). Bu
      ataylab shunday — asosiy oqim emas, "wow" ko'rgazma tugmasi.
- [x] `Product3DPreviewScreen.isLocalAsset` parametri **butunlay olib
      tashlandi** — `ar_demo_launcher.dart` uning yagona `true` chaqiruvchisi
      edi, shu bilan endi o'lik kod edi (`grep isLocalAsset lib/ test/` → faqat
      widget ta'rifi qolardi).
- [x] `assets/models/3d_model_demo.glb` va `.usdz` **repo'dan o'chirildi**.
      `assets/models/` endi faqat siqilgan `onboarding_chair.glb` (808 KB).
- [x] `pubspec.yaml`dagi eskirgan izoh yangilandi.
- [x] `onboarding_screen.dart:777` — qattiq yozilgan literal
      `AssetModels.onboardingChair` konstantasiga almashtirildi.
- [x] **`onboarding_chair.glb` siqildi** — `npx @gltf-transform/cli optimize
      --compress draco --simplify false` (geometriya **o'zgarmadi**): **5.68 MB
      → 808 KB**. Backend'ning AR pipeline'i (`model_compressor.py`) xuddi shu
      `gltf-transform --compress draco` buyrug'ini ishlatadi — model-viewer bu
      formatni prod'da allaqachon qo'llab-quvvatlaydi.
- [x] `flutter analyze lib/customer/features/home/ar_demo_launcher.dart
      lib/shared/widgets/ar/product_3d_preview_view.dart` — toza. AR-aloqador
      testlar (`buyer_ar_viewer_screen_test`, `ios_quick_look_test`,
      `ar_viewer_cubit_test`, `onboarding_screen_test`, `remote_config_test`)
      — 64/64 yashil.

**Tekshirish:**
```bash
du -sh assets/models
# → 808K (33 MB dan — maqsad "< 2 MB" edi, haqiqiy natija ancha yaxshi)

curl -s https://api.woody.uz/api/v1/catalog/settings/demo_models
# → haqiqiy R2 URL'lari (tasdiqlangan, yuqorida)
```

---

### ✅ T-05 · Lottie va qolgan asset'larni siqish — BAJARILDI (2026-08-07)

**Muammo edi.** `assets/lottie/ai_animation2.json` = **4.8 MB** — bitta
loading animatsiyasi ([ai_loading_overlay.dart:8](../../lib/seller/features/products/widgets/product_form/ai_loading_overlay.dart#L8)).
Tekshirilgach tasdiqlandi: bu **raster-frame Lottie** — 9 ta base64-kodlangan
PNG rasm (720×804 va 1080×1206) JSON ichiga qotirilgan, animatsiya shu
rasmlar orasida almashinib ketadi (vektor emas).

**1) `ai_animation2.json` — PNG → WebP (4.8 MB → 1.3 MB, −72%).**
Har bir embedded rasm `cwebp -q 90 -m 6` bilan qayta kodlandi; layer/keyframe/
timing/`w`/`h` — **hech biriga tegilmadi**, faqat `p` (base64 payload) va
MIME prefiksi (`image/png` → `image/webp`) o'zgardi. Xavfsizlik asosi:
`lottie` paketi (`load_image.dart:fromDataUri`) baytlarni
`Uri.parse(...).data!.contentAsBytes()` bilan MIME'dan mustaqil dekodlaydi —
Flutter'ning Skia kodeki formatni baytlardan aniqlaydi, deklaratsiyadan emas.

- Har 9 rasm alohida tekshirildi: JSON struktura diffi (`p`dan tashqari **bir
  xil**), `dwebp` bilan qayta dekodlash + o'lcham tekshiruvi (barchasi mos),
  va yangi regression test —
  [test/.../ai_loading_overlay_test.dart](../../test/seller/features/products/widgets/product_form/ai_loading_overlay_test.dart) —
  `dart:ui.instantiateImageCodec` orqali **haqiqiy Flutter engine kodeki**
  bilan barcha 9 baytni dekodlab, aniq piksel o'lchamini tasdiqlaydi.
- `ai_loading_overlay.dart`dagi eskirgan "~5MB" izohi yangilanmadi (kod
  o'zgarmadi, faqat asset) — keyingi safar shu faylga tegilganda tuzatiladi.

**2) `assets/images/onboarding/` — JPEG → WebP (1.0 MB → 872 KB, −13%).**
12 ta rasm `cwebp -q 90 -m 6`. Kutilganidan kamroq: manba JPEG allaqachon
siqilgan, JPEG→WebP qayta siqish "ikkinchi avlod" yo'qotish qo'shadi —
q=90'da bitta rasm (grid_1) hatto **kattaroq** chiqdi (102 KB > 95 KB orig).
Har bir konvertatsiyani vizual tekshirdim (original vs dekodlangan WebP,
yon-yonma) — farq sezilmaydi (bu marquee fon, doim harakatda). Kod:
[onboarding_screen.dart `_marqueeImages`](../../lib/customer/features/onboarding/screens/onboarding_screen.dart)
`.jpeg` → `.webp`ga yangilandi, eski JPEG'lar o'chirildi.

**3) `assets/google_fonts/` — Manrope 100% o'lik topildi va o'chirildi
(3.0 MB → 2.5 MB, 21 → 16 fayl).** Vazn-darajasida emas — **butun oila**
ishlatilmas edi: `AppFonts.accent` (Manrope'ga yagona yo'l) hech qayerda
chaqirilmagan, hech qanday hardcoded `'Manrope'` satri yo'q, va
`dashboard_screen.dart`dagi yagona "intentional exception" izohi aynan shu
CTA **allaqachon olib tashlanganini** hujjatlashtirgan edi. Boshqa 4 oila
(Inter/PlayfairDisplay/PlusJakartaSans + har bir og'irlik 400-800) —
**hammasi** `lib/`da ishlatilgan (`FontWeight.w400..800` global qidiruv —
har biri yuzlab joyda), oila-og'irlik bog'lanishini ishonchli izohlab
bo'lmagani uchun **tegilmadi** (noaniq holatda o'chirmaslik — CLAUDE.md).
5 ta `Manrope-*.ttf` o'chirildi, `pubspec.yaml`dan `fonts:` bloki,
`AppFonts.accent` konstantasi, `r.dart`dagi `manrope*` yozuvlari olib
tashlandi.

**Umumiy natija:**
```
assets/lottie              4.9M → 1.5M
assets/images/onboarding   1.0M → 872K
assets/google_fonts        3.0M → 2.5M
assets/ (jami)               48M → 39M   (T-04 bilan birga — u ham shu
                                           sessiyada davom etmoqda)
```

**Tekshirish:**
```bash
du -sh assets/lottie assets/images/onboarding assets/google_fonts
flutter test test/seller/features/products/widgets/product_form/ai_loading_overlay_test.dart
flutter test --reporter=compact | tail -1   # → All tests passed! (855)
```

---

### ✅ T-06 · Yandex MapKit hajmini qayta ko'rib chiqish (tadqiqot) — YOPILDI, o'zgartirilmadi (2026-08-07)

**Muammo edi.** `libmaps-mobile.so` = **26 MB** (arm64) — bitta eng katta
native kutubxona. Ishlatilishi: ikkala manzil tanlash ekrani
([map_address_picker_screen.dart](../../lib/customer/features/checkout/screens/map_address_picker_screen.dart),
[shop_address_step.dart](../../lib/seller/features/onboarding/widgets/shop_address_step.dart)).

**Qaror: `yandex_mapkit_lite`ga o'tilmaydi — hozirgi paket allaqachon
native "lite" SDK ishlatadi, almashtirish foyda bermaydi.**

**Topilma.** Ikkala manzil ekranida ham ishlatiladigan API juda tor:
faqat `YandexMap`/`YandexMapController`/`CameraPosition`/`CameraUpdate`/
`Point`/`MapAnimation` — marker/`MapObject`/`Placemark`/polygon/cluster
**hech qayerda ishlatilmaydi** (`mapObjects: const []`). Bu
`yandex_mapkit_lite`ga juda mos ko'rinardi — lekin paketning o'zini
tekshirganda:

- Hozirgi `yandex_mapkit ^4.2.1`ning
  [`android/build.gradle`](file:///Users/eldor/.pub-cache/hosted/pub.dev/yandex_mapkit-4.2.1/android/build.gradle)
  fayli:
  ```gradle
  def variant = project.hasProperty("yandexMapkit.variant") ? project.property("yandexMapkit.variant") : "lite"
  ...
  implementation 'com.yandex.android:maps.mobile:4.22.0-' + variant
  ```
  **Standart qiymat — `"lite"`.** `android/build.gradle.kts` va
  `android/gradle.properties`da bu qiymatni `"full"`ga o'zgartiradigan
  hech qanday override **yo'q** (`grep -rn "yandexMapkit" android/` —
  bo'sh natija). Ya'ni AAB'dagi 26 MB **allaqachon lite native SDK'dir**,
  "full" emas.
- `yandex_mapkit_lite` paketi (Surf, `pub.dev`): oxirgi reliz **2024-04-18**
  (2+ yil yangilanmagan), `yandex_mapkit`ning **eski 3.4.0** versiyasidan
  fork qilingan, va natijada bizning `4.22.0-lite`dan **eskiroq**
  `com.yandex.android:maps.mobile:4.4.0-lite`ni tortadi.

**Xulosa:** almashtirish — hajmda **nol foyda** (ikkalasi ham xuddi shu
native "lite" SDK oilasi, faqat versiya eskiroq), lekin real **regressiya
xavfi** bor (2 yillik parvarishlanmagan fork, checkout va seller onboarding
manzil oqimlari — ikkalasi ham tijorat uchun kritik). Foydalanuvchi bilan
tasdiqlangach (2026-08-07), paket almashtirilmadi.

**Qoldi (agar kelajakda hajm яна muammo bo'lsa):** interaktiv xaritani
statik rasm + `YANDEX_GEOCODER_API_KEY` bilan almashtirish hali ham nazariy
variant — lekin bu UX'ni pasaytiradi (sudrab pin qo'yish endi mumkin
bo'lmaydi) va 26 MB alohida o'zi hal qiluvchi omil emas edi. Alohida so'rov
bo'lmasa, ochilmaydi.

---

## Sprint 2 — Arxitektura qarzi

### ⬜ T-07 · Service locator'ni UI'dan chiqarish

**Muammo.** `screens/` va `widgets/` ichida **129 ta `sl<...>`** chaqiruv.
Cubit'larda constructor injection to'g'ri qilingan — widget'larda emas.
Natija: widget testlar yozilmaydi. `checkout_screen_widget_test` aynan
shundan qulagan:

```
Bad state: GetIt: Object/factory with type WoodyApiClient is not registered
  #5  refreshPaymentRemoteConfig (lib/shared/payments/refresh_payment_remote_config.dart:13)
  #6  _PaymentCardState.initState (lib/customer/features/checkout/screens/checkout_screen.dart:506)
```

**Bajarish (bosqichma-bosqich, hammasini bir vaqtda emas):**

- [ ] **Birinchi:** [checkout_screen.dart:506](../../lib/customer/features/checkout/screens/checkout_screen.dart#L506)
      — `refreshPaymentRemoteConfig`ni `CheckoutCubit`ga ko'chirish
      (T-02 dagi testni yashil qiladi)
- [ ] Qolganini ro'yxatga olish va **feature bo'yicha** hal qilish, tartib:
      `checkout` → `orders` → `wallet` → `products`
- [ ] Yangi qoida: widget ichida `sl<>` — faqat `AnalyticsService` va
      `AppLocaleController` kabi global, holatsiz servislar uchun.
      Repository — hech qachon.

**Tekshirish:**
```bash
grep -rn "sl<" lib/ --include="*.dart" | grep -E "screens/|widgets/" | wc -l
# baseline: 129 — har sprint'da kamayishi kerak
```

---

### ✅ T-08 · `PremiumTokens`ni `lib/core/theme/` ga ko'chirish — BAJARILDI (2026-08-07)

**Muammo edi.** `lib/shared/` **11 ta faylda**
`lib/customer/features/home/widgets/premium/premium_tokens.dart` ni import
qiladi. Ya'ni cross-mode shared chat modul bitta customer feature'iga bog'liq.
Bu [architecture.md](../../.claude/rules/architecture.md) rule card'iga zid
("Cross-mode code lives in `lib/shared/`").

**Qilingan ish.**

- [x] `git mv lib/customer/features/home/widgets/premium/premium_tokens.dart
      lib/core/theme/premium_tokens.dart` — tarix saqlanadi.
- [x] **78 fayldagi** (11 ta `lib/shared/`da, qolgani `customer/`/`seller/`/`core/`
      ichida to'g'ridan-to'g'ri import qilganlar — roadmap'dagi dastlabki "11 ta"
      faqat `lib/shared/` chegara buzilishini sanagan edi, haqiqiy import
      qamrovi ancha kattaroq chiqdi) importi yangilandi — Python skript bilan
      har bir faylning papka chuqurligidan yangi manzilgacha **to'g'ri
      nisbiy yo'l** hisoblab chiqildi (mexanik, `dart fix` ishlatilmadi, chunki
      u import ko'chirishni emas, faqat lint-tuzatishni avtomatlashtiradi).
      Bitta fayl (`test/shared/chat/chat_list_tile_test.dart`) `package:woody_app/...`
      absolyut import ishlatgani uchun skript pattern'iga tushmadi — qo'lda
      tuzatildi.
- [x] Eski joyda re-export **qoldirilmadi** — `grep -rn
      "customer/features/home/widgets/premium/premium_tokens" lib/ test/"`
      bo'sh natija.
- [x] `flutter analyze` (78 fayl) — toza. `flutter test` — to'liq to'plam
      yashil (mavjud, T-04'dan oldingi holatdan farqsiz).

**Tekshirish natijasi:**
```bash
grep -rn "import.*\(customer\|seller\)/" lib/shared --include="*.dart" | wc -l
# baseline 15 → 4 (aniq maqsadga mos: faqat manual_payment_pending_screen,
# T-09'ning o'zi — 4 ta seller import, keyingi navbatda)
```

---

### ✅ T-09 · `manual_payment_pending_screen` ni `shared/` dan chiqarish — BAJARILDI (2026-08-07)

**Muammo edi.** `manual_payment_pending_screen.dart` `shared/` dan **4 ta
seller faylini** import qilardi (`ar_token_repository`, `tariff_history_screen`,
`ar_token_purchase_history_screen`, `wallet_history_screen`). Ya'ni bu ekran
aslida shared emas — seller ekrani.

**Aniqlandi: faqat seller'da ishlatiladi.** `grep -rln
"manual_payment_pending_screen\|ManualPaymentPendingScreen" lib/` — barcha 5
chaqiruvchi (`ar_token_buy_section.dart`, `tariff_screen.dart`,
`tariff_payment_screen.dart`, `ar_tokens_screen.dart`, `wallet_screen.dart`)
`lib/seller/` ostida; `lib/customer/`da **birorta ham** yo'q, test ham yo'q.
Ekranning o'zi ham to'liq seller-ga xos (`SellerColors`, `AppFonts.seller`,
`tr('seller.*')` kalitlar) — customer'da qayta ishlatish niyati yo'q edi.

**Qilingan ish.**

- [x] `git mv lib/shared/payments/manual_payment_pending_screen.dart
      lib/seller/features/payments/manual_payment_pending_screen.dart`
- [x] Faylning o'z ichidagi 13 ta import — yangi joydan hisoblangan to'g'ri
      nisbiy yo'lga yangilandi (Python skript, T-08dagi bilan bir xil usul).
- [x] 5 ta chaqiruvchi faylning importi yangilandi.
- [x] `payment_pending_copy.dart` (sherik fayl, xuddi shu papkada) **ko'chirilmadi**
      — u faqat `core/i18n`ga bog'liq, customer/seller'ga import qilmaydi,
      demak chegara buzilishi yo'q (faqat bugungi yagona iste'molchisi seller
      bo'lgani chegara qoidasini buzmaydi — qoida import yo'nalishi haqida,
      kim ishlatishi haqida emas).
- [x] Eski joyda re-export qoldirilmadi — `grep -rn
      "shared/payments/manual_payment_pending_screen" lib/ test/"` bo'sh.

**Tekshirish natijasi:**
```bash
grep -rn "import.*\(customer\|seller\)/" lib/shared --include="*.dart" | wc -l
# 4 → 0 — Sprint 2'ning shu bo'yicha maqsadi to'liq bajarildi

flutter analyze <6 ta tegilgan fayl>   # toza
flutter test test/seller/features/wallet/screens/wallet_screen_test.dart
# 2/2 yashil
```

---

### ⬜ T-10 · `Result<T>` migratsiyasini yakunlash

**Muammo.** [CLAUDE.md](../../CLAUDE.md) va
[error-handling.md](../../.claude/rules/error-handling.md)
`order → seller_wallet → seller_product → seller_onboarding` migratsiyasini
va'da qilgan. Tekshirdim — **to'rttasida ham `Result<` = 0**. Ya'ni pul va
buyurtma yo'lidagi eng xavfli repo'lar hali `throw`da.

Va'da qilingan `test/architecture/result_boundary_test.dart` guard testi ham
yo'q — hech narsa **yangi** buzilishni to'xtatmaydi.

**Bajarish (har biri alohida commit + testlar bilan):**

- [ ] `order_repository` → `Result<T>` (eng yuqori xavf)
- [ ] `seller_wallet_repository` → `Result<T>`
- [ ] `seller_product_repository` → `Result<T>`
- [ ] `seller_onboarding_repository` → `Result<T>`
- [ ] `test/architecture/result_boundary_test.dart` — guard test yozish:
      har bir repo fayli **to'liq-`Result` yoki to'liq-`throw`**, aralash emas.
      Yuqoridagi 4 tasi migratsiya davomida allowlist'da tursin.

**Naqsh:** `runCatching(...)` + `apiErrorToFailure`
([api_error_messages.dart](../../lib/core/network/api_error_messages.dart)) —
`payment` va `checkout` da allaqachon qilingan, o'shani takrorlang.

**Tekshirish:**
```bash
for f in order seller_wallet seller_product seller_onboarding; do
  echo -n "$f: "; grep -c "Result<" lib/shared/repositories/${f}_repository.dart
done
```

---

## Sprint 3 — Hujjat va repo gigienasi

### ⬜ T-11 · CLAUDE.md'ga AR / 3D bo'limini yozish

**Muammo.** CLAUDE.md'da **AR / 3D / Meshy haqida 0 ta eslatma**. Bu:
- ~5000 qatorlik feature (`buyer_ar_viewer_screen` 1084, `product_3d_preview_view` 1064, `ar_section` 991, `set_ar_viewer_screen` 874, `ar_token_buy_section` 913…)
- **Native** dependency (`ar_flutter_plugin_plus`, `model_viewer_plus`, `camera`, `gal`, `webview_flutter`) — ya'ni Shorebird patch'ni bloklaydi
- AR token iqtisodiyoti bilan bog'langan (sotuvchi token sotib oladi)

Brain'da yo'q feature keyingi sessiyada noto'g'ri o'zgartiriladi.

**Bajarish:**

- [ ] `## AR / 3D pipeline` bo'limi: Meshy oqimi (3 foto → skan → moderatsiya → GLB/USDZ),
      buyer viewer vs native AR farqi, AR token modeli, **native = patch qilinmaydi** invariant'i
- [ ] `support` (voice chat), `broadcasts`, `tutorial` feature'larini ham qo'shish
- [ ] `## Recent feature work` bo'limini yangilash

---

### ⬜ T-12 · Hujjat drift'ini tozalash

- [ ] `docs/` (6 ta fayl, iyun) va `doc/` — ikkita hujjat uyi.
      CLAUDE.md `doc/` ni "sole home" deydi. `docs/` ni `doc/` ga birlashtirish
      yoki o'chirish
- [ ] README `1.0.36+36` deydi, pubspec `1.0.37+37` — versiyani README'dan
      butunlay olib tashlash (u har relizda eskiradi)
- [ ] [analysis_options.yaml:5](../../analysis_options.yaml#L5) — CI izohi
      (T-03 bilan birga)
- [ ] `woody_mobile_tz.md`, `WOODY_PROJECT_CONTEXT.md` — redirect stub'lar,
      hali keraklimi?

---

### ⬜ T-13 · Papka nomlaridagi ikkilanishni yo'q qilish

**Muammo.** [lib/core/deep_links/](../../lib/core/deep_links/) va
[lib/core/deeplink/](../../lib/core/deeplink/) — deyarli bir xil nomli ikki
papka, har birida bitta fayl, **ikkalasi ham ishlatiladi**. Bu importda
adashishga to'g'ridan-to'g'ri taklif.

**Bajarish:**

- [ ] `deferred_deep_link_service.dart` ni `core/deep_links/` ga ko'chirish
- [ ] `core/deeplink/` ni o'chirish
- [ ] 6 ta importni yangilash

---

### ⬜ T-14 · Repo'dan marketing artefaktlarini chiqarish

**Muammo.** `.git` = **150 MB**. Kod repo'sida:

```
Woody_Investor_Deck.pptx           7.6 MB   (root)
Woody_Investor_Deck copy.pptx      3.4 MB   (root — dublikat)
doc/Woody_Investor_Deck.pptx       3.4 MB   (yana dublikat)
Woody_Pitch_Deck.pdf               666 KB   (root va doc/ da)
Woody_Pitch_Deck.html              ikki joyda
large-thumbnail...mp4              1.0 MB   (root)
```

Jami 275 ta tracked `.md` fayl ham bor.

**Bajarish:**

- [ ] Pitch/investor materiallarini alohida joyga (Drive / alohida repo) ko'chirish
- [ ] `git rm --cached` + `.gitignore` ga `*.pptx`, `*.mp4` qo'shish
      *(tarixdan o'chirish — `filter-repo` — alohida, ehtiyotkorlik bilan;
      hozircha shart emas)*
- [ ] Lokal `dist/` (3 GB eski AAB/IPA) va `build/` ni tozalash
- [ ] `.history/` (VSCode local history) — `.gitignore`da bor, lekin diskda
      turibdi, tozalash mumkin

---

## Sprint 4 — Bog'liqliklar

### ⬜ T-15 · Major yangilanishlar (bosqichma-bosqich)

**Muammo.** Sezilarli orqada qolish — har bir kechikish keyingi migratsiyani
qimmatlashtiradi va xavfsizlik patch'lari ham o'tkazib yuborilmoqda.

| Paket | Hozir | Oxirgi | Sakrash |
|---|---|---|---|
| `go_router` | 14.8 | 17.4 | 3 major |
| `flutter_local_notifications` | 18.0 | 22.2 | 4 major |
| `firebase_core` | 3.15 | 4.13 | 1 major |
| `firebase_messaging` | 15.2 | 16.5 | 1 major |
| `firebase_crashlytics` | 4.3 | 5.2 | 1 major |
| `firebase_analytics` | 11.6 | 12.4 | 1 major |
| `flutter_secure_storage` | 9.2 | 11.0 | 2 major |
| `package_info_plus` | 8.3 | 10.2 | 2 major |
| `device_info_plus` | 11.5 | 13.2 | 2 major |
| `fl_chart` | 0.69 | 1.2 | 1 major |
| `record` | 5.2 | 7.1 | 2 major |
| `connectivity_plus` | 6.1 | 7.3 | 1 major |
| `share_plus` | 12.0 | 13.3 | 1 major |
| `camera` | 0.11 | 0.12 | minor |
| `get_it` | 8.3 | 9.2 | 1 major |

**Tartib (xavf bo'yicha, eng oson birinchi):**

- [ ] **1-to'lqin — patch/minor, xavfsiz:** `dio`, `equatable`, `lottie`,
      `gal`, `app_badge_plus`, `flutter_cache_manager`, `flutter_image_compress`,
      `facebook_app_events`, `yandex_mapkit`, `webview_flutter`
      → `flutter pub upgrade` + `flutter test`
- [ ] **2-to'lqin — Firebase to'plami** (birga yangilanadi: core + messaging +
      crashlytics + analytics). iOS `Podfile.lock` Firebase pinini ham
      moslashtirish (README'da 11.15.0 deb qayd etilgan)
- [ ] **3-to'lqin — `go_router` 14 → 17.** Eng katta xavf: ikkita router
      (`customer/router.dart` + `seller_router.dart` `StatefulShellRoute` bilan).
      `test/customer/navigation/` testlari bu yerda qalqon bo'ladi
- [ ] **4-to'lqin — qolganlari** birma-bir

**Har to'lqindan keyin:** `flutter test` + qurilmada qo'lda smoke test.
**Har to'lqin = alohida commit** (rollback oson bo'lsin).

---

## Sprint 5 — Sifat va kelajakdagi og'riq

### ⬜ T-16 · God-file'larni bo'lish

34 fayl > 700 qator, 65 fayl > 500. Eng kattalari:

| Fayl | Qator |
|---|---|
| [seller/features/wallet/screens/wallet_screen.dart](../../lib/seller/features/wallet/screens/wallet_screen.dart) | 1955 |
| [core/i18n/translations/seller_translations.dart](../../lib/core/i18n/translations/seller_translations.dart) | 1722 (92 KB) |
| [customer/features/checkout/screens/checkout_screen.dart](../../lib/customer/features/checkout/screens/checkout_screen.dart) | 1374 |
| [customer/features/product_list/screens/catalog_product_detail_screen.dart](../../lib/customer/features/product_list/screens/catalog_product_detail_screen.dart) | 1367 |
| [customer/features/home/screens/home_screen.dart](../../lib/customer/features/home/screens/home_screen.dart) | 1357 |

**Bajarish:** faqat **tegib o'tgan faylni** bo'ling — "hammasini bir vaqtda
refactor" qilmang. Boshqa sabab bilan `checkout_screen.dart`ni ochsangiz,
o'sha safar bitta `widgets/` faylini ajratib chiqing.

- [ ] `seller_translations.dart` — bu eng arzon g'alaba: domen bo'yicha
      (`wallet`, `tariff`, `products`, `orders`) alohida bundle'larga bo'lish
- [ ] `wallet_screen.dart` — `widgets/` papkasiga ajratish
- [ ] Yangi qoida: **yangi** ekran 500 qatordan oshmasin

---

### ⬜ T-17 · Auth ekranidagi hardcoded o'zbekcha matn

**Muammo.** Rus tilidagi foydalanuvchi **login ekranida** o'zbekcha sarlavha
ko'radi. O'zbekiston bozorida bu sezilarli.

- [ ] [auth/sheets/phone_step.dart:85](../../lib/auth/sheets/phone_step.dart#L85) — `'Tizimga kirish'`
- [ ] [auth/sheets/otp_step.dart:52](../../lib/auth/sheets/otp_step.dart#L52) — `'Kodni kiriting'`
- [ ] [auth/sheets/profile_step.dart:28](../../lib/auth/sheets/profile_step.dart#L28) — `'Tanishing, siz kimsiz?'`
- [ ] [customer/router.dart:273](../../lib/customer/router.dart#L273) — `'Savatch bo'sh — orqaga qayting'`
- [ ] [customer/customer_app.dart:453](../../lib/customer/customer_app.dart#L453) — `'Ilovadan chiqish uchun...'`

Har biri uchun uz/ru/en bundle'larga key qo'shish (`auth.*` domenida).

**Tekshirish:**
```bash
grep -rnE "Text\(\s*'[A-ZА-Яa-zа-я][^']{4,}'" lib/ --include="*.dart" | grep -v "tr(" | wc -l
# baseline: 5 → maqsad: 0
flutter test test/core/i18n/i18n_completeness_test.dart
```

---

### ⬜ T-18 · O'lik kodni tozalash

- [ ] [shared/repositories/category_data_source.dart:15](../../lib/shared/repositories/category_data_source.dart#L15)
      `MockCategoryDataSource` — **hech qayerda ishlatilmaydi**
      (DI faqat `WoodyCategoryRepository`ni ulaydi). Unsplash URL'lari bilan
      mock data bundle'da yotibdi. O'chirish
- [ ] `MockProductDataSource` — faqat bitta testda ishlatiladi
      → `test/fixtures/` ga ko'chirish
- [ ] Root'dagi `run`, `screen_phone`, `test_analytics_privacy/`,
      `test_presence_service/` (bo'sh papkalar) — tozalash

---

### ⬜ T-19 · Accessibility bazasi

**Muammo.** 509 fayl, atigi **4 ta** `Semantics`/`semanticLabel`.
`textScaler` bo'yicha ish yo'q → tizim shriftini kattalashtirilgan qurilmada
overflow xavfi (aynan `checkout` va `order_detail` kabi zich ekranlarda).

Bu shoshilinch emas, lekin App Store / Play review'da ham, real foydalanuvchida
ham chiqadi.

- [ ] Faqat **ikonka-tugmalarga** `semanticLabel` qo'shish (eng katta ta'sir,
      eng kam ish): savat, sevimlilar, ulashish, orqaga
- [ ] `checkout_screen` va `order_detail_screen`ni `textScaleFactor: 1.5`
      bilan widget testda pump qilib overflow yo'qligini tasdiqlash
- [ ] Golden test bazasi (`test/goldens/` allaqachon bor) shu holat uchun

---

### ⬜ T-20 · `minSdk 26` qarorini qayta ko'rib chiqish (tadqiqot)

`android/app/build.gradle.kts:46` → `minSdk = 26` (Android 8.0+).
Sabab: `java.time` ishlatadigan plugin. Bu bozorda bir necha foiz qurilma
tashqarida qoladi.

- [ ] Play Console'da haqiqiy qurilma taqsimotini ko'rish — yo'qotish qancha?
- [ ] `coreLibraryDesugaring` bilan `minSdk 21` ga tushish mumkinmi?
- [ ] Qaror va sabab shu yerga yozilsin (natija "qoldiramiz" bo'lishi ham to'g'ri)

---

## Baseline — 2026-08-07

Progress'ni o'lchash uchun boshlang'ich nuqta. Sprint tugaganda qayta yugurting:

```bash
# Kod hajmi
find lib -name "*.dart" | wc -l                                    # 509
find lib -name "*.dart" -exec cat {} + | wc -l                     # 125212
find lib -name "*.dart" -exec wc -l {} + | awk '$1>700' | wc -l    # 34

# Sifat
flutter analyze lib/ test/ 2>&1 | tail -1                          # 1 issue
flutter test --reporter=compact 2>&1 | tail -1                     # 845 +5 -5

# Arxitektura
grep -rn "sl<" lib/ --include="*.dart" | grep -E "screens/|widgets/" | wc -l   # 129
grep -rn "import.*\(customer\|seller\)/" lib/shared --include="*.dart" | wc -l # 15

# Hajm
du -sh assets                                                      # 48M
du -sh assets/models                                               # 38M

# i18n
grep -rnE "Text\(\s*'[A-ZА-Яa-zа-я][^']{4,}'" lib/ --include="*.dart" \
  | grep -v "tr(" | wc -l                                          # 5
```

---

## Tavsiya etilgan tartib

```
Sprint 0  →  T-01, T-02, T-03          (1–2 kun · relizni ochadi)
Sprint 1  →  T-04, T-05                (2–3 kun · 48 MB → ~8 MB)
Sprint 2  →  T-08, T-07, T-10, T-09    (bosqichma-bosqich · haftalar)
Sprint 3  →  T-11, T-12, T-13, T-14    (1 kun · arzon g'alabalar)
Sprint 4  →  T-15                      (to'lqin-to'lqin · fon ishi)
Sprint 5  →  T-16..T-20                (tegib o'tganda)
```

**Muhim:** Sprint 0 tugamaguncha boshqasiga o'tmang. CI'siz (T-03) qolgan
hamma tuzatish asta-sekin qayta buziladi.

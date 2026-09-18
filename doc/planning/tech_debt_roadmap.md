# Woody / mebellar_app — Texnik qarz roadmap

> **Status:** Living · **Versiya:** 1.1 · **Sana:** 2026-09-17
> Mahsulot roadmap'i: [roadmap.md](./roadmap.md) · Backlog: [backlog.md](./backlog.md)
> Master spec: [TZ.md](../TZ.md) · Operatsion brain: [CLAUDE.md](../../CLAUDE.md)

Bu hujjat **kod bazasining o'lchangan holatidan** kelib chiqqan — har bir band
repo'da tekshirilgan, taxmin emas. Boshlang'ich o'lchovlar
[§ Baseline](#baseline) da; 2026-08-07 (v1.0) va 2026-09-17 (v1.1) ustunlari
yonma-yon turadi, shunda progress ko'rinadi.

**v1.1 da o'zgargani (2026-09-17):** CI **olib tashlandi** (T-03 qayta yozildi);
T-01 endi `1.0.40+40` relizi haqida; **T-10 yakunlandi (2026-09-18)**; T-11
bajarildi; T-15 3-to'lqin kattalashdi (`go_router` endi 18.x).

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

> **2026-09-17:** T-02 va T-03 yopildi (T-03 — CI olib tashlanishi bilan).
> Bu sprintdan **faqat T-01 ochiq**, va u eng shoshilinch band: App Store'dagi
> ITMS-91064 tuzatmasi `main` da turibdi, lekin chiqmagan.

### ⬜ T-01 · `1.0.40+40` ni store'ga chiqarish (2026-09-17 holati)

> Bu band har relizda qayta ochiladi. Quyidagi matn **2026-09-17** holatini
> tasvirlaydi.
>
> ✅ **Tayyorgarlik bajarildi (2026-09-18):**
> [`release_1_0_40_prep.md`](release_1_0_40_prep.md) — tasdiqlangan blocker
> ro'yxati (`ios/Runner/PrivacyInfo.xcprivacy`, `android/settings.gradle.kts`,
> `pubspec.yaml`+`.lock` — ya'ni **patch emas, `release`**), mahalliy gate,
> ikkala do'kon uchun konsol qadamlari va ledger yozuvi shabloni.
> **Relizning o'zi sizda qoladi** — `shorebird release` imzolash kalitlarini
> talab qiladi.

**Muammo.** `pubspec.yaml` `1.0.40+40` da, lekin
[tools/shorebird/releases.md](../../tools/shorebird/releases.md) dagi oxirgi
yozuv — `1.0.39+39` (`e333566d43e8`, 2026-08-11, android + ios). Ya'ni
**12 commit relizsiz turibdi**.

**Nega Shorebird patch yetarli emas.** `1.0.39+39` dan beri o'zgargan fayllar
ichida ikkita patch-bloker bor:

| Fayl | Nega bloker |
|---|---|
| `ios/Runner/PrivacyInfo.xcprivacy` | native (iOS) diff |
| `pubspec.yaml` | versiya + bog'liqlik maydoni |

Qolgani Dart — lekin bitta native diff ham patch'ni bekor qiladi.

**Va bu shoshilinch.** `1.0.39` ning iOS build'i Apple tomonidan
**ITMS-91064** bilan rad etilgan (`NSPrivacyTracking=true` + **bo'sh**
`NSPrivacyTrackingDomains` — Apple TN3181 buni aniq nomlaydi). Tuzatma
commit `a8154a4` da (`ep1.facebook.com` e'lon qilindi), lekin **hali
chiqmagan**: hozir App Store'da bu tuzatma yo'q.

**Bajarish:**

- [x] `pubspec.yaml` → `version: 1.0.40+40` (commit `a8154a4`)
- [ ] `./tools/shorebird.sh check` — blocker'larni ko'rish (native diff kutilyapti)
- [ ] `./tools/shorebird.sh release android`
- [ ] `./tools/shorebird.sh release ios`
- [ ] iOS'da ITMS-91064 o'tganini App Store Connect'da tasdiqlash
- [ ] [`release_checklist.md`](../release_checklist.md) ni yurib chiqish
      (APNs kaliti, Play Ad-ID deklaratsiyasi, maxfiylik javoblari)
- [ ] Ledger'da ikkala platforma ham qayd etilganini tasdiqlash

**Tekshirish:**
```bash
grep '^version:' pubspec.yaml
tail -3 tools/shorebird/releases.md
git diff --name-only <oxirgi_ledger_sha>..HEAD | grep -E '^(android|ios|assets|pubspec)'
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

### ⏭️ T-03 · CI — QAYTARILDI, SO'NG OLIB TASHLANDI (2026-09-17)

> Bu band ikki marta qaror qabul qilingan. Tarix muhim, chunki
> `analysis_options.yaml` ikkalasida ham tahrirlangan.

**1-qaror (2026-08-07) — qaytarildi.** `.github/` da workflow fayli yo'q edi
(commit `918eec6` — "drop GitHub CI/build"), lekin `analysis_options.yaml:5`
hali ham *"CI runs it blocking on every push/PR"* deb turardi — yolg'on hujjat.
`.github/workflows/ci.yml` qayta yaratildi: `checkout` →
`subosito/flutter-action` (`channel: stable`) → `flutter pub get` →
`flutter analyze lib/ test/` → `flutter test`. Env bandi kerak bo'lmadi —
testlar `main.dart`ni yugurtirmaydi, shuning uchun `AppConfig.assertConfigured()`
hech qachon ishga tushmaydi.

**Nima bo'ldi.** Workflow push qilingandan keyin **2026-08-20 dan 2026-09-11
gacha 5/5 push qizil** bo'ldi — kod sababli emas. `channel: stable` **pin
qilinmagan** edi, shuning uchun runner Flutter **3.47.3** ga ko'tarildi, mahalliy
SDK esa **3.44.9** da qoldi. Yangi analizator mahalliy analizatorda umuman
bo'lmagan lint chiqardi:

```
warning • Returning a 'Future' without 'await' inside a try block
        • lib/core/cache/cache_service.dart:33 • unawaited_return_in_try_block
```

`flutter analyze` warning'da exit 1 qaytaradi → butun pipeline yiqildi, holbuki
mahalliy daraxt yashil edi. Ya'ni gate **signal bermay qo'ydi**: har bir push
qizil bo'lgach, qizil rang ma'no tashlamaydi.

**2-qaror (2026-09-17) — olib tashlandi.** Foydalanuvchi qarori: bu ilova uchun
CI kerak emas. `.github/` butunlay o'chirildi.
`analysis_options.yaml` sarlavhasi endi workflow fayliga emas, **mahalliy
buyruqlarga** ishora qiladi.

**Buning natijasi — yozib qo'yilsin, chunki bu qarzni qaytaradi:**

| Nima endi tekshirilmaydi | Qayerda yozilgan |
|---|---|
| `analysis_options.yaml` `strict-casts` | faqat siz `dart analyze lib/ test/` yugurtirsangiz |
| i18n uch-bundle pariteti | debug boot guard + `/i18n-check` |
| `Result<T>` chegarasi | `test/architecture/result_boundary_test.dart` — faqat `flutter test` da |
| 923 testlik to'plam | faqat mahalliy `flutter test` |

**Gate endi mahalliy va qo'lda:**

```bash
dart analyze lib/ test/   # yoki: /check
flutter test
```

**Agar CI qachondir qaytarilsa:** `flutter-version:` ni **aniq pin qiling**
(`channel: stable` emas) va uni `pubspec.yaml` dagi Dart SDK bilan birga
yangilang. Pin qilinmagan runner — shu bandni o'ldirgan narsa.

**CI o'chirilishi fosh qilgan bug — TUZATILDI (2026-09-18).**
`cache_service.dart` dagi `return _directorySize(tmp);` da `await` yo'q edi,
ya'ni future `try` blokidan **tashqarida** yakunlanardi va tashqi
`catch (_) { return 0; }` o'sha yo'l uchun **o'lik kod** edi.

Ta'sir doirasi tor va buni aniq aytish kerak: `_directorySize` ning o'zi
ichkarida deyarli hamma narsani ushlaydi va qisman yig'indini qaytaradi.
Tashqariga chiqib keta oladigan yagona yo'l — uning **birinchi qatoridagi**
`dir.existsSync()` ning `FileSystemException` tashlashi (u o'zining `try`
blokidan tashqarida). Ya'ni bu "kesh hajmi doim yiqiladi" degani emas;
bu — nodir holatda 0 ga tushish o'rniga exception chiqishi.

Baribir tuzatishga arziydi, va bu bandning asosiy qiymati boshqa joyda:
**lint haq edi, va uni faqat yangiroq analizator ko'rgan.** Mahalliy SDK
3.44.9 da `unawaited_return_in_try_block` qoidasi yo'q edi; uni CI runner'i
(Flutter 3.47.3) topdi — o'sha CI qizil bo'lib turgani uchun hech kim
o'qimagan. Gate'ni e'tiborsiz qoldirish uni o'chirish bilan barobar.

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

### 🔄 T-07 · Service locator'ni UI'dan chiqarish — 7/9 QISM BAJARILDI (2026-08-07)

**Dastlabki muammo qisman noto'g'ri edi.** Roadmap "129 ta `sl<...>` — hammasi
buzuq" deb yozgan, lekin har birini o'qib chiqilgach aniqlandi: aksariyati
**loyihaning o'z to'g'ri naqshi** ekan:

| Tur | Misol | Holat |
|---|---|---|
| **A — `BlocProvider(create: (_) => Cubit(sl<Repo>()))`** | `checkout_screen.dart`, `tariff_screen.dart` | To'g'ri, `architecture.md`ga mos — tegilmadi |
| **B — umumiy singleton Cubit'ga murojaat** | `sl<NotificationsCubit>()`, `sl<UnpaidOrderCubit>().refresh()` | To'g'ri GetIt naqshi — tegilmadi |
| **C — widget bevosita repository/servis chaqiradi** | `catalog_product_detail_screen.dart`da xom `sl<WoodyApiClient>().post()` | **Haqiqiy anti-pattern** — bu tuzatildi |
| **D — infratuzilma** (`AnalyticsService`, `LocationFacade`, xom Hive `Box`) | | `AnalyticsService`ga o'xshash — tegilmadi |

Haqiqiy nishon ~129 emas, **~65 ta C-toifa joy**, foydalanuvchi bilan
tasdiqlangach shu qamrovda davom etildi.

**Tuzatish naqshi (barcha 7 tugagan toifada bir xil):** har bir widget'ning
repository/servis chaqiruvi **yo mavjud Cubit/Bloc'ga metod sifatida
ko'chirildi** (agar ekranning o'z cubit'i bo'lsa — `CheckoutCubit`,
`SellerWalletCubit`, `TariffUpgradeBloc`, `OrderDetailBloc`), **yo widget
konstruktor orqali bog'liqlikni qabul qiladigan** qilib o'zgartirildi (agar
cubit yo'q bo'lsa — masalan `ArTokensScreen`, `SellerSetsScreen`,
`CatalogProductDetailScreen`), sl<> chaqiruvi esa **faqat qurilish nuqtasida**
(router yoki ota-widget) qoldirildi — bu Turi-A bilan bir xil, to'g'ri joy.

**Tugagan toifalar (7/9):**

- [x] **checkout** — `refreshPaymentRemoteConfig()` `CheckoutCubit`ga
      ko'chirildi (`WoodyApiClient`/`Box` konstruktor orqali)
- [x] **orders** — `order_detail_screen.dart`: cancel reasons `OrderDetailBloc`
      metodi, `_PayNowBar` konstruktor orqali `PaymentRepository`/
      `PendingPaymentService?`
- [x] **wallet** — `SellerWalletCubit` kengaytirildi (`refreshPaymentMethods`,
      `paymentInstructions`, `uploadPaymentScreenshot`, `markPendingDeposit`);
      `ArTokenBuySection`/`ArTokensScreen`/`ArTokenPurchaseHistoryScreen`/
      `WalletHistoryScreen` — barchasi konstruktor orqali, butun chaqiruv
      zanjiri (`manual_payment_pending_screen`, `ar_section`, `profile_screen`)
      yangilandi
- [x] **products** — `SellerProductDetailScreen`/`SellerSetEditorScreen`/
      `SellerSetsScreen` konstruktor orqali (`seller_router.dart` +
      `seller_products_screen.dart` qurilish nuqtalari yangilandi)
- [x] **tariff** — `TariffUpgradeBloc` kengaytirildi (`refreshPaymentMethods`,
      `paymentInstructions`, `buyPlan`, `markPendingDeposit`)
- [x] **customer profile/settings** — `SettingsScreen`/`EditProfileScreen`
      konstruktor orqali; `account_dialogs.dart`dagi 2 ta top-level funksiya
      (`showSignOutDialog`, `confirmAccountDeletion`) parametr qabul qiladi
- [x] **catalog/search** — `CatalogProductDetailScreen` (5 ta bog'liqlik: api,
      attributesRepository, shopRepository, reviewsRepository,
      productDataSource, setRepository) + ichki `PremiumProductSellerCard`/
      `_ReviewsSection`/`_SimilarSection`; `search_screen.dart`/
      `search_filter_sheet.dart`/`review_composer_sheet.dart`/
      `ar_entry_points.dart` — barchasi; `customer/router.dart`ning 2 ta
      qurilish nuqtasi yangilandi

**Qoldi (2/9, keyingi sessiyada xuddi shu naqsh bilan):**

- [ ] **chat/support/notifications** — `chat_thread_screen.dart` (4),
      `support_chat_screen.dart` (2), `notification_simulator_screen.dart` (4),
      `notifications_screen.dart` (shared, 2), `notifications_screen.dart`
      (customer, 4), `notifications_screen.dart` (seller, 3)
- [ ] **seller misc** — `leaderboard_screen.dart` (2), `seller_contract_screen.dart`
      (4), `shop_settings/settings_form.dart` (1), `services_screen.dart` (1),
      `seller/onboarding/onboarding_screen.dart` (3)

**Tekshirish (7 tugagan toifa uchun) — har biri alohida tasdiqlangan:**
```bash
flutter analyze lib/customer/features/checkout/ lib/customer/features/orders/ \
  lib/seller/features/wallet/ lib/seller/features/products/ lib/seller/features/sets/ \
  lib/seller/features/tariff/ lib/customer/features/profile/ \
  lib/customer/features/product_list/ lib/customer/features/search/ \
  lib/customer/features/reviews/ lib/customer/router.dart lib/seller/seller_router.dart
# → No issues found

flutter test test/customer/features/checkout/ test/customer/features/orders/ \
  test/seller/features/wallet/ test/seller/features/products/ test/seller/features/tariff/ \
  test/customer/features/profile/ test/customer/features/product_list/ \
  test/customer/features/search/
# → barchasi yashil (checkout +10, wallet +8, orders +66 birgalikda, va h.k.)
```

**Yangilanma:** T-10 (`order`/`seller_product`/`seller_onboarding`
repolarini `Result<T>`ga ko'chirish) shu orada tugallandi — pastdagi T-10
bo'limiga qarang. `seller_wallet_repository` ataylab T-10'da kutib
turibdi — bu bo'lim (T-07) shu faylni tahrirlashni tugatib commit
qilgach, xuddi shu naqsh bilan bajariladi.

**Yangi qoida (davom ettirilsin):** widget ichida `sl<>` — faqat
`AnalyticsService`/`AppLocaleController`/`LocationFacade` kabi global,
holatsiz servislar va **qurilish nuqtalarida** (router builder, ota-widget
`Cubit(sl<Repo>())` konstruksiyasi). Repository/servis metodini **widget
ichidan** to'g'ridan-to'g'ri chaqirish — hech qachon.

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

### ✅ T-10 · `Result<T>` migratsiyasini yakunlash — **BAJARILDI (2026-09-18)**

**Muammo edi.** [CLAUDE.md](../../CLAUDE.md) va
[error-handling.md](../../.claude/rules/error-handling.md)
`order → seller_wallet → seller_product → seller_onboarding` migratsiyasini
va'da qilgan. Tekshirilganda **to'rttasida ham `Result<` = 0** chiqdi —
pul va buyurtma yo'lidagi eng xavfli repo'lar hali `throw`da edi.

**3/4 bajarildi: `order`, `seller_product`, `seller_onboarding`.
`seller_wallet` ataylab qoldirildi** — sababi quyida.

**Nega hammasi bir vaqtda bajarilmadi.** Ish boshlanganda
`seller_wallet_cubit.dart` (va uning 2 ta test fayli) boshqa (T-07)
sessiya tomonidan **hozir tahrirlanayotgan, hali commit qilinmagan**
holatda edi — constructor signature o'zgaryapti. Bitta faylni ikki
tomondan bir vaqtda tahrirlash to'qnashuv xavfini keltirib chiqarardi,
shuning uchun foydalanuvchi bilan kelishilgan holda `seller_wallet` T-07
tugab commit qilingunga qadar qoldirildi. Qolgan 3 tasining chaqiruvchilarida
to'qnashuv yo'q edi (`git status` bilan tasdiqlangan, har bir repoga
tegishdan oldin qayta tekshirildi).

**⚠️ Sessiya davomida kutilmagan holat:** ishlash jarayonida boshqa sessiya
(foydalanuvchi tomonidan) `f0b39a3` commit'ini push qildi — bu commit
o'zining asset-tozalash ishi bilan birga **mening tugallanmagan
`seller_onboarding`/`seller_product` ishimni ham** (hali to'liq
tekshirilmagan holatda) "chore: remove unused assets and update font
references" degan mos kelmaydigan xabar bilan qamrab oldi. Bu allaqachon
push qilingani uchun orqaga qaytarilmadi — buning o'rniga qolgan barcha
bo'shliqlar (pastda) topilib yopildi, to'liq qayta tekshirildi, va **T-10
uchun to'g'ri, alohida commit** qilib push qilindi.

**Qilingan ish.**

- [x] `order_repository` → `Result<T>` — 9 metod (`watch` Stream sifatida
      qoldi, Result o'lchoviga kirmaydi). Woody impl
      `woody_customer_repositories.dart` ichida (`WoodyOrderRepository`),
      `runCatching` + `apiErrorToFailure`. Chaqiruvchilar: `orders_bloc.dart`
      (`.timeout()` alohida `TimeoutException` sifatida ushlanadi, Result
      chegarasidan tashqarida), `order_detail_bloc.dart` (4 metod +
      `fetchCancelReasons()` — bu ikkinchisi `showCancelReasonSheet` umumiy
      widget'i throw-asosli qolgani uchun ataylab throw'ga qaytarib
      ko'priklanadi), `unpaid_order_cubit.dart` (`fetchAwaitingPaymentOrder` —
      **muhim nuance**: `Ok(null)` = "buyurtma yo'q" (banner tozalanadi),
      `Err` = "so'rov muvaffaqiyatsiz" (**oxirgi ma'lum banner saqlanadi** —
      original `catch(_){}` xulq-atvori aynan takrorlandi, network xatosi
      "to'landi" deb noto'g'ri o'qilmasin).
- [x] `seller_product_repository` → `Result<T>` — 11 metod (`watch` Stream
      qoldi — Woody impl'da haqiqatda `Stream.empty()`, hech qachon
      emit qilmaydi). **Muhim topilma:** `create`/`update`/`getById`/
      `uploadImage`/`deleteImage`/`reorderImages`/`setPrimaryImage`
      production'da **hech qayerda chaqirilmaydi** — add/edit-product oqimi
      alohida `AddProductRepository` orqali ishlaydi. Faqat `list`/`archive`/
      `restore`/`delete`/`submitForReview` haqiqiy chaqiruvchiga ega
      (`seller_products_bloc.dart`, `seller_set_editor_screen.dart`).
      Repo-lokal `_toFailure()` yozildi — `apiErrorToFailure`ning umumiy
      status-bucket matni o'rniga backend'ning **xom xabarini** saqlaydi
      (`ApiError.message ?? .code`), aynan `seller_products_bloc.dart`dagi
      eski `_displayError` nima qilgan bo'lsa — masalan "Bu mahsulot
      buyurtmalarda qatnashgan…" kabi 409-xabarlar generic matnga
      almashtirilib yubormasin.
- [x] `seller_onboarding_repository` → `Result<T>` — 5 metod, jumladan
      **sinxron** `loadDraft()` (`Result<OnboardingDraft>`, hali ham hech
      qachon muvaffaqiyatsiz bo'lmaydi — fayl bir xillik qoidasi uchun
      wrap qilindi) va `loadRemoteDraft()` (`Ok(null)` = "masofaviy qoralama
      yo'q" HAM "so'rov muvaffaqiyatsiz" — ikkalasi ham chaqiruvchida bir xil
      ishlanadi, xulq-atvor o'zgarmadi).
- [x] Har uch repo uchun mock/fake yangilandi
      (`test/fixtures/mocks/mock/mock_{order,seller_product,seller_onboarding}_repository.dart`)
      + 2 ta **oldindan mavjud, lekin dastlabki tekshiruvda o'tkazib
      yuborilgan** integration test (`woody_order_repository_test.dart`,
      `woody_seller_product_repository_test.dart`) va bloc testlar
      (`order_detail_bloc_test.dart`) `Result<T>`ga moslashtirildi.
- [x] `test/architecture/result_boundary_test.dart` yozildi — har bir
      `lib/shared/repositories/*.dart` interfeysi to'liq-Result yoki
      to'liq-throw ekanini statik tekshiradi. Ishga tushirilganda **2 ta
      qo'shimcha, T-10'ga aloqasi yo'q, oldindan mavjud aralash fayl**
      topildi: `seller_order_repository.dart` va `shop_repository.dart` —
      ikkalasi ham **ataylab** shunday (ma'lumot-o'qish metodlari
      xatoda bo'sh ro'yxatga qaytadi, `Err` emas — fayl izohlarida
      hujjatlashtirilgan, oldingi "B.1" bosqichidan). Allowlist shu ikkitasi
      + `seller_wallet_repository.dart`ni (T-10 davom etmoqda) sabab bilan
      birga saqlaydi.
- [x] `flutter analyze lib/ test/` — toza (1 oldindan bor baseline issue).
      `flutter test` — **859/859 yashil** (guard test ikkalasi ham kiritilgan
      holda).

**✅ Yakunlandi (2026-09-18): `seller_wallet_repository` → `Result<T>`** — 10 metod
(`Stream` yo'q). Naqsh: ifoda-tanali `runCatching(..., onError: (e, _) =>
apiErrorToFailure(e))` — **umumiy ko'prik**, repo-lokal `_toFailure` emas
(cubit allaqachon `apiErrorMessage(e)` ko'rsatardi, ya'ni xatti-harakat
saqlanadi). Chaqiruvchilar: `seller_wallet_cubit.dart` (5 ta),
`wallet_history_screen.dart`, `manual_payment_pending_screen.dart` (4 ta).

**Uchta nozik qaror — yozib qo'yiladi:**

1. **`wallet_history_screen._load()` dan `Future.wait` olib tashlandi.** Uch xil
   `Result<T>` ustidan `Future.wait` → `List<Result<Object>>` bo'ladi va `as`
   cast'lar kompilyatsiya qilinmaydi; ustiga `Result` hech qachon reject
   qilmagani uchun `catch` bloki o'lik kodga aylanardi. O'rniga record
   (`(f1, f2, f3)`) bilan parallel boshlanadi, keyin har biri alohida `await`
   qilinadi va uchlik `switch` bilan tekshiriladi (`tariff_bloc.dart:157-166`
   naqshi). **Xatoda hammasi yiqiladi** — hozirgi xatti-harakat; qisman render
   "yechib olishlaringiz yo'q" degan yolg'onni ko'rsatardi.
2. **`reconcileDeposit()` da `Err` "hali kutilmoqda" bo'lib qoladi.**
   `.valueOrNull` bilan ataylab yig'iladi, izoh bilan (bu qoida taqiqlagan
   `.valueOrNull!` emas). Repodagi `?? 'pending'` default'i `Ok` tarmog'ida
   qoladi — shunda 200-lekin-bo'sh javob tarmoq uzilishidan ajralib turadi.
   Yangi test (`depositStatus: 200-bo'sh vs 500`) aynan shuni qulflaydi.
3. **Ikkita cancel — migratsiya fosh qilgan HAQIQIY BUG.** Ilgari
   `cancelTopUp`/`cancelDeposit` xato bersa exception `runZonedGuarded` ga
   ketardi: ekran ochiq qolardi va foydalanuvchiga **hech narsa
   ko'rsatilmasdi**. `Result<void>` buni majburan tuzatdi —
   `fold(ok: pop, err: snackbar(failure.message))`. Yangi i18n kalit kerak
   bo'lmadi: `failure.message` allaqachon lokalizatsiyalangan.

**Xavf — yozib qo'yiladi:** `appLog.handle` → `appLog.warning` ga o'tish
Crashlytics non-fatal'larini yo'qotadi. Lekin `appLog.error` yomonroq bo'lardi:
`isExpectedTransientError` `Failure` turini tanimaydi, ya'ni **har oflayn
ochilish** non-fatal bo'lib ketardi. `warning` olindi; keyingi ish sifatida
"transient filter'ga `Failure` qo'shish" yozib qo'yiladi.

**Testlar.** Mavjud 2 faylning stub'lari `.thenThrow` → `Err(...)` ga
o'tkazildi (bu **semantik** o'zgarish — qoldirilsa migratsiya jimgina
buzilardi). Yangi `test/shared/repositories/woody_seller_wallet_repository_test.dart`
— **11 ta case**, jumladan `requestWithdrawal` karta raqamini tozalashi (hech
qachon test qilinmagan, pul yo'naltiruvchi ma'lumot) va `depositStatus` ning
200-bo'sh vs 500 farqi. **In-memory mock qo'shilmadi** — hech kim iste'mol
qilmaydi; qo'shilsa o'sha zahoti o'lik kod bo'lardi.

**Allowlist ikkala joydan tozalandi** (map + `expect(_allowlist.keys, {...})`).
Tuzoq: interfeys to'liq-`Result` bo'lgach guard'ning **o'zi** eskirgan yozuvni
sezmaydi (hech narsa aralashmaydi), shuning uchun faqat qadalgan kalitlar
to'plami yarim-o'chirishni ushlaydi — test faylida izoh sifatida yozib qo'yildi.

**`Result` chegarasida endi migratsiya qarzi yo'q.** Allowlist'da qolgan ikki
fayl (`seller_order_repository.dart`, `shop_repository.dart`) — **ataylab**
shunday, qarz emas.

> **2026-09-17 yangilanishi:** to'sib turgan sabab **yo'qoldi** (T-07 commit
> qilindi, ish daraxti toza). **2026-09-18:** ish bajarildi — yuqoriga qarang.

**Naqsh:** `runCatching(...)` + `apiErrorToFailure`
([api_error_messages.dart](../../lib/core/network/api_error_messages.dart)) —
`payment` va `checkout` da allaqachon qilingan, o'shani takrorlang
(`seller_product` uchun repo-lokal variant — yuqorida sababi bilan).

**Tekshirish natijasi:**
```bash
for f in order seller_wallet seller_product seller_onboarding; do
  echo -n "$f: "; grep -c "Result<" lib/shared/repositories/${f}_repository.dart
done
# order: 9, seller_wallet: 11, seller_product: 14, seller_onboarding: 6

flutter test test/architecture/result_boundary_test.dart   # 2/2 yashil
```

---

## Sprint 3 — Hujjat va repo gigienasi

### ✅ T-11 · CLAUDE.md'ga AR / 3D bo'limini yozish — BAJARILDI (2026-09-17)

**Muammo edi.** CLAUDE.md'da **AR / 3D / Meshy haqida 0 ta eslatma** — ~5000
qatorlik, **native** bog'liqlikka ega (ya'ni Shorebird patch'ni bloklaydigan)
va token iqtisodiyoti bilan bog'langan feature brain'da umuman yo'q edi.

**Qilingan ish.** CLAUDE.md'ga to'rtta yangi bo'lim qo'shildi:

- `### AR / 3D — per-part models` — `Product.arParts` modeli, ikki JSON shakli,
  viewer routing (`BuyerArViewerScreen` / `SetArViewerScreen` / 2D fallback),
  `ArSupport` capability probe, per-part monetizatsiya, va **"native dep =
  hech qachon patch emas"** invariant'i. To'liq qo'llanma
  [`doc/guides/ar.md`](../guides/ar.md) da — CLAUDE.md unga ishora qiladi, nusxa
  ko'chirmaydi.
- `### Support chat` — `/support/*` endpoint'lari, ovozli xabar (`record` +
  `just_audio`), va per-order chat bilan **aralashtirmaslik** ogohlantirishi.
- `### Broadcasts & tutorial` — broadcasts hozircha **faqat placeholder**
  ekani (tugallangan sirt deb yozilmasin), va `safeStartShowCase(...)`
  invariant'i.
- `### Payments` + `### Connectivity & offline UX` — T-11 ro'yxatida yo'q edi,
  lekin shu bo'shliqning o'zi: ikkalasi ham jonli, nozik (OS-kill'dan omon
  qoladigan `PendingPaymentStore`, `unknown != paid`, captive-portal probe)
  va brain'da yo'q edi.

`## Recent feature work` bo'limi ham qayta yozildi — endi "Autumn 2026" /
"Spring / Summer 2026" deb ajratilgan va joriy versiya holati yozib qo'yilgan.

**Tekshirish:**
```bash
grep -c "AR / 3D\|Support chat\|Connectivity & offline" CLAUDE.md   # ≥ 3
```

---

### 🔄 T-12 · Hujjat drift'ini tozalash — QISMAN BAJARILDI (2026-09-17)

**Bajarildi (2026-09-17):**

- [x] [analysis_options.yaml](../../analysis_options.yaml) — CI izohi endi
      mavjud bo'lmagan workflow fayliga emas, mahalliy buyruqlarga ishora
      qiladi (T-03 bilan birga).
- [x] **README versiyasi.** Dastlabki taklif "versiyani README'dan butunlay
      olib tashlash" edi. **Boshqacha qilindi:** versiya qoldirildi, lekin endi
      *ikkita* raqam yoziladi — `pubspec` versiyasi **va** oxirgi haqiqatan
      chiqqan reliz. Sabab: aynan shu ikkisining farqi (`1.0.40+40` yozilgan,
      `1.0.39+39` chiqqan) muhim signal edi va uni yashirish o'rniga ko'rsatish
      foydaliroq. README §7 da relizsiz qolgan tuzatma haqida ogohlantirish bor.
- [x] **`doc/backlog.md`** — `doc/planning/backlog.md` ning **bayt-bayt nusxasi**
      edi (ikkita haqiqat manbai). Endi `doc/roadmap.md` kabi bir qatorlik
      stub'ga aylantirildi.
- [x] **Eskirgan raqamlar** README / CLAUDE.md / `doc/guides/release-shorebird.md` da
      yangilandi: test soni (122 fayl / 767 case → **140 / 912**, 923 o'tadi),
      Shorebird ledger'idagi oxirgi reliz (`1.0.26` va `1.0.36` → **`1.0.39+39`**),
      iOS Firebase pin (11.15.0 → **12.17.0**).
- [x] **`release_checklist.md` dagi qarama-qarshilik** — hujjat
      `NSPrivacyTrackingDomains` "ataylab bo'sh" deyardi, holbuki kod
      `ep1.facebook.com` e'lon qiladi (Apple ITMS-91064 rad javobidan keyin).
      Tuzatildi.

**Qoldi:**

- [x] `docs/` (6 ta fayl) va `doc/` — **birlashtirildi (2026-09-18).**
      `docs/` → **`doc/guides/`** (`doc/` ga to'g'ridan-to'g'ri emas: `doc/`
      da allaqachon `architecture/` **katalogi** bor, `docs/architecture.md`
      esa uning yoniga fayl bo'lib tushar edi — chalkash). 16 ta kiruvchi
      havola, ko'chgan fayllar ichidagi 11 ta `../` havola va
      `tools/shorebird.sh` dagi `docs/*` glob'i (patch-xavfsizlik tasnifi —
      `doc/*` uni allaqachon qamraydi, shuning uchun olib tashlandi)
      yangilandi. Endi hujjat uyi bitta.
- [x] **Ikkita o'lik havola** tuzatildi: `notification_handler.dart:12` va
      `notification_simulator_screen.dart:14` hech qachon mavjud bo'lmagan
      `docs/05-notifications-deep-linking.md` ga ishora qilardi — endi
      kodning o'ziga ishora qiladi.
- [x] `WOODY_PROJECT_CONTEXT.md` — **o'chirildi.** Bitta qatorlik redirect
      stub edi; README unga havola qilmaydi (roadmap'ning "README ikkalasiga
      ham havola qiladi" da'vosi eskirgan edi). `woody_mobile_tz.md`
      **saqlanadi** — unga README ham, `doc/TZ.md` ham havola qiladi.
- [x] `lib/core/deep_links/` + `lib/core/deeplink/` — **birlashtirildi**
      (`deep_links/` ga). Roadmap "6 import" deb yozgan edi, aslida **10**
      (`customer_app.dart` ikkalasini ham import qilardi).
- [x] `doc/TZ.md` — **v1.6 (2026-09-18) da to'liq yarashtirildi.** Backend va
      admin bo'limlari ham jonli kodga qarab qayta auditdan o'tkazildi: deploy
      tavsifi (Docker Compose), router soni (32 → 42), Alembic head
      (`0027` → `0102`), AR ma'lumot modeli (`product_ar_parts`),
      `/seller/tariff/buy`, moderator scope'lari (9 ta), 14 ta hujjatlanmagan
      jadval va 10 ta router qo'shildi.

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

**Muammo.** `.git` = **158 MB** (2026-08-07 da 150 MB edi — o'syapti).

**2026-09-17 da qayta o'lchandi — root'dagi dublikatlar tozalangan, lekin
`doc/` dagilar qolgan.** Hozir tracked:

```
doc/Woody_Investor_Deck.pptx       3.3 MB
doc/Woody_Pitch_Deck.pptx          1.7 MB
doc/Woody_Pitch_Deck.pdf           652 KB
doc/Woody_Pitch_Deck.html
woody_frond.pen                    132 KB   (root)
doc/woody_frond.pen                4 KB
doc/admin_panel.pen · design/mobile_mockup.pen
```

`.pen` (Pencil design) fayllari alohida og'riq: bitta commit'da
`woody_frond.pen` **3 489 qatorlik diff** keltirgan, yana bittasida 2 719 —
kod tarixini ko'rish qiyinlashadi. Jami **277 ta tracked `.md`** fayl ham bor
(ko'pi `.claude/` va `.agents/` tooling boilerplate'i).

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

### 🔄 T-15 · Major yangilanishlar (bosqichma-bosqich) — 3/4 TO'LQIN (2026-09-18)

**Muammo edi.** Sezilarli orqada qolish — har bir kechikish keyingi migratsiyani
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

- [x] **1-to'lqin — patch/minor, xavfsiz:** `dio` (5.10→5.11), `equatable`
      (2.0.8→2.1.0), `lottie` (3.4→3.5.1), `gal` (2.3.2→2.3.3), `app_badge_plus`
      (1.3.1→1.3.3), `flutter_cache_manager` (3.4.1→3.4.2), `flutter_image_compress`
      (2.4.0→2.5.1), `facebook_app_events` (0.30.2→0.30.5), `yandex_mapkit`
      (4.2.1→4.3.0), `webview_flutter` (4.14.0→4.14.1) — hammasi mavjud caret
      constraint doirasida edi, `pubspec.yaml`ga tegilmadi, faqat
      `flutter pub upgrade <paketlar>` bilan lock yangilandi.
- [x] **2-to'lqin — Firebase to'plami** — `firebase_core` `^3.6.0→^4.13.0`,
      `firebase_messaging` `^15.1.3→^16.5.0`, `firebase_crashlytics`
      `^4.1.5→^5.2.7`, `firebase_analytics` `^11.3.5→^12.4.6` (`pubspec.yaml`
      to'g'ridan-to'g'ri tahrirlandi, hammasi birga). Changelog tekshiruvi
      (pub.dev): asosiy breaking change'lar Dart API emas, native SDK minimum
      talablari — iOS SDK 12.0.0 / iOS deployment target 13+, Android SDK 34 /
      `minSdk` 21-23. Loyiha allaqachon iOS `platform :ios, '15.0'` va
      Android `minSdk 26` bilan ikkalasidan ham yuqorida — moslashtirish shart
      bo'lmadi. iOS `Podfile.lock` Firebase pinini moslashtirish uchun
      `pod update` ishlatildi (`Firebase/Messaging` versiya to'qnashuvi
      static `pod install`da chiqdi — kutilgan, chunki lock hali eski
      11.15.0'da qulflangan edi); natijada Firebase **11.15.0 → 12.17.0**
      (`YandexMapsMobile` ham shu jarayonda **4.22.0-lite → 4.39.1-lite**ga
      ko'tarildi — 1-to'lqindagi `yandex_mapkit` dart-tomon bumpi buni talab
      qilgan edi). README (4 joy) va `doc/guides/release-shorebird.md`dagi eski
      "Firebase 11.15.0" pin-eslatmalari yangi versiyaga yangilandi.
      **Tasdiqlash:** `flutter analyze lib/ test/` toza (1 oldindan bor
      baseline issue, o'zgarishsiz); `flutter test` — **859/859 yashil**;
      **haqiqiy native build'lar** ham ishga tushirildi (Dart test/analyze
      native pod/gradle darajasini tekshirmaydi) —
      `flutter build ios --no-codesign --dart-define-from-file=env/prod.json`
      va `flutter build apk --release --dart-define-from-file=env/prod.json`
      ikkalasi ham **muvaffaqiyatli** (`Runner.app` 115.8 MB,
      `app-release.apk` 185.4 MB).
- [ ] **3-to'lqin — `go_router` 14 → 18.** Eng katta xavf: ikkita router
      (`customer/router.dart` + `seller_router.dart` `StatefulShellRoute` bilan).
      `test/customer/navigation/` testlari bu yerda qalqon bo'ladi
      (9 ta back-navigation testi — cold deep-link, tab fallback, share link).
- [x] **3a-to'lqin (2026-09-18) — past xavfli majorlar + zanjirli bog'liqlik.**
      `get_it` 8→**9.2.1**, `shimmer` 3→**4.0.0**, `cached_network_image` 3→**4.0.0**,
      `package_info_plus` 8→**10.2.1**, `device_info_plus` 11→**13.2.0**,
      `share_plus` 12→**13.3.0**, `flutter_secure_storage` 9→**10.3.4**.

      **Zanjir majburlagan.** `package_info_plus` 10 `win32 ^6` talab qiladi,
      `share_plus` 12 esa `win32 ^5` — ya'ni `share_plus` ni ham ko'tarish
      shart bo'ldi; `share_plus` 13 o'z navbatida `flutter_secure_storage` 10+
      ni talab qildi. Uchtasi **birga** ko'tarilishi kerak, alohida emas.
      `share_plus` allaqachon yangi API'da edi (`SharePlus.instance.share(ShareParams(...))`),
      shuning uchun kod o'zgarmadi.

- [ ] **`shimmer` 4 va `cached_network_image` 4 — BLOKLANGAN** (sinab ko'rilib,
      qaytarildi). Ikkalasi `^3.x` da qoldi. Sabab quyida.

#### ⚠️ `material_ui` tuzog'i — `pub outdated` ham, `analyze` ham buni ko'rmaydi

`shimmer` **4.0.0** va `cached_network_image` **4.0.0** ikkalasi ham
`package:flutter/material.dart` o'rniga yangi **`material_ui`** paketiga
o'tgan (Wasm mosligi uchun). `material_ui 1.3.0` esa `meta` paketining
`@awaitNotRequired` annotatsiyasini ishlatadi.

Bizning toolchain: Flutter **3.44.9**, Dart **3.12.2** — `material_ui` ning
e'lon qilingan talablarini (`sdk: ^3.12.0`, `flutter: >=3.44.0`) **qanoatlantiradi**.
Lekin Flutter 3.44.9 `meta` ni **1.18.0** da pin qiladi, va `awaitNotRequired`
o'sha versiyada yo'q. Natija — test kompilyatsiyasida:

```
material_ui-1.3.0/lib/src/bottom_sheet.dart:1304:2:
  Error: Undefined name 'awaitNotRequired'.
```

**Bu nima uchun muhim — uchta gate ham jim qoldi:**

| Tekshiruv | Natija |
|---|---|
| `flutter pub get` | ✅ muvaffaqiyatli hal qildi |
| `flutter pub outdated` | ✅ "Resolvable" deb ko'rsatdi |
| `dart analyze lib/ test/` | ✅ 1 info (baseline) — **o'zgarishsiz** |
| `flutter test` | ❌ **16 ta test fayli yuklanmadi** |

Analizator faqat `lib/` va `test/` manbalarini ko'radi, pub-cache'dagi paket
kodini emas. Xatoni **faqat** `flutter test` tutdi. Ya'ni paket bump'idan
keyin `analyze` yetarli emas — **to'liq `flutter test` majburiy**.

**Blokdan chiqish sharti:** Flutter'ning o'zi yangiroq `meta` pin qiladigan
versiyaga ko'tarilishi. Shundan keyin ikkalasini `^4` ga qaytaring.

- [ ] **3b-to'lqin (2026-09-18) — connectivity juftligi.**
      `connectivity_plus` 6.1.5→**7.3.1** va
      `internet_connection_checker_plus` 2.7.2→**3.1.2**.
      Ikkalasi **birga** ko'tarildi: ular `ConnectivityService` ning ikki
      yarmi, birini yolg'iz ko'tarish probe seam'ini buzadi.

      **Ikkita yashirin talab chiqdi — ikkalasini ham `flutter test` tutmaydi:**

      1. **ICCP v3 hardware trigger'ni yo'qotdi.** v3 `connectivity_plus`
         bog'liqligidan voz kechib, sof Dart paketiga aylandi — ya'ni radio
         o'zgarganda darhol qayta tekshirmaydi, faqat keyingi poll tick'ida
         (20 soniyagacha) sezadi. Migratsiya qo'llanmasi bo'yicha
         `triggerStream: Connectivity().onConnectivityChanged` qo'shildi.
         (`RealConnectivityService` o'zi ham shu oqimga obuna — bu probe'ning
         **o'z** status stream'ini v2 dagidek tezkor saqlaydi.)
      2. **`connectivity_plus` 7.0.0 native build talablari qo'ydi:**
         AGP **≥ 8.12.1**, Gradle wrapper ≥ 8.13, Kotlin ≥ 2.2.0.
         Bizda Gradle **8.14** ✅ va Kotlin **2.2.20** ✅ mos edi, lekin
         AGP **8.11.1** ❌ — past. `android/settings.gradle.kts` da
         AGP **8.12.3** ga ko'tarildi va haqiqiy `flutter build apk` bilan
         tasdiqlandi. Dart testlari Gradle darajasini umuman ko'rmaydi.

      Buning evaziga olingan narsa bekorga emas: 7.x ikkita **crash
      tuzatmasini** olib keladi — iOS `NWPathMonitor` race condition
      (serial queue) va Android broadcast-receiver flag'i.

- [x] **3c-to'lqin (2026-09-18) — qolgan majorlar.**
      `fl_chart` 0.69.2→**1.2.0**, `flutter_local_notifications` 18.0.1→**22.3.1**,
      `camera` 0.11.4→**0.12.1**, `just_audio` 0.9.46→**0.10.6**,
      `record` 5.2.1→**6.2.1**, `smooth_page_indicator` 1.2.1→**3.0.0**.

      **`flutter_local_notifications` 22 pozitsion argumentlarni nomlanganga
      o'tkazgan** — yagona haqiqiy kod migratsiyasi (16 analizator xatosi):

      | v18 | v22 |
      |---|---|
      | `cancel(id, tag: …)` | `cancel(id: …, tag: …)` |
      | `initialize(settings, onDidReceive…)` | `initialize(settings: …, onDidReceive…)` |
      | `show(id, title, body, details, payload:)` | `show(id: …, title: …, body: …, notificationDetails: …, payload: …)` |

      Tuzatilgan joylar: `push_service.dart` (5 ta chaqiruv) va ikkita test
      fayli (`push_service_chat_dismiss_test.dart`,
      `push_service_token_refresh_test.dart` — mocktail `any()` lari
      `any(named: …)` ga o'tdi; `registerFallbackValue(const InitializationSettings())`
      allaqachon bor edi).

- [ ] **`showcaseview` 5 — QAYTARILDI, ataylab.** `^4.0.1` da qoldi.
      v5 `ShowCaseWidget` ni `ShowcaseView.register()` ga, `ShowCaseWidget.of(context)`
      ni `ShowcaseView.get()` ga deprecate qiladi (v6 da olib tashlanadi).
      Bu **nom almashtirish emas** — widget-daraxtdagi provider'dan global
      registratsiyaga o'tish, ya'ni haqiqiy refactor. Paket ko'tarish
      batch'ida qilinadigan ish emas; alohida qaror sifatida qoldirildi.
      Qoldirilmaganda analizator baseline'i 1 dan **6** ga chiqardi — CI yo'q
      paytda bu signalni zaiflashtiradi.

- [x] **4-to'lqin (2026-09-18) — `go_router` 14.8.1 → 17.5.0.**
      Roadmap'da "eng katta xavf" deb belgilangan band. Amalda **bitta ham
      kod o'zgarishi kerak bo'lmadi** — analizator 0 xato berdi, chunki ikkala
      router ham allaqachon zamonaviy API'da edi (`state.uri`,
      `state.pathParameters`, `context.go/push/pop`, `shell.goBranch`).
      Eskirgan `state.location` repo'da umuman yo'q edi.

      **18 emas, 17.5.** `go_router` **18.0.0** "Migrates to material_ui and
      cupertino_ui" — ya'ni yuqoridagi `material_ui` blokiga tushadi.
      17.5.0 — Flutter 3.44.9 da ishlaydigan eng yuqori versiya.

      **Uchta major orasidagi breaking changelar va bizga ta'siri:**

      | Versiya | Breaking change | Bizga ta'siri |
      |---|---|---|
      | **15.0.0** | URL'lar endi **katta-kichik harfga sezgir** (`caseSensitive: true` default) | Marshrutlarimiz to'liq kichik harfda; ulashish havolalari ham (`/product/:id`, `/shop/:id`) kichik harfda generatsiya qilinadi. Ta'sir yo'q — lekin tashqi manbadan `/Product/123` kelsa endi 404 |
      | **16.0.0** | `GoRouteData` (type-safe routes) o'zgarishlari, `go_router_builder >= 3.0.0` talab qiladi | **Tegishli emas** — `go_router_builder` ishlatilmaydi |
      | **17.0.0** | `ShellRoute` navigatsiyasi endi **root observer'larni default xabardor qiladi** (`notifyRootObserver`) | ⚠️ Haqiqiy xatti-harakat o'zgarishi — pastda |

#### ⚠️ 17.0.0 — seller tab almashinuvi endi analitikaga tushadi

Ikkala routerga ham `FirebaseAnalyticsObserver` ulangan
(`customer/router.dart`, `seller_router.dart`). Seller rejimi
`StatefulShellRoute.indexedStack` bilan 5 ta tab'dan iborat.

**Ilgari:** tab almashinuvi root observer'ga yetib bormasdi → GA4 da seller
tab navigatsiyasi **ko'rinmasdi**.
**Endi:** har tab almashinuvi `screen_view` hodisasini yozadi.

**Qaror: eski xatti-harakat saqlandi.** `seller_router.dart` da
`StatefulShellRoute.indexedStack(notifyRootObserver: false, …)` qo'yildi.

Sabab: paket bump'i **analitika ma'lumotlarining shaklini o'zgartirmasligi**
kerak. Aks holda admin `/app-usage` dagi `screen_view` qatori aynan shu
relizda sakrardi — va bu sakrash foydalanuvchi xatti-harakatiga umuman
aloqador bo'lmasdi, ya'ni releaslar orasidagi taqqoslash buzilardi.
Seller tab navigatsiyasini GA4 ga qo'shish — bu **mahsulot qarori**, paket
ko'tarishning yon ta'siri emas. Kerak bo'lsa, o'sha bir qatorni olib
tashlash kifoya, lekin ongli ravishda va uzilishni kutgan holda.

`setCurrentScreen()` hech qayerda chaqirilmaydi, shuning uchun **ikki marta
hisoblash xavfi yo'q** (tekshirildi).

#### Yakuniy holat (2026-09-18) — nima qoldi va nega

`flutter pub outdated` dagi qolgan 13 ta direct dependency, sabab bo'yicha:

| Sabab | Paketlar | Qachon ochiladi |
|---|---|---|
| **`material_ui` bloki** | `go_router` 18, `shimmer` 4, `cached_network_image` 4 | Flutter yangiroq `meta` pin qilgach |
| **Ma'lumot yo'qolishi xavfi** | `flutter_secure_storage` 11 | v10 bilan bitta reliz store'ga chiqqach |
| **Refactor talab qiladi** | `showcaseview` 5 | alohida qaror (`ShowcaseView.register()`) |
| **SDK'da resolvable emas** | `record` 7, `permission_handler` 13, `equatable` 3, `vector_math` 2.4, `intl` 0.20.3, `clock` 1.1.3 | Flutter/Dart ko'tarilgach |
| **Constraint ichida, arzimas** | `geolocator` 14.0.3, `lottie` 3.6.1 | `flutter pub upgrade` — istalgan vaqtda |

Ya'ni 13 tadan **hech biri "unutilgan" emas** — har birining yozilgan sababi bor.
Boshlanishida 15 ta major orqada edi; endi haqiqiy, ochiq major qarz **yo'q**.

#### Tekshiruv protokoli — paket ko'tarishda uchta gate

Bu sessiyada uch marta shunday bo'ldi: `pub get` ✅, `pub outdated` ✅,
`dart analyze` ✅ — lekin paket **baribir ishlamadi**. Shuning uchun:

| Gate | Nimani tutadi | Misol |
|---|---|---|
| `dart analyze lib/ test/` | o'z kodimizdagi API o'zgarishi | `flutter_local_notifications` 22 nomlangan argumentlari |
| `flutter test` | paket ichidagi kompilyatsiya xatosi, xatti-harakat regressiyasi | `material_ui` / `@awaitNotRequired` |
| `flutter build apk` | Gradle / AGP / native talablar | `connectivity_plus` 7 → AGP ≥ 8.12.1 |
| **CHANGELOG o'qish** | **ma'lumot migratsiyasi** — buni hech qaysi gate tutmaydi | `flutter_secure_storage` 9→11 token'larni o'chiradi |

To'rtinchisi eng muhimi: uni **faqat odam** tutadi.

#### ⚠️ `flutter_secure_storage`: 9 → 11 sakrash MUMKIN EMAS (sessiya yo'qoladi)

`flutter pub outdated` `11.2.0` ni "resolvable" deb ko'rsatadi va `pub get`
muammosiz o'tadi — lekin bu **jimgina barcha foydalanuvchini tizimdan
chiqarib yuboradi**. Paket CHANGELOG'i (v11.0.0) buni ochiq aytadi:

> *"Any data saved using deprecated algorithms or features will be unusable
> after this upgrade. **If you used a version prior to v10, upgrade to v10
> first so existing data is migrated.**"*

Mexanizm: v9 yozgan ma'lumotda algoritm markerlari yo'q. v11 ularni
`legacyDataUnreadable` deb belgilaydi, `AndroidOptions.resetOnError` esa
**default `true`** — ya'ni o'qib bo'lmaydigan yozuvlar **o'chiriladi**.
Bizda o'sha yozuvlar `TokenStore` dagi access/refresh JWT juftligi.

**Qabul qilingan yechim:** `^10.3.1` ga pin qilindi. v10 v9 ma'lumotini
avtomatik migratsiya qiladi (`migrateOnAlgorithmChange` default `true`).

**Kod o'zgarishi:** yangi
[`lib/core/storage/secure_storage_options.dart`](../../lib/core/storage/secure_storage_options.dart)
— yagona `woodySecureStorage` konstantasi `AndroidOptions(migrateWithBackup: true)`
bilan. Migratsiya bir martalik va o'rtasida crash bo'lsa yozuv yo'qoladi;
backup uni qayta tiklanadigan qiladi. Uchala chaqiruv joyi
(`TokenStore`, `SecureStorage`, `resetSecureStorageOnFreshInstall`) shu
konstantadan foydalanadi.

**v11 uchun shart:** v10 bilan **kamida bitta reliz store'ga chiqishi** va
foydalanuvchilar uni o'rnatishi kerak. Shundan keyingina `^11` ga o'tiladi.
v11 yana `minSdk` 24 (bizda 26 ✅) va `compileSdk` **37** talab qiladi —
o'shanda Android tomonini ham tekshiring.

**Qoldi:** 3- va 4-to'lqin — foydalanuvchi bilan kelishilgan holda
ochilmadi (yuqori xavf, alohida sessiyada qilinsin).

> **⚠️ 2026-09-17 qayta o'lchov — tafovut kattalashdi.** Yuqoridagi jadval
> 2026-08-07 holati. Bir oy ichida `go_router` **17.4 → 18.0.1** ga chiqdi,
> ya'ni 3-to'lqin endi **4 major** sakrash (3 emas). `flutter pub outdated`
> bugungi holati:
>
> | Paket | Joriy | Resolvable / Latest | Sakrash |
> |---|---|---|---|
> | `go_router` | 14.8.1 | **18.0.1** | 4 major |
> | `flutter_local_notifications` | 18.0.1 | **22.3.1** | 4 major |
> | `flutter_secure_storage` | 9.2.4 | **11.2.0** | 2 major |
> | `package_info_plus` | 8.3.1 | **10.2.1** | 2 major |
> | `device_info_plus` | 11.5.0 | **13.2.0** | 2 major |
> | `record` | 5.2.1 | **7.1.1** | 2 major |
> | `camera` | 0.11.4 | 0.12.1 | minor |
> | `get_it` | 8.3.0 | **9.2.1** | 1 major |
> | `fl_chart` | 0.69.2 | **1.2.0** | 1 major |
> | `connectivity_plus` | 6.1.5 | **7.3.1** | 1 major |
> | `share_plus` | 12.0.2 | **13.3.0** | 1 major |
> | `cached_network_image` | 3.4.1 | **4.0.0** | 1 major |
> | `internet_connection_checker_plus` | 2.7.2 | **3.1.2** | 1 major |
> | `shimmer` | 3.0.0 | **4.0.0** | 1 major |
> | `showcaseview` | 4.0.1 | **5.1.0** | 1 major |
> | `smooth_page_indicator` | 1.2.1 | **3.0.0** | 2 major |
> | `just_audio` | 0.9.46 | 0.10.6 | minor |
>
> Firebase to'plami (2-to'lqindan keyin) faqat **minor** orqada:
> `firebase_core` 4.13.0→4.15.0, `messaging` 16.5.0→16.7.0,
> `crashlytics` 5.2.7→5.4.0, `analytics` 12.4.6→12.6.0 — xavfsiz.
>
> **Diqqat:** `connectivity_plus` va `internet_connection_checker_plus`
> ikkalasi ham `ConnectivityService`ning yadrosi (2026-09-10 da qayta
> yozilgan) — ularni **birga** ko'taring va
> `test/core/connectivity/connectivity_service_test.dart` ni qalqon qiling.
> Bir paket majorini yolg'iz ko'tarish probe seam'ini buzadi.

**Har to'lqindan keyin:** `flutter test` + qurilmada qo'lda smoke test.
**Har to'lqin = alohida commit** (rollback oson bo'lsin) — bu sessiyada hali
commit qilinmadi, foydalanuvchi tasdiqlagach qilinadi.

**Tekshirish natijasi:**
```bash
flutter analyze lib/ test/          # 1 issue (baseline, o'zgarishsiz)
flutter test --reporter=compact | tail -1   # All tests passed! (859)
flutter build ios --no-codesign --dart-define-from-file=env/prod.json   # ✓
flutter build apk --release --dart-define-from-file=env/prod.json       # ✓
grep "Firebase/Core (" ios/Podfile.lock   # 12.17.0
```

---

## Sprint 5 — Sifat va kelajakdagi og'riq

### ⬜ T-16 · God-file'larni bo'lish

**2026-09-17 holati: 36 fayl > 700 qator** (2026-08-07 da 34 edi — ⚠️ band
ochiq turgani uchun o'sib boryapti). Eng kattalari:

| Fayl | Qator (08-07 → 09-17) |
|---|---|
| [seller/features/wallet/screens/wallet_screen.dart](../../lib/seller/features/wallet/screens/wallet_screen.dart) | 1955 → **1932** |
| [core/i18n/translations/seller_translations.dart](../../lib/core/i18n/translations/seller_translations.dart) | 1722 → **1719** |
| [customer/features/product_list/screens/catalog_product_detail_screen.dart](../../lib/customer/features/product_list/screens/catalog_product_detail_screen.dart) | 1367 → **1393** |
| [customer/features/checkout/screens/checkout_screen.dart](../../lib/customer/features/checkout/screens/checkout_screen.dart) | 1374 → **1379** |
| [customer/features/home/screens/home_screen.dart](../../lib/customer/features/home/screens/home_screen.dart) | 1357 → **1354** |
| [seller/features/tariff/screens/tariff_screen.dart](../../lib/seller/features/tariff/screens/tariff_screen.dart) | — → **1328** |
| [seller/features/products/screens/seller_products_screen.dart](../../lib/seller/features/products/screens/seller_products_screen.dart) | — → **1313** |

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

## Baseline

Progress'ni o'lchash uchun boshlang'ich nuqta. Sprint tugaganda qayta yugurting
va yangi ustun qo'shing.

| O'lcham | 2026-08-07 | **2026-09-17** | Izoh |
|---|---|---|---|
| `lib/` dart fayllar | 509 | **510** | — |
| `lib/` qatorlar | 125 212 | **126 582** | +1 370 |
| >700 qatorli fayllar | 34 | **36** | ⚠️ o'sdi — T-16 |
| `dart analyze lib/ test/` | 1 issue | **1 issue** | o'sha `use_null_aware_elements` info |
| `flutter test` | 845 (+5 −5) | **923 / 923** | hammasi yashil |
| test fayllari | — | **140** | — |
| UI'dagi `sl<...>` | 129 | **116** | T-07 — 2 qism qoldi |
| `lib/shared` → mode importlari | 15 | **0** | ✅ maqsadga yetildi |
| `assets` hajmi | 48 MB | **7.1 MB** | ✅ T-04 + T-05 |
| `assets/models` | 38 MB | **yo'q** (R2 da) | ✅ T-04 |
| hardcoded o'zbekcha matn | 5 | **5** | T-17 — tegilmagan |
| `Result<T>` qarzi (repo) | 4 | **0** | ✅ T-10 yakunlandi (2026-09-18) |
| CI | qayta tiklandi | **yo'q** (qaror) | T-03 |
| Eskirgan major paketlar | 15 | **8** | T-15 3a/3b bajarildi |
| AGP / Gradle / Kotlin | 8.11.1 / 8.14 / 2.2.20 | **8.12.3** / 8.14 / 2.2.20 | connectivity_plus 7 talabi |

Qayta o'lchash buyruqlari:

```bash
# Kod hajmi
find lib -name "*.dart" | wc -l
find lib -name "*.dart" -exec cat {} + | wc -l
find lib -name "*.dart" -exec wc -l {} + | awk '$1>700 && $2!="total"' | wc -l

# Sifat  (CI yo'q — bu ikkitasi yagona gate)
dart analyze lib/ test/ 2>&1 | tail -1
flutter test --reporter=compact 2>&1 | tail -1

# Arxitektura
grep -rn "sl<" lib/ --include="*.dart" | grep -E "screens/|widgets/" | wc -l
grep -rn "import.*\(customer\|seller\)/" lib/shared --include="*.dart" | wc -l

# Hajm
du -sh assets

# i18n
grep -rnE "Text\(\s*'[A-ZА-Яa-zа-я][^']{4,}'" lib/ --include="*.dart" \
  | grep -v "tr(" | wc -l
```

---

## Tavsiya etilgan tartib (2026-09-17 da qayta ko'rilgan)

```
HOZIR      →  T-01                    (1.0.40+40 relizi — iOS'da rad javobi tuzatmasi
                                       hali chiqmagan; eng shoshilinch band)
✅ Bajarildi →  T-10                 (seller_wallet — Result chegarasidagi oxirgi qarz;
                                       to'siq yo'qoldi, istalgan vaqtda boshlash mumkin)
Fon ishi   →  T-15 4-to'lqin           (go_router 14→18 — 37 fayl, alohida sessiyada.
                                       3a/3b to'lqinlar 2026-09-18 da bajarildi)
✅ Bajarildi →  T-12 qoldig'i + T-13 (docs/ → doc/guides/ birlashtirildi)
Tegib o't  →  T-16..T-20              (T-16 o'sib boryapti: wallet_screen.dart 1932 qator)
Yopilgan   →  T-02 T-03 T-04 T-05 T-06 T-08 T-09 T-11
Qisman     →  T-07 (7/9) · T-15 (2/4)   — T-10, T-12, T-13 yakunlandi (2026-09-18)
```

**Eslatma — eski "Sprint 0 tugamaguncha boshqasiga o'tmang" qoidasi endi
ishlamaydi.** U CI (T-03) ni asos qilib olgan edi; CI olib tashlangach,
uning o'rnini **mahalliy intizom** egallaydi: har commit oldidan
`dart analyze lib/ test/` + `flutter test`. Qoida shu.

**Commit konventsiyasi:** `fix(debt): T-10 seller_wallet Result<T> ga ko'chirildi`

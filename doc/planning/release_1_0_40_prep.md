# T-01 — `1.0.40+40` reliz tayyorgarligi

> **Holat:** tayyorgarlik tugallandi (2026-09-18). **Relizning o'zini siz
> yugurtirasiz** — `shorebird release` imzolash kalitlariga muhtoj, ular faqat
> sizning mashinangizda.
>
> **Nega bu reliz kerak:** `1.0.39` iOS build'i Apple tomonidan **ITMS-91064**
> bilan rad etilgan (`NSPrivacyTracking=true` + BO'SH `NSPrivacyTrackingDomains`).
> Tuzatma `main` da, lekin **hech qachon chiqmagan**. Ya'ni hozir do'konda
> turgan iOS build'da o'sha nuqson bor.

---

## 1. Nima uchun patch emas, to'liq reliz

`tools/shorebird.sh check` ning tasnifi (ledger'dagi oxirgi reliz
`1.0.39+39`, SHA `e333566d43e8` ga nisbatan, 2026-09-18 holatiga):

| Turkum | Fayl | Ma'nosi |
|---|---|---|
| 🔴 NATIVE | `ios/Runner/PrivacyInfo.xcprivacy` | ITMS-91064 tuzatmasi |
| 🔴 NATIVE | `android/settings.gradle.kts` | AGP 8.12.3 (connectivity_plus 7 talabi) |
| 🟠 DEPS | `pubspec.yaml`, `pubspec.lock` | T-15 major bump'lar + test-only dev deps |
| 🟢 DART | 39 ta fayl | patch'ga sig'ardi, lekin yuqoridagilar bloklaydi |

**Uchala blocker ham "hard"** — Shorebird CLI `--allow-native-diffs` /
`--allow-asset-diffs` bilan majburlashni ogohlantirish bilan qabul qiladi,
**lekin bunday patch ishga tushganda ilovani yiqitadi**. Shuning uchun:
`shorebird release`, `shorebird patch` emas.

> ℹ️ `shorebird check` shu sandbox'da **ishga tushirilmadi** — Shorebird CLI
> bu yerda o'rnatilmagan (va imzolash kalitlari ham yo'q). Yuqoridagi jadval
> skriptning `classify_changes()` mantig'i aynan shu `git diff` ustida qo'lda
> qayta yurgizilib olindi, ya'ni raqamlar haqiqiy. Baribir o'z mashinangizda
> `./tools/shorebird.sh check` ni bir marta yugurtiring — u bundan keyingi
> commit'larni ham hisobga oladi.

---

## 2. Reliz oldidan (mahalliy gate — CI yo'q)

```bash
dart analyze lib/ test/          # kutilgan: 1 info (baseline use_null_aware_elements)
flutter test --concurrency=2     # --concurrency=2 MAJBURIY (SIGTERM flake'i)
flutter build apk --debug --dart-define-from-file=env/prod.json
```

Oxirgisi shart, chunki `pubspec.yaml` va `android/settings.gradle.kts`
o'zgargan — `flutter test` Gradle mos kelmasligini **ko'ra olmaydi**.

Shu build'dan keyin AD_ID ruxsatini qayta tekshiring (transitiv kutubxonalardan
keladi, dep bump uni o'zgartirishi mumkin):

```bash
grep -n "AD_ID" build/app/outputs/logs/manifest-merger-debug-report.txt
```

---

## 3. Konsol qadamlari (`doc/release_checklist.md` bo'yicha)

Bularni repo tekshira olmaydi — qo'lda, reliz chiqarishdan oldin.

### iOS — App Store Connect

- [ ] **APNs production kaliti.** Firebase Console → Project settings →
      Cloud Messaging → `com.mebellar.app` uchun `.p8` **Authentication Key**
      yuklangan, Key ID va Team ID (`LQ278UVP2Y`) to'g'ri. Sertifikat
      ishlatilsa — *Production* sertifikati va muddati o'tmagan bo'lsin.
      Push Notifications capability App ID da yoqilgan va provisioning profile
      shundan **keyin** qayta yaratilgan.
- [ ] **App Privacy anketasi `PrivacyInfo.xcprivacy` bilan mos.** Manifest
      hozir: tracking `true`, Device ID (tracking), User ID, Purchase History,
      Product Interaction, Crash Data, Performance Data.
- [ ] ⚠️ **`NSPrivacyTrackingDomains` bo'sh emasligini ko'zingiz bilan
      tasdiqlang** — `ep1.facebook.com` turibdi. **Aynan shu 1.0.39 ni
      yiqitgan.** Bo'sh massiv + `tracking=true` = ITMS-91064.
- [ ] **"What's New"** matnini `store/app_store_listing.md` §7 dan qo'ying
      (uz / ru / en bloklari tayyor, ≤4000 belgi sanab tekshirilgan).
- [ ] Version maydoni **1.0.40** (`store/app_store_listing.md` §6 da yangilangan).

### Android — Play Console

- [ ] **Advertising ID** deklaratsiyasi: ishlatiladi deb belgilangan,
      maqsadlari — *Advertising or marketing* + *Analytics*.
- [ ] **Data safety** iOS manifesti bilan bir xil to'plamni e'lon qiladi
      (device/advertising ID, purchase history, app interactions, crash logs,
      diagnostics) va yig'ish **ixtiyoriy** deb ko'rsatilgan ("Foydalanish
      statistikasi" toggle'i).
- [ ] **"What's New"** matnini `store/google_play_listing.md` §5 dan qo'ying
      (uz / ru / en, **≤500 belgi** — 426 / 422 / 398 sanab tekshirilgan).
- [ ] Maxfiylik siyosati URL'i: `https://woody.uz/uz/privacy`.

> `kMetaAdvancedMatchingEnabled` hamon **OFF**. Agar u yoqilib ketsa, telefon /
> ism / email **bir vaqtning o'zida** uchala joyga qo'shilishi kerak: privacy
> manifest, ikkala do'kon anketasi, va maxfiylik siyosati matni.

---

## 4. Relizni chiqarish

```bash
./tools/shorebird.sh release android
./tools/shorebird.sh release ios
```

Skript `build_release.sh` bilan bir xil env/imzo preflight'ini yugurtiradi
(`--obfuscate --split-debug-info`) va ledger'ga qatorni **avtomatik** qo'shadi.

Agar biror sababga ko'ra skriptdan tashqarida chiqarsangiz, ledger'ni qo'lda
yozing:

```bash
./tools/shorebird.sh record 1.0.40+40
```

### Ledger yozuvi shabloni

Skript o'zi qo'shadi; qo'lda yozilsa `tools/shorebird/releases.md` jadvaliga:

```
| 2026-09-__ | 1.0.40+40 | <git_sha_12> | android | 1.0.40: ITMS-91064 privacy manifest tuzatmasi + T-15 dep bump'lar (AGP 8.12.3) + T-10 seller_wallet Result<T> |
| 2026-09-__ | 1.0.40+40 | <git_sha_12> | ios     | 1.0.40: ITMS-91064 privacy manifest tuzatmasi + T-15 dep bump'lar (AGP 8.12.3) + T-10 seller_wallet Result<T> |
```

`<git_sha_12>` — relizni chiqargan commit'ning qisqa SHA'si
(`git rev-parse --short=12 HEAD`). Bu SHA muhim: keyingi
`./tools/shorebird.sh check` **aynan shunga nisbatan** diff oladi.

---

## 5. Relizdan keyin

- [ ] iOS build App Store Connect'da **ITMS-91064 siz** o'tganini tasdiqlang —
      bu relizning asosiy maqsadi.
- [ ] TestFlight build'ida push smoke-test (mahalliy `flutter run` emas — u
      development entitlement bilan imzolanadi, ya'ni sandbox APNs).
- [ ] `doc/planning/tech_debt_roadmap.md` dagi **T-01** ni yoping.
- [ ] `CLAUDE.md` dagi "oxirgi chiqqan build" qatorini `1.0.40+40` ga yangilang
      (hozir `1.0.39+39` deb turibdi).

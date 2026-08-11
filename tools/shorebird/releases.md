# Shorebird release ledger

Har bir `shorebird release` shu jadvalga yoziladi. `tools/shorebird.sh check`
shu yerdagi **Git SHA**'ga nisbatan diff oladi — ya'ni "shu versiyani
chiqarganimdan beri qaysi fayllarni o'zgartirdim?" degan savolga javob beradi.
Bu fayl git'ga **commit qilinadi** (`.log` emas — `*.log` gitignore'da).

Yozuvlar avtomatik qo'shiladi:

- `tools/shorebird.sh release android` → release chiqarib, jadvalga qator qo'shadi
- `tools/shorebird.sh record 1.0.18+18` → boshqa yo'l bilan chiqarilgan release'ni qo'lda yozish

| Sana | Versiya | Git SHA | Platforma | Izoh |
|------|---------|---------|-----------|------|
| 2026-06-19 | 1.0.18+18 | c80583d880e3 | android | — |
| 2026-06-19 | 1.0.18+18 | c80583d880e3 | ios | — |
| 2026-06-19 | 1.0.19+19 | 3a3453993b58 | android | — |
| 2026-06-19 | 1.0.19+19 | e957e55b4d98 | ios | — |
| 2026-06-20 | 1.0.20+20 | 257422291e3d | android | — |
| 2026-06-20 | 1.0.20+20 | 1706eeec8760 | ios | — |
| 2026-06-21 | 1.0.22+22 | ec4ad22d26c0 | android | 1.0.22: AI Interyer Dizayner + onboarding/AR backlog |
| 2026-06-21 | 1.0.22+22 | ec4ad22d26c0 | ios | 1.0.22: AI Interyer Dizayner + onboarding/AR backlog |
| 2026-06-21 | 1.0.23+23 | 5751400339b0 | android | 1.0.23: Facebook SDK + AI persona/chat overhaul |
| 2026-06-22 | 1.0.24+24 | 6b330b281c3c | android | — |
| 2026-06-22 | 1.0.24+24 | 0ca7e14d10c3 | ios | — |
| 2026-06-23 | 1.0.25+25 | 67237d36fb22 | android | 1.0.25: multi-object AR + FB validation fix |
| 2026-06-23 | 1.0.25+25 | 67237d36fb22 | ios | 1.0.25: multi-object AR + FB validation fix |
| 2026-06-24 | 1.0.26+26 | 4c945889c331 | android | 1.0.26: Meta App Events + unified network gates + NetworkLogger |
| 2026-06-24 | 1.0.26+26 | 4c945889c331 | ios | 1.0.26: Meta App Events + unified network gates + NetworkLogger |
| 2026-06-25 | 1.0.27+27 | 0d5addf4b79b | android | 1.0.27: launcher app-icon unread badge (app_badge_plus) |
| 2026-06-25 | 1.0.28+28 | f36231d54217 | android | — |
| 2026-06-25 | 1.0.29+29 | 92dd2499793b | android | — |
| 2026-06-25 | 1.0.29+29 | 1f296588821b | ios | — |
| 2026-06-26 | 1.0.30+30 | cbae8d34c732 | android | 1.0.30: seller banner flicker fix + authoritative push badge count |
| 2026-06-27 | 1.0.31+31 | 21535dba8d9d | android | 1.0.31: deferred payment + estimated max delivery fee + AR section refactor |
| 2026-06-28 | 1.0.32+32 | d466f8dca9c7 | android | 1.0.32: custom force-update overlay (in_app_update removed) + maintenance mode |
| 2026-06-28 | 1.0.32+32 | d466f8dca9c7 | ios | 1.0.32: custom force-update overlay (in_app_update removed) + maintenance mode |
| 2026-07-04 | 1.0.33+33 | e0e1d5f10170 | android | 1.0.33: iOS AR Quick Look, share-link back nav, customer AR part switcher, admin GLB/USDZ badges |
| 2026-07-04 | 1.0.33+33 | e0e1d5f10170 | ios | 1.0.33: iOS AR Quick Look, share-link back nav, customer AR part switcher, admin GLB/USDZ badges |
| 2026-07-06 | 1.0.34+34 | 301a5004a898 | android ios | 1.0.34: Crashlytics crash fixes (showcase boot, transient errors, MapKit, iOS AR registrar) |
| 2026-07-06 | 1.0.35+35 | 51281d85fce6 | android | 1.0.35: personalized home feed (Siz uchun + Ommabop) + splash refresh |
| 2026-07-07 | 1.0.35+35 | cdd7c55656e6 | ios | — |
| 2026-08-01 | 1.0.36+36 | 3077347c63a0 | android ios | 1.0.36: guest personal-API 401 guard + hybrid public notifications + wallet withdraw |
| 2026-08-03 | 1.0.37+37 | 46cb842c704c | android | 1.0.37: seller oferta/onboarding KYC persist + pick-time compress |
| 2026-08-07 | 1.0.38+38 | a61f0ec3386a | android | 1.0.38: T-15 1+2-to'lqin — dep upgrades (dio/lottie/yandex_mapkit/… + Firebase suite 3→4/15→16/4→5/11→12, iOS pod 11.15.0→12.17.0) |
| 2026-08-11 | 1.0.39+39 | e333566d43e8 | android | 1.0.39: Meta reklama infratuzilmasi — iOS privacy manifest (tracking=true), Release APNs production entitlement, Advanced Matching (flag OFF), maxfiylik siyosati Meta SDK oshkorligi |
| 2026-08-11 | 1.0.39+39 | e333566d43e8 | ios | 1.0.39: Meta reklama infratuzilmasi — iOS privacy manifest (tracking=true), Release APNs production entitlement, Advanced Matching (flag OFF), maxfiylik siyosati Meta SDK oshkorligi |

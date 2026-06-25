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

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

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

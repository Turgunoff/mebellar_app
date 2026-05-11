# Bundled Fonts (offline, native)

Bu jild Woody ilovasida ishlatiladigan **barcha shrift oilalarini
oldindan yuklab olgan TTF fayllar** bilan saqlaydi. Ilova ishga
tushganda hech qanday font internetdan yuklanmaydi.

> **Tarix:** Avval `google_fonts` paketi orqali offline rejim sozlangan
> edi. Endi paket olib tashlandi va Flutter'ning native shrift tizimiga
> o'tilgan — bog'liqlik kamayadi va bundle hajmi ~150 KB kichikroq.

## Qanday ishlaydi

1. `pubspec.yaml`'da har bir oila/og'irlik **`flutter.fonts:`** ostida
   ro'yxatga olingan:
   ```yaml
   flutter:
     fonts:
       - family: PlusJakartaSans
         fonts:
           - asset: assets/google_fonts/PlusJakartaSans-Regular.ttf
             weight: 400
           # ... va boshqalar
   ```

2. Kod doim oila nomini [`AppFonts`](../../lib/core/theme/app_fonts.dart)
   konstantalari orqali oladi (hardcode string yo'q):
   ```dart
   const TextStyle(
     fontFamily: AppFonts.seller,        // 'PlusJakartaSans'
     fontWeight: FontWeight.w500,
   )
   ```

3. Theme'lar [`app_theme.dart`](../../lib/core/theme/app_theme.dart) va
   [`app_typography.dart`](../../lib/core/theme/app_typography.dart) ham
   shu konstantalardan foydalanadi — `Text()` widget'lari hech qanday
   `fontFamily` ko'rsatmasdan ham to'g'ri shriftda renderlanadi.

## Mavjud fayllar (20 ta TTF, ~2.9 MB)

| Oila | Weights |
|------|---------|
| Inter | Regular, Medium, SemiBold, Bold, ExtraBold |
| Manrope | Regular, Medium, SemiBold, Bold, ExtraBold |
| PlayfairDisplay | Regular, Medium, SemiBold, Bold, ExtraBold |
| PlusJakartaSans | Regular, Medium, SemiBold, Bold, ExtraBold |

## Nomlash standarti (juda muhim)

`google_fonts` paketi faylni faqat shu formatda topadi:

```
{FontFamily}-{Weight}.ttf
```

- **FontFamily**: bo'sh joysiz CamelCase (`PlusJakartaSans`, `PlayfairDisplay`)
- **Weight**: standart PostScript nomi:

| FontWeight | Fayl nomidagi qism |
|------------|---------------------|
| `FontWeight.w100` | Thin |
| `FontWeight.w200` | ExtraLight |
| `FontWeight.w300` | Light |
| `FontWeight.w400` | Regular |
| `FontWeight.w500` | Medium |
| `FontWeight.w600` | SemiBold |
| `FontWeight.w700` | Bold |
| `FontWeight.w800` | ExtraBold |
| `FontWeight.w900` | Black |

Italik uchun: `{FontFamily}-{Weight}Italic.ttf` (masalan,
`Inter-BoldItalic.ttf`).

## Yangi font/weight qo'shish

### Yo'l 1 — Avtomatik (tavsiya etiladi)

CSS API orqali Google'dan TTF URL'larni olib yuklab olish:

```bash
# Misol: yangi "Lora" oilasini qo'shish
UA="Mozilla/4.0"
FAMILY="Lora"  # Google Fonts'dagi nom
URL_PREFIX="https://fonts.googleapis.com/css2?family"
curl -s -A "$UA" "$URL_PREFIX=${FAMILY}:wght@400;500;600;700" \
  | grep -oE "https://fonts\.gstatic\.com/[^)]+\.ttf"
# Chiqishi 4 ta URL — qo'lda 400→Regular, 500→Medium, ... deb saqlang.
```

Yoki [`tools/`](../../tools/) jildiga skript qo'shing.

### Yo'l 2 — Qo'lda

1. [Google Fonts](https://fonts.google.com/) saytidan font'ni yuklab oling.
2. ZIP ichidan kerakli `.ttf` fayllarni oling
   (odatda `static/` papkasida).
3. Yuqoridagi nomlash standarti bo'yicha qayta nomlang.
4. Bu jildga ko'chiring.
5. Tekshiring:
   ```bash
   flutter clean && flutter pub get && flutter run
   ```

## Italik kerak bo'lib qolsa

Hozir loyihada hech qanday italik shrift ishlatilmaydi (`FontStyle.italic`
chaqiruvi yo'q). Agar kerak bo'lsa:

1. `{FontFamily}-{Weight}Italic.ttf` formatida fayl qo'shing.
2. Misol: `Inter-Italic.ttf` (400i), `Inter-BoldItalic.ttf` (700i).

## Diagnostika

Ilovada matn **system default shriftda ko'rinsa** (Roboto/SF Pro), bu
quyidagilardan birini anglatadi:

1. Asset to'g'ri bundle qilinmagan → `flutter clean && flutter pub get`.
2. Fayl nomi noto'g'ri (yuqoridagi standartga rioya qiling).
3. Console'da `google_fonts` paketdan ogohlantirish ko'rinadi:
   `Could not load asset ...` — yo'l yoki nomni tekshiring.

## Litsenziya

Barcha to'rt oila **SIL Open Font License 1.1** ostida — tijoriy ilovada
ham erkin ishlatish mumkin, atribut talab qilinmaydi. Litsenziya
matnlari [Google Fonts](https://fonts.google.com/) saytida har bir
oila'ning "License" yorlig'ida.

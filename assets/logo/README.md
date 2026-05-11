# Woody Launcher Icon — Update Guide

Bu jild Woody ilovasi uchun **launcher icon** (iOS App Store + Android home
screen icon) va in-app brand asset'larini saqlaydi. Logo o'zgartirilganda
ushbu hujjatdagi ketma-ketlikni bajaring.

---

## ⚡ Tezkor reja (TL;DR)

Agar sizda **3 ta tayyor PNG** bo'lsa (foreground, monochrome, va master):

```bash
# 1. Yangi fayllarni joyiga qo'ying (eski nomlar bilan ustiga yozing)
cp ~/Downloads/woody_logo_new_master.png        assets/logo/woody_logo_foreground.png
cp ~/Downloads/woody_logo_new_monochrome.png    assets/logo/woody_logo_monochrome.png

# 2. Icon generatorni ishga tushiring
dart run flutter_launcher_icons

# 3. Sinab ko'ring
flutter run -d android
flutter run -d ios
```

Agar sizda **faqat 1 ta master PNG** bo'lsa (AI dan kelgan oddiy variant),
foreground va monochrome'ni o'zingiz hosil qilishingiz kerak — pastdagi
"To'liq ketma-ketlik" bo'limini o'qing.

---

## 📁 Asset fayllar ro'yxati

| Fayl | O'lchami | Mazmuni | Qayerda ishlatiladi |
|------|----------|---------|---------------------|
| `woody_logo.png` | 512×512 | Asl manba — transparent | Arxiv (zaxira) |
| `woody_logo_1024.png` | 1024×1024 | High-quality upscale | Zaxira master |
| `woody_logo_card.png` | 512×512 | Krem fonli versiya | Marketing, splash hero |
| **`woody_logo_foreground.png`** ⭐ | 1024×1024 | W markaziy 65%'da, atrofi transparent | iOS icon + Android adaptive foreground |
| **`woody_logo_monochrome.png`** ⭐ | 1024×1024 | Pure black W silhouette, transparent | Android 13+ themed icons |

⭐ = `flutter_launcher_icons` shu fayllardan icon generation qiladi.

---

## 📐 Asset talablari (spetsifikatsiya)

### 1. `woody_logo_foreground.png` (asosiy)

| Parametr | Qiymat | Sabab |
|----------|--------|-------|
| O'lcham | **1024×1024 px** | iOS App Store talabi va yuqori sifat |
| Format | PNG, RGBA (alfa bilan) | Transparent fon kerak |
| Fon | **Transparent** | iOS uchun `flutter_launcher_icons` krem rangga flatten qiladi; Android adaptive ostida ham `#FBF1E8` bo'ladi |
| W tarkibi | **Markaziy 65%** (≈665×665 px) | Android adaptive icon safe zone (66dp / 108dp) |
| Padding | **Har 4 tomondan ≈180 px** | Mask cropping (yumaloq, squircle) dan himoya |
| Markazlash | Qat'iy markazda | iOS va Android'da bir xil ko'rinishi uchun |

### 2. `woody_logo_monochrome.png` (Android 13+)

| Parametr | Qiymat | Sabab |
|----------|--------|-------|
| O'lcham | 1024×1024 px | Foreground bilan bir xil canvas |
| Format | PNG, RGBA | Faqat alfa kanal muhim |
| Rang | **Pure black `#000000`** | Android tizim foydalanuvchi tema rangiga avtomatik bo'yaydi |
| Shakl | W ning solid silhouette'i | Yog'och tola, terracotta, hech narsa YO'Q |
| Padding | Foreground bilan bir xil | Bir xil safe zone |

### 3. `woody_logo_card.png` (ixtiyoriy — marketing)

| Parametr | Qiymat |
|----------|--------|
| O'lcham | Min 1024×1024 (afzal) |
| Fon | Krem `#FBF1E8` solid fill |
| Maqsad | Splash screen, web hero, packaging |

---

## 🎯 To'liq ketma-ketlik

### Variant A: Faqat 1 ta yangi master PNG bor (AI dan)

Bu eng keng tarqalgan holat — AI yangi logo chizdi, sizda 1024×1024
transparent PNG bor. Foreground (padded) va monochrome'ni programmik hosil
qiling.

**1-qadam: Yangi master'ni joyiga qo'ying**

```bash
cp ~/Downloads/yangi_woody.png assets/logo/woody_logo.png
```

**2-qadam: Pillow (PIL) o'rnatilganligini tekshiring**

```bash
python3 -c "from PIL import Image; print('OK')"
# Agar xato bersa:
python3 -m pip install --user Pillow
```

**3-qadam: Generator skriptini yarating va ishga tushiring**

`tools/prepare_icons.py` faylini yarating (yoki yangilang):

```python
"""Master PNG'dan foreground (padded) va monochrome (silhouette) yaratadi."""
from PIL import Image
from pathlib import Path

LOGO_DIR = Path(__file__).parent.parent / "assets" / "logo"
SRC = LOGO_DIR / "woody_logo.png"
CANVAS = 1024
SAFE_ZONE = 0.65  # W markaziy 65%'da bo'lsin

master = Image.open(SRC).convert("RGBA")

# 1) Upscale to 1024 if smaller
if master.size != (CANVAS, CANVAS):
    upscaled = master.resize((CANVAS, CANVAS), Image.LANCZOS)
    upscaled.save(LOGO_DIR / "woody_logo_1024.png", optimize=True)

# 2) Foreground: W in central 65%, transparent padding around
safe = int(CANVAS * SAFE_ZONE)
w_small = master.resize((safe, safe), Image.LANCZOS)
fg = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
offset = ((CANVAS - safe) // 2, (CANVAS - safe) // 2)
fg.paste(w_small, offset, w_small)
fg.save(LOGO_DIR / "woody_logo_foreground.png", optimize=True)

# 3) Monochrome: solid black silhouette from foreground's alpha
mono = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
black = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
mono.paste(black, (0, 0), fg.split()[-1])
mono.save(LOGO_DIR / "woody_logo_monochrome.png", optimize=True)

print("OK — foreground va monochrome yaratildi.")
```

Buyruq:

```bash
python3 tools/prepare_icons.py
```

**4-qadam: Launcher icon'larni generate qiling**

```bash
dart run flutter_launcher_icons
```

**5-qadam: Verifikatsiya** (pastdagi "Tekshirish ro'yxati"'ni bajaring)

---

### Variant B: 3 ta tayyor fayl bor (dizaynerdan)

Dizayner foreground va monochrome'ni o'zi tayyor qilib bergan bo'lsa:

```bash
# Fayllarni o'rniga qo'ying
cp foreground_yangi.png  assets/logo/woody_logo_foreground.png
cp monochrome_yangi.png  assets/logo/woody_logo_monochrome.png
cp master_yangi.png      assets/logo/woody_logo.png   # ixtiyoriy

# Generation
dart run flutter_launcher_icons
```

---

## ⚙️ `pubspec.yaml` sozlanishi (o'zgartirmang)

Hozirgi konfiguratsiya — agar buzilsa, qayta tiklash uchun:

```yaml
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/logo/woody_logo_foreground.png"
  min_sdk_android: 21
  remove_alpha_ios: true
  background_color_ios: "#FBF1E8"
  adaptive_icon_background: "#FBF1E8"
  adaptive_icon_foreground: "assets/logo/woody_logo_foreground.png"
  adaptive_icon_monochrome: "assets/logo/woody_logo_monochrome.png"
```

**Diqqat:** `#FBF1E8` — brand "warm cream" rangi. O'zgartirsangiz,
`lib/core/theme/app_colors.dart`'dagi `lightBackground` ni ham yangilang.

---

## ✅ Tekshirish ro'yxati (har generation'dan keyin)

### iOS

```bash
# 1024×1024 versiyasi RGB bo'lishi kerak (alfa kanalsiz)
python3 -c "
from PIL import Image
i = Image.open('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
print('Mode:', i.mode)  # 'RGB' bo'lsin, 'RGBA' EMAS
"
```

- [ ] Mode = `RGB` (alfa yo'q) — App Store talabi
- [ ] Fon krem `#FBF1E8`
- [ ] W markazda, chetlarga tegmaydi

### Android

- [ ] `mipmap-xxxhdpi/ic_launcher_foreground.png` — 4 burchak transparent
- [ ] `mipmap-xxxhdpi/ic_launcher_monochrome.png` — faqat qora silhouette
- [ ] `values/colors.xml` — `ic_launcher_background = #FBF1E8`
- [ ] `mipmap-anydpi-v26/ic_launcher.xml` — 3 ta `<*>` element

```bash
# Foreground'ning 4 burchagi transparent ekanini avtomatik tekshirish:
python3 -c "
from PIL import Image
img = Image.open('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png').convert('RGBA')
w, h = img.size
corners = [(5,5), (w-5,5), (5,h-5), (w-5,h-5)]
for c in corners:
    a = img.getpixel(c)[3]
    print(f'{c}: alpha={a}', 'OK' if a == 0 else 'XATO — transparent emas!')
"
```

### Visual test

```bash
flutter run -d android   # Home screen'da app icon'ni qarang
flutter run -d ios       # Simulator/qurilmada
```

- [ ] Pixel telefonida (yumaloq mask) — W to'liq ko'rinadi
- [ ] Samsung telefonida (squircle) — W kesilmaydi
- [ ] Eski Android (kvadrat) — W markazda
- [ ] iOS home screen — W chetlarga tegmaydi

---

## 🛠 Muammolar va yechimlar

| Muammo | Ehtimoliy sabab | Yechim |
|--------|-----------------|--------|
| iOS build "icon has alpha" deb shikoyat qiladi | `remove_alpha_ios: false` yoki manba RGBA | `pubspec.yaml`'da `remove_alpha_ios: true` borligini tekshiring |
| Pixel telefonida W ning yon qismi kesilgan | Safe zone buzilgan (>72% canvas) | `woody_logo_foreground.png`'da W'ni qisqartiring (safe = 0.60–0.65) |
| Themed icon (Android 13+) g'alati rang bo'yaydi | Monochrome rangli, faqat silhouette emas | `woody_logo_monochrome.png`'ni qayta yarating (pure black silhouette) |
| `dart run flutter_launcher_icons` "image not found" | Yo'l noto'g'ri yoki fayl assets/'da yo'q | `pubspec.yaml`'dagi `image_path` va `adaptive_icon_*` yo'llarini tekshiring |
| Eski icon home screen'dan o'chmaydi | Android launcher cache'i | Qurilmadan ilovani **butunlay o'chiring** va qayta o'rnating |
| Icon noto'g'ri ko'rinadi `flutter run` ichida | Build cache eski | `flutter clean && flutter pub get` keyin qayta run |

---

## 🎨 Yangi master AI bilan chizdirish uchun prompt'lar

### Master (asosiy W + yog'och tola)

```
Premium minimalist app icon: bold geometric capital "W" monogram for
furniture brand "Woody".

- Solid filled silhouette of W in deep espresso brown #2A1A0E
- Inner negative space filled with consistent VERTICAL wood grain in
  terracotta #B85C38 (same direction across all three legs)
- One small wood knot at the apex of the middle V
- Background: transparent (alpha)
- Canvas: 1024×1024
- 15% safe padding on all sides — W must NOT touch edges
- Compact, roughly square proportions
- Strictly flat 2D vector, no 3D, no shadows, no gradients
- Must remain readable at 24×24 px

Avoid: hollow outlines, multiple grain patterns, end-grain bullseyes,
realistic wood texture, decorative elements, any text other than W,
3D effects, drop shadows.
```

### Monochrome variant

```
Same W silhouette as the master, but rendered as a PURE BLACK solid
shape (#000000) on transparent background. NO wood grain, NO terracotta,
NO inner texture — just the solid silhouette of the W letterform.
1024×1024 PNG, same safe zone padding as the master.
```

---

## 📌 Brand ranglari (Woody)

| Token | Hex | Ishlatish joyi |
|-------|-----|----------------|
| Cream (background) | `#FBF1E8` | Adaptive icon background, iOS fallback, splash |
| Terracotta (accent) | `#C27A5F` | Wood grain, primary brand accent |
| Terracotta Deep | `#B85C38` | Pressed/hover state |
| Espresso (outline) | `#2A1A0E` | W silhouette, dark text |

Bu kodlar [lib/core/theme/app_colors.dart](../../lib/core/theme/app_colors.dart)
faylida sinxron saqlanishi kerak.

---

## 📚 Foydalanilgan paket

- [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
  ^0.14.1 — `dev_dependencies`'da

Yangi versiya chiqsa, `pubspec.yaml`'ni yangilab `flutter pub get` ni
qayta ishga tushiring.

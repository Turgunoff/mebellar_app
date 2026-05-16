# 12 — Localization

> Asl §10.

## 1. Qo'llab-quvvatlanadigan tillar

`uz` (default), `ru`, `en`. Foydalanuvchi tili `profiles.preferred_language` da saqlanadi, mobile localda Hive `settings`'da ham backup qilinadi.

## 2. Stack: `easy_localization`

```yaml
# pubspec.yaml
dependencies:
  easy_localization: ^3.0.7

flutter:
  assets:
    - assets/translations/
```

## 3. Setup

```dart
// main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await _initRootScope();
  // ...

  runApp(EasyLocalization(
    supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('uz'),
    child: Phoenix(child: switch (mode) {
      AppMode.seller => const SellerApp(),
      AppMode.customer => const CustomerApp(),
    }),
  ));
}
```

```dart
// customer_app.dart / seller_app.dart
MaterialApp.router(
  // ...
  localizationsDelegates: context.localizationDelegates,
  supportedLocales: context.supportedLocales,
  locale: context.locale,
)
```

## 4. UI matnlari (string keys)

```json
// assets/translations/uz.json
{
  "common": {
    "save": "Saqlash",
    "cancel": "Bekor qilish",
    "loading": "Yuklanmoqda..."
  },
  "auth": {
    "login": "Kirish",
    "register": "Ro'yxatdan o'tish",
    "email_not_confirmed": "Email tasdiqlanmagan"
  },
  "products": {
    "out_of_stock": "Mavjud emas",
    "in_stock": "Mavjud"
  },
  "error": {
    "tariff_limit_exceeded": {
      "title": "Tarif limitiga yetdingiz",
      "message": "{limit} mahsulot. Yangilab cheksizga o'ting."
    },
    "insufficient_stock": "Mahsulot yetarli emas",
    "validation_error": "Noto'g'ri ma'lumot",
    "unknown": "Xatolik yuz berdi"
  },
  "tariff": {
    "copy_card": "Karta raqamini ko'chirish",
    "card_copied": "Karta raqami nusxalandi",
    "upload_screenshot": "To'lov skrinshotini yuklash",
    "upgrade": "Tarifni yangilash"
  },
  "profile": {
    "switch_to_seller": "Sotuvchi rejimi",
    "switch_to_customer": "Xaridor rejimi"
  }
}
```

ru.json va en.json bir xil struktura.

## 5. Foydalanish

```dart
import 'package:easy_localization/easy_localization.dart';

Text(tr('common.save'))
Text('error.tariff_limit_exceeded.message'.tr(namedArgs: {'limit': '10'}))
```

---

## 6. Backend content (multilingual JSONB)

Backend response mahsulot/shop nomi JSONB qaytaradi:

```json
{
  "id": "uuid",
  "name": {"uz": "Yog'och stol", "ru": "Деревянный стол", "en": "Wooden table"}
}
```

Mobile `MultilingualText` model bilan tanlaydi:

```dart
// shared/models/multilingual_text.dart
class MultilingualText {
  final String? uz;
  final String? ru;
  final String? en;

  const MultilingualText({this.uz, this.ru, this.en});

  factory MultilingualText.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MultilingualText();
    return MultilingualText(
      uz: json['uz'] as String?,
      ru: json['ru'] as String?,
      en: json['en'] as String?,
    );
  }

  String get(String lang) {
    return switch (lang) {
      'ru' => ru ?? uz ?? en ?? '',
      'en' => en ?? uz ?? ru ?? '',
      _ => uz ?? ru ?? en ?? '',
    };
  }
}

// Ishlatish
Text(product.name.get(context.locale.languageCode))
```

Yoki extension:

```dart
extension MultilingualTextX on MultilingualText {
  String forContext(BuildContext context) => get(context.locale.languageCode);
}

Text(product.name.forContext(context))
```

---

## 7. Tilni o'zgartirish

```dart
// lib/customer/features/profile/widgets/language_picker.dart
Future<void> _setLanguage(BuildContext context, String lang) async {
  // 1. EasyLocalization
  await context.setLocale(Locale(lang));

  // 2. Backend update
  await GetIt.I<AuthRepository>().updateProfile({'preferred_language': lang});

  // 3. Hive backup
  await GetIt.I<Box>(instanceName: 'settings').put('preferred_language', lang);
}
```

> **Bonus:** App restart **shart emas** — `easy_localization.setLocale()` reactive, butun UI darhol til'da yangilanadi.

---

## 8. Backend error code'larni tarjima qilish

```dart
String translateError(Map<String, dynamic>? error) {
  final code = error?['code'] as String?;
  if (code == null) return tr('error.unknown');

  // 'error.<code>' kalit `easy_localization`'da bormi?
  final key = 'error.$code';
  final translated = tr(key);
  return translated == key ? error?['message'] as String? ?? tr('error.unknown') : translated;
}
```

---

## 9. Number/currency/date formatlash

`intl` paketi bilan:

```dart
import 'package:intl/intl.dart';

String formatCurrency(num amount, {String locale = 'uz'}) {
  final fmt = NumberFormat('#,###', locale);
  return '${fmt.format(amount)} so\'m';
}

String formatDate(DateTime date, {String locale = 'uz'}) {
  return DateFormat('d MMM yyyy', locale).format(date);
}
```

---

## 10. Pluralization (kerak bo'lsa)

```json
{
  "products_count": {
    "zero": "Mahsulot yo'q",
    "one": "{count} mahsulot",
    "other": "{count} mahsulot"
  }
}
```

```dart
Text('products_count'.plural(productCount))
```

---

## 11. RTL — kerak emas (uz, ru, en hammasi LTR)

V1'da arab/forsiy tillar yo'q — RTL sozlash kerak emas.

---

## 12. Test

```dart
testWidgets('language switch updates UI', (tester) async {
  await tester.pumpWidget(testApp(SettingsScreen()));

  await tester.tap(find.text('Русский'));
  await tester.pumpAndSettle();

  expect(find.text('Сохранить'), findsOneWidget);  // ru: save
});
```

---

## 13. Translation review

Native speakers tarjimalarni tekshiradi (V1 launch'dan oldin). Tarjima fayllari git history'da — har o'zgarishni track qilish.

---

## 14. Keyingi qadam

→ [13-security.md](./13-security.md) — mobile xavfsizlik

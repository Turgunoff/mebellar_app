# 10 — Tariff Upgrade UX (P2P pul o'tkazma)

> Asl §7.2 mobile UX. Backend logikasi: `backend/docs/07-tariffs-payments.md`.

## 1. Konteks (qisqacha)

V1'da rasmiy to'lov gateway YO'Q. Sotuvchilar tariff uchun **P2P karta-karta pul o'tkazma** orqali to'laydilar. Sotuvchi platforma egasining shaxsiy karta hisobiga pul o'tkazadi va skrinshot yuboradi. Admin manual tasdiqlaydi.

## 2. Tariff sahifasi

### List

```
[ Joriy: Free ]

[Free]      Bepul         — 10 mahsulot, 5% komissiya       [Joriy ✓]
[Basic]     99,000/oy     — 100 mahsulot, 3% komissiya     [Tanlash]
[Pro]       299,000/oy    — Cheksiz, 2%, Analytics          [Tanlash] [⭐ Recommended]
[Enterprise] Custom       — Custom features                 [Bog'lanish]
```

### Tarif kartochkalari

- Narx
- Asosiy imkoniyatlar (limitlardan farq, can_use_* flags)
- Joriy bo'lsa "Joriy ✓" badge
- Recommended bo'lsa "⭐ Eng mashhur"

### API

```
GET /tariffs                      # public, hamma tariflar
GET /seller/tariff                # joriy + tugash sanasi + status
```

---

## 3. Upgrade flow — Payment Instructions Bottom Sheet

Foydalanuvchi tarif tanlaganda, bottom sheet ochiladi:

```
┌─────────────────────────────────────────┐
│ Pro tarifi                              │
│ 299,000 so'm/oy                         │
│                                         │
│ Quyidagi karta raqamiga pul o'tkazing:  │
│                                         │
│ 🏦 Humo: 9860 1234 5678 9012            │
│ 👤 Karta egasi: Eldor Turg'unov         │
│                                         │
│ Izoh (commentariy)da yoz: SHOP-{shop_id}│
│                                         │
│ [📋 Karta raqamini ko'chirish]          │
│ [📸 To'lov skrinshotini yuklash]        │
│                                         │
│ Yoki @MebellarSupportBot'ga             │
│ skrinshot yuboring                      │
└─────────────────────────────────────────┘
```

### Implementatsiya

```dart
// lib/seller/features/tariff/widgets/payment_instructions_sheet.dart
class PaymentInstructionsSheet extends StatelessWidget {
  final Tariff tariff;
  final BillingPeriod period;
  final String shopId;

  @override
  Widget build(BuildContext context) {
    final amount = period == BillingPeriod.monthly
        ? tariff.priceMonthly
        : tariff.priceYearly;

    return BottomSheet(
      // ...
      child: Column(
        children: [
          Text(tariff.name.get(lang)),
          Text(formatCurrency(amount)),
          // Karta raqami widget — tap'da clipboard
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: '9860123456789012'));
              showSnackbar(context, tr('tariff.card_copied'));
            },
            child: CardNumberWidget('9860 1234 5678 9012', 'Eldor Turg'unov'),
          ),
          Text('Izoh: SHOP-$shopId'),
          ElevatedButton.icon(
            icon: Icon(Icons.copy),
            label: Text(tr('tariff.copy_card')),
            onPressed: _copyCard,
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.upload_file),
            label: Text(tr('tariff.upload_screenshot')),
            onPressed: () => _pickAndUpload(context),
          ),
        ],
      ),
    );
  }
}
```

### Skrinshot upload

```dart
Future<void> _pickAndUpload(BuildContext context) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.gallery);
  if (file == null) return;

  // Client-side resize
  final resized = await resizeImage(file, maxWidth: 2048, quality: 85);

  // Supabase Storage upload (private bucket)
  final path = 'payments/$shopId/${uuid.v4()}.jpg';
  await Supabase.instance.client.storage
      .from('payments')
      .uploadBinary(path, resized, fileOptions: const FileOptions(contentType: 'image/jpeg'));

  // Backend so'rovi
  await tariffRepository.upgradeRequest(TariffUpgradeRequest(
    tariffCode: tariff.code,
    billingPeriod: period.name,
    paymentScreenshotUrl: path,
    amountPaid: amount.toInt(),
  ));

  // Bottom sheet yopiladi va status sahifasi ochiladi
  Navigator.pop(context);
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => PaymentPendingScreen(),
  ));
}
```

### API

```
POST /seller/tariff/upgrade
{
  "tariff_code": "pro",
  "billing_period": "monthly",
  "payment_screenshot_url": "payments/<shop_id>/<uuid>.jpg",
  "amount_paid": 299000,
  "sender_card_last4": "1234",      // ixtiyoriy
  "sender_name": "Salim Aliyev",    // ixtiyoriy
  "comment": "Pro tarif uchun"      // ixtiyoriy
}
```

---

## 4. Pending status sahifasi

```
[ Pending ]

⏳ To'lov tasdiqlash kutilmoqda

Pro tarifi: 299,000 so'm
Yuborilgan: 2026-05-01 14:23
Tasdiqlash uchun: 24 soat ichida

Joriy tarif (Free) hozircha amal qiladi.
Tasdiqlangach, Pro tarifiga o'tasiz.

[Tarix]    [Bekor qilish]
```

> **Pending paytida:** shop free tarifida qoladi, `expires_at` ko'rsatilmaydi.

### Push notif kelganda

- Approved: "Pro tarifiga muvaffaqiyatli o'tdingiz! 🎉" → tariff sahifasi refresh
- Rejected: "To'lov tasdiqlanmadi: <sabab>. Iltimos, qayta urinib ko'ring." → upgrade flow qayta ochiladi

---

## 5. Tariff history

Profile ostida "Tariflar tarixi" — `subscriptions` jadvalidan list:

```
- Pro     2026-04-01 → 2026-05-01    Active
- Basic   2026-03-01 → 2026-04-01    Expired
- Free    2026-02-01 → 2026-03-01    Expired
```

(V1'da optional, V2'da albatta.)

---

## 6. Tariff expiring warning

Push notif backend cron (`check_expiring_subscriptions`)'dan keladi 7 kun oldin:

> "Tarif tugashiga 7 kun qoldi. Davomini ta'minlash uchun yangilang."

Click → tariff upgrade flow.

Tugagandan keyin avtomatik free'ga downgrade va push: "Tarif tugadi. Free rejimga o'tdingiz. Mahsulotlaringiz limit ostida arxivlandi."

---

## 7. Limit reached UX

Mahsulot qo'shishda backend `tariff_limit_exceeded` qaytarsa:

```dart
on DioException catch (e) {
  if (e.response?.data?['error']?['code'] == 'tariff_limit_exceeded') {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('error.tariff_limit_exceeded.title')),
        content: Text(tr('error.tariff_limit_exceeded.message',
          namedArgs: {'limit': tariff.maxProducts.toString()})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TariffUpgradeScreen(),
              ));
            },
            child: Text(tr('tariff.upgrade')),
          ),
        ],
      ),
    );
  }
}
```

---

## 8. Telegram alternativ

Bottom sheet'da link: "Yoki @MebellarSupportBot'ga skrinshot yuboring":

- `tg://resolve?domain=MebellarSupportBot` deep link
- Telegram ochiladi, bot bilan suhbat
- Admin Telegram bot orqali skrinshot oladi va manual tasdiqlaydi
- Status mobile app'da sync bo'ladi (push notif)

---

## 9. Test

```dart
testWidgets('PaymentInstructionsSheet copies card to clipboard', (tester) async {
  await tester.pumpWidget(testApp(PaymentInstructionsSheet(...)));

  await tester.tap(find.text(tr('tariff.copy_card')));
  await tester.pumpAndSettle();

  final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
  expect(clipboardData?.text, '9860123456789012');
  expect(find.byType(SnackBar), findsOneWidget);
});
```

---

## 10. Keyingi qadam

→ [11-storage-image-upload.md](./11-storage-image-upload.md) — image picker, resize, Supabase Storage

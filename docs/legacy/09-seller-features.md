# 09 — Seller Features (Onboarding + Verification + Operations)

> Asl §1.2 seller parts + §6 (verification UX angle).

## Bottom navigation (V1)

```
[Dashboard] [Products] [Orders] [Analytics] [Profile]
```

> Tariff va Settings — Profile ostida.

---

## 1. Seller onboarding (`seller/features/onboarding/` — customer mode'da boshlanadi)

> **Muhim UX:** onboarding **customer app ichida** boshlanadi, oxirida `switchAppMode` chaqirib SellerApp'ga o'tiladi. Sabab: hali seller emas — current AppMode customer.

### Multi-step form

```
Step 1: Welcome
  "Mebellar'da sotishni boshlang. 5 daqiqada ro'yxatdan o'ting."
  [Boshlash]

Step 2: Yuridik holat
  ○ Jismoniy shaxs    (passport bilan)
  ○ Yakka tartibdagi tadbirkor (YaTT)
  ○ MChJ
  ○ AJ
  Ma'lumot: "Jismoniy shaxs ham to'liq sotuvchi bo'la oladi. YaTT majburiy emas."

Step 3: Shaxsiy ma'lumot
  - F.I.O. (legal_name)
  - Telefon raqami
  - Email
  - Telegram username (ixtiyoriy)

Step 4: Do'kon ma'lumoti
  - Do'kon nomi (uz, ru — kamida bittasi)
  - Qisqa tavsif
  - Manzil — region picker, address line, map (lat/lng tap)

Step 5: Verification
  - "Hujjatlaringizni keyinroq yuborasiz" (skip)
  - "Hozir yuborish" (verification screen ochiladi)

Step 6: Done
  "Tasdiqlash uchun yuborildi. 1-3 ish kuni ichida javob beramiz."
  [Sotuvchi rejimiga o'tish]  → switchAppMode(seller)
```

### API

```
POST /seller/onboarding
{
  "business_type": "individual",
  "legal_name": "...",
  "shop_name": {"uz": "...", "ru": "..."},
  "shop_description": {"uz": "..."},
  "contact_phone": "+998...",
  "contact_email": "...",
  "telegram_username": "...",
  "address": "...",
  "region_id": "uuid",
  "latitude": 41.3,
  "longitude": 69.2
}
```

Backend: seller_profile (status=pending) + shop (visibility=draft) yaratadi. Tafsilot: `backend/docs/06-verification.md §2.2`.

### Save progress

Multi-step form'da har step localga (Hive) saqlash — abandonment yuqori, foydalanuvchi qaytib kelganda joydan davom etishi shart.

---

## 2. Verification (`seller/features/verification/`)

### Status screens

| Status | UI |
|--------|-----|
| `pending` | "Hujjatlar yuklanmagan" + [Yuklash] tugma |
| `in_review` | "Tasdiqlash kutilmoqda" + spinner + estimated SLA |
| `approved` | "Tasdiqlangan ✓" + "Sotishni boshlash" CTA |
| `rejected` | "Rad etildi: <sabab>" + [Qayta yuborish] |

### Upload flow

```
1. Tip: "Quyidagi hujjatlar kerak (jismoniy shaxs uchun):
   • Passport old tomon
   • Passport orqa tomon
   • Selfie (passport bilan)"

2. Image picker har hujjat uchun (camera + gallery)

3. Client-side resize (max 2048x2048, JPG 85)

4. Supabase Storage upload (verification/ bucket, private):
   final path = 'verification/${userId}/passport_front.jpg';
   await supabase.storage.from('verification').upload(path, file);

5. Backend: POST /seller/verification/manual
   {
     "passport_front_url": "verification/.../passport_front.jpg",
     "passport_back_url": "...",
     "selfie_url": "...",
     "passport_series": "AB1234567",
     "inn": "..."   // self_employed/llc bo'lsa
   }

6. Status → in_review
7. Admin tasdiqlaganda push notif + status approved
```

### YaTT/MChJ uchun qo'shimcha hujjatlar

`business_type == 'self_employed'`:
- + business_certificate (YaTT guvohnomasi PDF)
- + INN

`business_type == 'llc'`:
- Direktor passport (yuqoridagi 3 ta)
- Ustav (PDF)
- Davlat ro'yxat guvohnomasi
- INN

### API

```
GET /seller/verification              # joriy holat
POST /seller/verification/manual      # submit
POST /seller/verification/myid        # V2 — disabled
```

---

## 3. Dashboard (`seller/features/dashboard/`)

### Tarkibi

- Verification status banner (agar approved emas)
- KPI cards:
  - Bugungi orders
  - Bugungi revenue
  - Pending orders count
  - Active products count / max_products
- "Yangi orderlar" — top 5 (realtime channel'dan ham keladi)
- "Top products" — last 7 days (Pro tariff'da)

### API

```
GET /seller/analytics/overview
GET /seller/orders?status=pending&per_page=5
```

### Realtime new order

- `RealtimeOrdersSource` bilan watch
- Yangi order kelganda: snackbar + haptic + KPI update

---

## 4. Products (`seller/features/products/`)

### List

- Search bar
- Filter: status (draft/pending/approved/rejected/archived)
- Item: thumbnail, name, price, status badge, stock
- "+" FAB → create

### Create / Edit

```
Step 1: Name + description (multilingual tabs)
Step 2: Category + attributes (kategoriyaga xos)
Step 3: Price + stock + SKU
Step 4: Images (gallery, drag reorder, primary toggle)
Step 5: Dimensions + weight (yetkazib berish hisobi uchun)
Step 6: Save as draft / Submit for review
```

### Tariff limit

Mahsulot qo'shishda backend `tariff_limit_exceeded` xato qaytarsa, UI:

```
"10/10 mahsulotga yetdingiz. Tarifni yangilang"
[Pro tarifiga o'tish] → Tariff upgrade screen
```

### API

```
GET /seller/products?status=&page=
POST /seller/products
GET /seller/products/{id}
PATCH /seller/products/{id}
DELETE /seller/products/{id}
POST /seller/products/{id}/images
DELETE /seller/products/{id}/images/{image_id}
```

Image upload — tafsilot: [11-storage-image-upload.md](./11-storage-image-upload.md).

---

## 5. Orders (`seller/features/orders/`)

### List

- Tabs: New (pending) | Active (confirmed/preparing/shipped) | Done (delivered/completed) | Cancelled
- Item: order_number, customer name, total, status, date
- Yangi order: highlight + badge

### Detail

- Order info, items, customer, address, payment_method
- Status timeline
- Action buttons (state machine):
  - `pending` → [Tasdiqlash] [Bekor qilish]
  - `confirmed` → [Tayyorlash boshlandi] [Bekor qilish]
  - `preparing` → [Yuborilgan] [Bekor qilish]
  - `shipped` → [Yetkazildi] [Bekor qilish]
  - `delivered` → wait for customer to mark `completed`
  - `completed` → no action

### API

```
GET /seller/orders?status=&page=
GET /seller/orders/{id}
POST /seller/orders/{id}/confirm
POST /seller/orders/{id}/ship
POST /seller/orders/{id}/deliver
POST /seller/orders/{id}/cancel
```

---

## 6. Shop Settings (`seller/features/shop_settings/`)

### Tarkibi

- Logo / cover upload (image picker → Supabase Storage)
- Multilingual name, description
- Brand color picker
- Address (region picker + map)
- Working hours (jadval)
- Visibility toggle (public/hidden)
- Services (alohida sub-screen)

### Services configuration

```
[Service type] [Toggle] [Configure ⚙️]

Misol:
[Bepul yetkazib berish] [✓] [⚙️ Min order: 1,000,000 so'm]
[Yig'ib berish]         [✓] [⚙️ Narx: 50,000 so'm]
[12 oy garantiya]       [✓] [⚙️]
```

### API

```
GET /seller/shop
PATCH /seller/shop
POST /seller/shop/logo
POST /seller/shop/cover
GET /seller/services
PUT /seller/services
```

---

## 7. Tariff (`seller/features/tariff/`)

Bu alohida fayl: [10-tariff-upgrade-ux.md](./10-tariff-upgrade-ux.md) — P2P to'lov flow tafsilotli.

---

## 8. Analytics (`seller/features/analytics/`)

V1'da basic (Pro tariff'dagi sotuvchilar uchun batafsil):

- Sales chart (last 30 days)
- Top products (by revenue, by quantity)
- Customer geo distribution (V2)

`fl_chart` paketi — deferred import (V2'da bundle optimization).

### API

```
GET /seller/analytics/overview
GET /seller/analytics/sales?from=&to=
GET /seller/analytics/products
```

---

## 9. Seller Profile

- Shop info (link to shop_settings)
- Verification status (link to verification)
- Tariff (link to tariff page)
- "Xaridor rejimi" tugma — `switchAppMode(customer)`
- "Chiqish"

---

## 10. Empty va Error states

- Hech mahsulot yo'q: "Birinchi mahsulotingizni qo'shing"
- Hech order yo'q: "Hali buyurtma kelgan emas"
- Pending verification: barcha screen'lar disabled, banner top'da

---

## 11. Test pattern

```dart
testWidgets('OnboardingFlow saves progress between steps', (tester) async {
  await tester.pumpWidget(testApp(OnboardingScreen()));

  // Step 1
  await tester.tap(find.text('Boshlash'));
  await tester.pumpAndSettle();

  // Step 2
  await tester.tap(find.text('Jismoniy shaxs'));
  await tester.tap(find.text('Davom'));

  // App'ni yopish (simulating)
  await tester.pumpAndSettle();

  // Hive'da saqlangan
  final box = await Hive.openBox('onboarding_draft');
  expect(box.get('business_type'), 'individual');
});
```

---

## 12. Keyingi qadam

→ [10-tariff-upgrade-ux.md](./10-tariff-upgrade-ux.md) — P2P to'lov UX

# 07 — API Reference (Mobile angle)

> Asl §4.4 + §19.5. Backend kontrakti — mobile qaysi endpoint'larni iste'mol qiladi. Backend dasturchi `backend/docs/04-api-endpoints.md` da bir xil ro'yxatni ko'radi.

## Base URL va header

```
Production:  https://api.mebellar.uz/api/v1
Staging:     https://staging.api.mebellar.uz/api/v1
Dev:         http://localhost:8000/api/v1
```

Har authenticated request'da:

```
Authorization: Bearer <supabase_jwt>
Accept-Language: uz   # optional, V1'da JSONB butun obyekt qaytadi
```

---

## 1. Public (auth shart emas)

| Method | Path | Iste'molchi | Maqsad |
|--------|------|-------------|--------|
| GET | `/health` | Both | Server status check |
| GET | `/categories` | Customer | Catalog tree |
| GET | `/categories/{slug}` | Customer | Category detail |
| GET | `/regions` | Both | Address picker |
| GET | `/products` | Customer | Catalog list, filter, search, pagination |
| GET | `/products/{slug}` | Customer | Product detail |
| GET | `/shops` | Customer | Shop list |
| GET | `/shops/{slug}` | Customer | Shop detail |
| GET | `/shops/{slug}/products` | Customer | Shop's products |
| GET | `/banners` | Customer | Home banners |
| GET | `/tariffs` | Seller | Tariff list (upgrade UI) |
| GET | `/service-types` | Seller | Available services |

### Catalog filter params

```
GET /products?
    category=<slug>
    &shop=<slug>
    &search=<text>
    &min_price=<int>
    &max_price=<int>
    &sort=created_at|price_asc|price_desc|popular
    &page=<int>
    &per_page=<int>  // max 100
```

---

## 2. Authenticated (any user)

| Method | Path | Iste'molchi | Maqsad |
|--------|------|-------------|--------|
| GET | `/me` | Both | Profile + roles + seller_profile (agar mavjud) |
| PATCH | `/me` | Both | Profile update (full_name, preferred_language, ...) |
| DELETE | `/me` | Both | Soft delete (90 kun grace) |
| GET | `/me/addresses` | Customer | Address list |
| POST | `/me/addresses` | Customer | Add address |
| PATCH | `/me/addresses/{id}` | Customer | Update |
| DELETE | `/me/addresses/{id}` | Customer | Remove |
| GET | `/cart` | Customer | Cart items |
| POST | `/cart/items` | Customer | Add to cart |
| PATCH | `/cart/items/{id}` | Customer | Quantity change |
| DELETE | `/cart/items/{id}` | Customer | Remove |
| GET | `/favorites` | Customer | Wishlist |
| POST | `/favorites/{product_id}` | Customer | Add |
| DELETE | `/favorites/{product_id}` | Customer | Remove |
| GET | `/orders` | Customer | Buyer's orders |
| POST | `/orders` | Customer | Checkout |
| GET | `/orders/{id}` | Customer | Order detail |
| POST | `/orders/{id}/cancel` | Customer | Cancel pending order |
| GET | `/notifications` | Both | List, unread count |
| PATCH | `/notifications/{id}/read` | Both | Mark single as read |
| POST | `/notifications/read-all` | Both | Mark all |
| POST | `/seller/onboarding` | Customer (becoming seller) | seller_profile + shop yaratish (pending) |

### Checkout request body

```json
POST /orders
{
  "shop_id": "uuid",
  "items": [
    {
      "product_id": "uuid",
      "quantity": 2,
      "selected_services": ["assembly", "warranty_1y"]
    }
  ],
  "delivery_method": "shop_delivery",
  "address_id": "uuid",       // pickup bo'lsa kerak emas
  "recipient_name": "...",
  "recipient_phone": "+998...",
  "delivery_notes": "Uy oldida qo'ying",
  "payment_method": "cash_on_delivery",   // V1
  "customer_note": "..."
}
```

> **Multi-shop split:** agar cart'da bir nechta shop'dan mahsulot bo'lsa, mobile har shop uchun **alohida** `POST /orders` chaqiradi.

---

## 3. Seller (verification approved kerak)

> **JWT-based shop resolution:** URL'da `{shop_id}` YO'Q. Backend JWT'dan user_id → seller_profile → shop'ni aniqlaydi.

| Method | Path | Maqsad |
|--------|------|--------|
| GET | `/seller/shop` | O'z do'koni |
| PATCH | `/seller/shop` | Shop info update |
| POST | `/seller/shop/logo` | Logo upload |
| POST | `/seller/shop/cover` | Cover upload |
| GET | `/seller/products` | Mahsulotlar ro'yxati |
| POST | `/seller/products` | Yangi mahsulot |
| GET | `/seller/products/{id}` | Detail |
| PATCH | `/seller/products/{id}` | Update |
| DELETE | `/seller/products/{id}` | Soft delete |
| POST | `/seller/products/{id}/images` | Image upload |
| DELETE | `/seller/products/{id}/images/{image_id}` | Remove image |
| GET | `/seller/orders` | Shop'ga kelgan orderlar |
| GET | `/seller/orders/{id}` | Order detail |
| POST | `/seller/orders/{id}/confirm` | pending → confirmed |
| POST | `/seller/orders/{id}/ship` | preparing → shipped |
| POST | `/seller/orders/{id}/deliver` | shipped → delivered |
| POST | `/seller/orders/{id}/cancel` | Cancel (any non-final state) |
| GET | `/seller/services` | Yoqilgan xizmatlar |
| PUT | `/seller/services` | Toggle services + config |
| GET | `/seller/tariff` | Joriy tarif |
| POST | `/seller/tariff/upgrade` | P2P to'lov so'rovi (skrinshot bilan) |
| GET | `/seller/analytics/overview` | KPI |
| GET | `/seller/analytics/sales` | `?from=&to=` |
| GET | `/seller/analytics/products` | Top products |
| GET | `/seller/verification` | Joriy holat |
| POST | `/seller/verification/manual` | Passport upload |
| POST | `/seller/verification/myid` | V2, hozir disabled |

### Tariff upgrade body

```json
POST /seller/tariff/upgrade
{
  "tariff_code": "pro",
  "billing_period": "monthly",
  "payment_screenshot_url": "payments/<shop_id>/<uuid>.jpg",
  "amount_paid": 299000,
  "sender_card_last4": "1234",
  "sender_name": "Salim Aliyev",
  "comment": "Pro tarif uchun"
}
```

---

## 4. Standart javob formati

### Muvaffaqiyat

```json
{
  "data": { ... },
  "meta": { "page": 1, "total": 100, "per_page": 20 }
}
```

### Xatolik

```json
{
  "error": {
    "code": "tariff_limit_exceeded",
    "message": "Tariff limit: 10 products",
    "details": {}
  }
}
```

Mobile `error.code` bo'yicha `easy_localization` bilan tarjima qiladi:

```dart
final errorCode = response.data?['error']?['code'];
final message = errorCode != null
    ? tr('error.$errorCode')
    : tr('error.unknown');
```

### Standart error code'lar (V1)

| Code | HTTP | Maqsad |
|------|------|--------|
| `unauthorized` | 401 | JWT yo'q yoki noto'g'ri |
| `forbidden` | 403 | Auth bor, lekin huquq yo'q |
| `not_found` | 404 | Resource yo'q |
| `validation_error` | 422 | Pydantic validation fail |
| `seller_not_verified` | 403 | Verification approved emas |
| `tariff_limit_exceeded` | 402 | Mahsulot soni tariff limitidan oshdi |
| `seller_already_exists` | 409 | Onboarding 1:1 buzilgan |
| `payment_already_pending` | 409 | Tariff upgrade kutilmoqda |
| `insufficient_stock` | 400 | Order checkout race condition |
| `invalid_image_format` | 400 | Image upload format |
| `image_too_large` | 400 | >10 MB |
| `verification_already_in_progress` | 409 | Hujjat qayta yuborib bo'lmaydi |

---

## 5. Pagination

```dart
final response = await dio.get('/products', queryParameters: {
  'page': 1,
  'per_page': 20,
  'category': 'sofas',
});

final data = response.data['data'] as List;
final meta = response.data['meta'];
final hasNext = meta['has_next'] as bool;
```

Infinite scroll pattern: `BlocProvider` ichida page counter bilan.

---

## 6. Realtime (Supabase Channels — REST emas)

| Channel | Mode |
|---------|------|
| `public:orders:user_id=eq.<uuid>` | Customer |
| `public:orders:shop_id=eq.<uuid>` | Seller |

Tafsilot: [04-realtime.md](./04-realtime.md).

---

## 7. Storage upload

Mobile to'g'ridan-to'g'ri Supabase Storage'ga upload qiladi (Supabase SDK orqali):

```dart
final path = await Supabase.instance.client.storage
    .from('verification')
    .upload('user-id/passport_front.jpg', file);
```

Backend keyin URL'ni qabul qiladi (`POST /seller/verification/manual`).

Tafsilot: [11-storage-image-upload.md](./11-storage-image-upload.md).

---

## 8. Keyingi qadam

→ [08-customer-features.md](./08-customer-features.md) — customer flow ekranlari

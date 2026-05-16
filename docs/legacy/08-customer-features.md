# 08 — Customer Features

> Asl §1.2 customer parts. Har feature uchun ekran, BLoC, repository, va API endpoint xaritasi.

## Bottom navigation (V1)

```
[Home] [Catalog] [Cart] [Orders] [Profile]
```

> Favorites tab alohida emas, profile ostida (kichikroq UI).

---

## 1. Home (`customer/features/home/`)

### Tarkibi

- Banners carousel (`/banners`)
- "Featured shops" horizontal list (`/shops?featured=true`)
- "Featured products" (`/products?featured=true`)
- "Categories" grid — top-level (`/categories`)
- "Recently viewed" (Hive cache'dan)

### API

```
GET /banners
GET /shops?featured=true&per_page=10
GET /products?featured=true&per_page=20
GET /categories
```

### BLoC

```dart
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  // banners, featuredShops, featuredProducts, categories
}
```

---

## 2. Catalog (`customer/features/catalog/`)

### Tarkibi

- Top: search bar (tap → search screen)
- Category tree (drill-down)
- Filter sheet: price range, sort
- Product grid (2 column)
- Infinite scroll

### API

```
GET /products?category=<slug>&min_price=<int>&max_price=<int>&sort=<>&page=<>
```

V1'da advanced filters (rang, material, ...) yo'q — faqat narx va kategoriya.

---

## 3. Search (`customer/features/search/`)

### Tarkibi

- Recent searches (Hive cache)
- Search results (debounced 300ms)
- Empty state

### API

```
GET /products?search=<query>&page=<>
```

Backend `to_tsvector` GIN index'i bilan full-text search (uz/ru/en alohida indekslar).

---

## 4. Product Detail (`customer/features/product_detail/`)

### Tarkibi

- Image gallery (swipeable)
- Title, price (with old_price strikethrough)
- Shop card (logo, name, "Verified ✓" badge, telefon, Telegram)
- "Bu do'kon nima taklif qiladi" — shop_services list (icons)
- Description (multilingual rendering)
- Attributes (kategoriyaga xos)
- "Add to cart" / "Buy now"
- Favorites toggle (heart icon)

### API

```
GET /products/{slug}
GET /shops/{slug}                    # shop info
GET /shop-services?shop_id=<uuid>    # uchun shop_services join
POST /favorites/{product_id}
DELETE /favorites/{product_id}
POST /cart/items
```

### Shop services rendering

```dart
// shared/widgets/shop_services_block.dart
Widget build(BuildContext context, List<ShopService> services) {
  return Wrap(
    spacing: 8,
    children: services.where((s) => s.isEnabled).map((s) => Chip(
      avatar: Icon(parseIcon(s.serviceType.icon)),
      label: Text(s.customDescription?.get(lang) ?? s.serviceType.name.get(lang)),
    )).toList(),
  );
}
```

> Customer ↔ seller chat YO'Q (V1). `shop.contact_phone` va `shop.telegram_username` `tel:` / `https://t.me/...` link bilan ko'rsatiladi.

---

## 5. Cart (`customer/features/cart/`)

### Tarkibi

- Multi-shop bo'lsa shop bo'yicha grouped (har shop alohida bo'lim)
- Item: rasm, title, narx, quantity stepper, remove
- Bottom: total, "Buyurtma berish" tugma

### API

```
GET /cart
PATCH /cart/items/{id}
DELETE /cart/items/{id}
```

### Multi-shop checkout

Cart ichida 2 shop'dan mahsulot bo'lsa — 2 marta `POST /orders` chaqiriladi (har shop alohida order). UI checkout screen'ida user'ga aniq ko'rsatiladi.

---

## 6. Checkout (`customer/features/checkout/`)

### Steps

1. **Items review** — cart items per shop
2. **Delivery address** — `GET /me/addresses`, default selection, "Add new"
3. **Delivery method** — pickup / shop_delivery / courier (shop_services'ga qarab dynamic)
4. **Selected services** — har item uchun (assembly, warranty, ...)
5. **Payment** — V1'da faqat `cash_on_delivery`
6. **Confirm** — total, "Buyurtma berish"

### API

```
POST /orders
{
  "shop_id": "uuid",
  "items": [...],
  "delivery_method": "shop_delivery",
  "address_id": "uuid",
  "payment_method": "cash_on_delivery",
  ...
}
```

Multi-shop bo'lsa: per-shop loop bilan post.

### Empty state

Cart bo'sh bo'lsa: "Sevimli mebellaringizni qidirib toping. [Catalog'ga o'tish]"

---

## 7. Orders (`customer/features/orders/`)

### List

- Tabs: All | Active | Completed | Cancelled
- Item: order_number, shop, total, status badge, date
- Pull to refresh

### Detail

- Order info, status timeline, items, address, total breakdown
- "Cancel" tugma (faqat `pending` yoki `confirmed` holatida)
- Status update **realtime** — Supabase channel'dan keladi (04-realtime.md)

### API

```
GET /orders?status=<>&page=<>
GET /orders/{id}
POST /orders/{id}/cancel
```

---

## 8. Favorites (`customer/features/favorites/`)

Profile ostida (alohida tab emas):

```
GET /favorites
POST /favorites/{product_id}
DELETE /favorites/{product_id}
```

UI: product grid, "Bo'sh" empty state.

---

## 9. Profile (`customer/features/profile/`)

### Tarkibi

- Avatar + full_name (PATCH /me)
- Phone, email
- "Manzillar" → addresses CRUD
- "Sevimlilar" → favorites
- "Buyurtmalar" → orders (bottom nav bilan dublirlanadi, lekin shortcut)
- "Til" → easy_localization setLocale (PATCH /me preferred_language)
- "Sotuvchi bo'lish" — agar seller_profile yo'q
- "Sotuvchi rejimiga o'tish" — agar verified seller
- "Chiqish"
- "Akountni o'chirish" — `DELETE /me` confirm

### Mode switcher

```dart
ElevatedButton(
  onPressed: () async {
    await switchAppMode(context, AppMode.seller);
    // Phoenix.rebirth ichida
  },
  child: Text(tr('profile.switch_to_seller')),
)
```

---

## 10. Empty va Error states

Har screen uchun mas'uliyat:

- **Loading:** shimmer placeholder
- **Empty:** rasm + matn + CTA
- **Error:** rasm + matn + "Qayta urinish" tugma

`shared/widgets/empty_state.dart`, `shared/widgets/error_state.dart` reuseable.

---

## 11. Test pattern

```dart
testWidgets('ProductDetail shows shop services', (tester) async {
  when(mockProductRepo.fetchBySlug('sofa-1')).thenAnswer(
    (_) async => mockProduct,
  );

  await tester.pumpWidget(testApp(ProductDetailScreen(slug: 'sofa-1')));
  await tester.pumpAndSettle();

  expect(find.text('Bepul yetkazib berish'), findsOneWidget);
  expect(find.byIcon(Icons.local_shipping), findsOneWidget);
});
```

---

## 12. Keyingi qadam

→ [09-seller-features.md](./09-seller-features.md) — seller flow va onboarding

# Flutter App ROADMAP — Mebellar V2

> Sprint-bo'yicha batafsil amaliy reja. Har sprint **bir hafta** (haftada 35-40 soat). Acceptance criteria bilan — sprint tugaganda nima ishlashi kerakligi aniq.
>
> Asl manba: `docs/` papkasidagi 16 fayl + `mebellar_v2_tz.md` v2.2.

## Foydalanish

- Har sprint boshida: ushbu hujjatni o'qib, vazifalarni TaskList'ga ko'chirish
- Har task'ga checkbox — tugaganda `[ ]` → `[x]`
- Sprint oxirida: **Definition of Done** tekshirish, retro yozish (`docs/RETRO.md`)
- Scope creep'ga "yo'q"

## Tezkor navigatsiya

| Sprint | Maqsad | Davomi | Backend bilan sinxron |
|--------|--------|--------|------------------------|
| [Sprint 0](#sprint-0--tayyorgarlik) | Apple/Google account, design assets | 3-5 kun | Backend Sprint 0 parallel |
| — | (Backend Sprint 1+2 tugashini kutadi) | 2 hafta | Backend `GET /me` deploy bo'lguncha |
| [Sprint 1](#sprint-1--mobile-skeleton--auth) | Skeleton + login + GET /me | 1 hafta | Backend Sprint 2 tayyor |
| [Sprint 2](#sprint-2--mode-switching--di) | Dual-entry, scope, Phoenix.rebirth | 3-4 kun | — |
| [Sprint 3](#sprint-3--customer-home--catalog) | Home, categories, catalog, search | 1 hafta | Backend Sprint 3 |
| [Sprint 4](#sprint-4--product-detail--cart) | Product detail, cart, favorites | 1 hafta | Backend Sprint 4 |
| [Sprint 5](#sprint-5--checkout--orders) | Checkout, orders, realtime | 1 hafta | Backend Sprint 4 |
| [Sprint 6](#sprint-6--seller-onboarding--verification) | Onboarding form, hujjat upload | 1 hafta | Backend Sprint 5 |
| [Sprint 7](#sprint-7--seller-dashboard--products) | Dashboard, product CRUD, image gallery | 1 hafta | Backend Sprint 6 |
| [Sprint 8](#sprint-8--seller-orders--shop-settings) | Order fulfillment, shop, services | 1 hafta | Backend Sprint 6 |
| [Sprint 9](#sprint-9--tariff-upgrade-ux) | Tariff page, P2P payment sheet | 4-5 kun | Backend Sprint 7 |
| [Sprint 10](#sprint-10--cross-mode-notifications) | Push handling, pending route | 1 hafta | Backend Sprint 9 |
| [Sprint 11](#sprint-11--polish--qa) | Empty/error states, deep link, sentry | 1 hafta | Backend Sprint 11 |
| [Sprint 12](#sprint-12--launch-prep) | Store assets, submission | 1 hafta | Backend Sprint 12 |

**Jami:** ~12 sprint = **3 oy** (optimistik). **Realistik solo dev:** 5-6 oy.

---

## Definition of Done (har sprint uchun)

- [ ] Hamma vazifa kodi yozildi va PR merge bo'ldi
- [ ] Widget test'lar yozildi (kritik flow uchun)
- [ ] `flutter analyze` 0 issue
- [ ] Manual smoke test ikkala platforma'da (iOS sim + Android emulator)
- [ ] Real device test (kamida iOS yoki Android)
- [ ] `docs/` faylida tegishli o'zgarishlar yangilandi (agar arxitektura o'zgargan bo'lsa)
- [ ] Sprint retro yozildi

---

## Sprint 0 — Tayyorgarlik

**Maqsad:** Account'lar, design assets, environment config.

**Davomi:** 3-5 kun (backend Sprint 0 bilan parallel)

### Vazifalar

- [ ] **Apple Developer Program** ($99/yil — Individual yetadi V1)
  - Enrollment 1-3 kun, oldindan boshlash
  - APNs key generate (OneSignal uchun kerak)
- [ ] **Google Play Console** ($25 one-time)
  - Test account ham qo'shish (App Review uchun)
- [ ] **OneSignal app yaratish** (backend bilan parallel — Sprint 0)
  - iOS app + APNs key upload
  - Android app + FCM Server Key
- [ ] **Sentry account** — `mebellar-app` Flutter project, DSN saqlash
- [ ] **Universal Links / App Links uchun domain**
  - `https://mebellar.uz/.well-known/apple-app-site-association`
  - `https://mebellar.uz/.well-known/assetlinks.json`
  - DNS sozlash backend Sprint 0'da bajariladi
- [ ] **Design assets minimal**
  - App icon (1024×1024 PNG, ikkala mode uchun bir xil yoki farqli)
  - Splash screen
  - Bo'sh-state illustratsiyalar (cart bo'sh, hech order yo'q, ...)
  - Brand color: customer va seller uchun farqli
- [ ] **`pubspec.yaml` cleanup** — demo dependency'lar olib tashlash
- [ ] **`.env` strategy** — `--dart-define-from-file=env/dev.json` pattern
- [ ] **Bundle ID / package name finalizatsiyasi**
  - iOS: `uz.mebellar.app`
  - Android: `uz.mebellar.app`

### Acceptance criteria

- [ ] Empty Flutter app `flutter run` ishlaydi (iOS sim + Android emu)
- [ ] App Store Connect'da app draft yaratilgan
- [ ] Play Console'da app draft yaratilgan
- [ ] OneSignal'dan test push iOS sim'ga keladi (helloworld app)

### Risk

- **Apple Developer enrollment 2-3 kun olishi mumkin** — eng birinchi qilish
- **APNs key faqat 1 marta yaratiladi** — ehtiyot saqlash

---

## Sprint 1 — Mobile Skeleton + Auth

**Maqsad:** Login → `GET /me` → Customer yoki Seller app boot bo'ladi.

**Davomi:** 1 hafta

**Reference:** `docs/01-project-structure.md`, `docs/02-dual-entry-mode-switching.md`, `docs/06-auth-flow.md`

### Vazifalar

- [x] **Demo kod cleanup** — `lib/main.dart` demo'ni o'chirish, yangi tuzilishni tayyorlash
- [x] **`pubspec.yaml` dependencies (`docs/01-project-structure.md`)**
  - flutter_bloc, go_router, get_it, dio
  - supabase_flutter
  - hive_flutter, flutter_secure_storage
  - flutter_phoenix
  - easy_localization
  - onesignal_flutter
  - cached_network_image, image_picker, image
  - intl, equatable
  - sentry_flutter
- [x] **Loyiha tuzilmasi yaratish** (`lib/`):
  - [x] `core/` — di, network, storage, auth, theme, error, widgets, utils
  - [x] `core/notifications/` (Sprint 10'da to'liqlanadi, hozircha placeholder)
  - [x] `shared/` — models, repositories, widgets
  - [x] `customer/` — placeholder folder
  - [x] `seller/` — placeholder folder
  - [x] `auth/` — login, register, email verify
- [x] **`main.dart` — root scope setup** (`docs/02-dual-entry-mode-switching.md` §3)
  - [x] `initRootScope()` — Hive, Supabase, Dio, AuthRepository
  - [x] AppMode enum
  - [x] `getInitialMode()`
- [x] **Theme** (`core/theme/`)
  - [x] `customer_theme.dart` — Material 3, customer brand color
  - [x] `seller_theme.dart` — boshqa accent
- [x] **Localization setup** (`docs/12-localization.md`)
  - [x] `assets/translations/{uz,ru,en}.json` — common, auth keys
  - [x] `EasyLocalization.ensureInitialized()`
- [x] **Auth screens (`lib/auth/`)**
  - [x] `login_screen.dart` — email/password, "Forgot?", "Register"
  - [x] `register_screen.dart` — email, password, full_name, language picker
  - [x] `verify_email_screen.dart` — "Email'ni tekshiring, link orqali tasdiqlang"
  - [x] `forgot_password_screen.dart`
- [x] **AuthRepository (`core/auth/`)**
  - [x] `signUp`, `signIn`, `signOut`, `resetPassword`
  - [x] `fetchMe()` → `GET /api/v1/me`
- [x] **Dio interceptor** — Bearer token (`docs/06-auth-flow.md` §7)
- [x] **Customer va Seller skeleton App'lar**
  - [x] `customer/customer_app.dart` — placeholder MaterialApp + bottom nav
  - [x] `seller/seller_app.dart` — placeholder MaterialApp + bottom nav
- [x] **Initial mode chooser** — login muvaffaqiyatli bo'lganda
  - Agar `seller_profile.verification_status == 'approved'` → ModeChooserBottomSheet
  - Aks holda → customer
- [x] **Sentry init** — `core/error/sentry_setup.dart` (DSN bo'sh bo'lsa skip qiladi)
- [x] **Widget test** — mode chooser flow uchun (login UI test'i Sprint 2'da kengaytiriladi)

### Acceptance criteria

- [x] `flutter run --dart-define-from-file=env/dev.json` ishga tushadi — `flutter analyze` 0 issue, debug APK build muvaffaqiyatli
- [ ] Register → email verify (ground truth Supabase'da) → login → customer skeleton ochiladi *(Supabase project credentials kerak — `env/dev.json` to'ldirish)*
- [ ] Logged in user app'ni qaytadan ochsa, login skip bo'ladi va to'g'ri mode'ga boradi *(yuqoridagi credentials bilan birga manual test)*
- [ ] iOS + Android ikkalasida ham ishlaydi *(Android debug build PASS, iOS sim manual smoke kerak)*

### Risk

- **Supabase email link deep linking** — Universal/App Links sozlash 1-2 kun olishi mumkin. Fallback: email'da kod yuborish (yoki Supabase confirm link clicked → web sahifa "Endi appni oching")

---

## Sprint 2 — Mode Switching + DI

**Maqsad:** `switchAppMode` to'liq leak-free ishlaydi. Customer ↔ Seller switch test'dan o'tadi.

**Davomi:** 3-4 kun

**Reference:** `docs/02-dual-entry-mode-switching.md`

### Vazifalar

- [x] **Mode scope DI**
  - [x] `initModeScope(AppMode)` — pushNewScope + register
  - [x] `_registerCustomerDependencies()` — customer BLoC'lar (placeholder)
  - [x] `_registerSellerDependencies()` — seller BLoC'lar (placeholder)
- [x] **`switchAppMode(context, AppMode)`** — popScope → init → Phoenix.rebirth (splash overlay bilan)
- [x] **Dispose pattern misollari**
  - [x] `OrderTrackingService` (customer) — `RealtimeChannel.unsubscribe()` stub
  - [x] `NewOrdersListener` (seller) — `dispose()` stub
- [x] **ModeChooserBottomSheet UI** (Sprint 1'da yaratilgan)
- [x] **Profile screen mode switcher**
  - [x] Customer: "Sotuvchi rejimi" button (agar `seller_profile.isApproved`)
  - [x] Seller: "Xaridor rejimi" button
- [x] **Memory leak test** (widget test)
  - 10 marta switch → har scope service'i dispose bo'lgan, settings box hali ham ochiq
- [x] **`flutter_phoenix` integratsiyasi** — `main()` ichida `Phoenix(child: ...)` (Sprint 1)

### Acceptance criteria

- [x] Switch'dan keyin eski mode'ning servicelari `dispose()` chaqirilgan (`mode_switching_test.dart` — 6/6 PASS)
- [x] Switch'dan keyin Hive boxes (settings, cache, pending_route) hali ham ochiq (root scope)
- [x] 10 marta ketma-ket switch'da memory leak yo'q (avtomatik test)
- [ ] Customer mode'dan seller mode'ga 1 sekundan kam vaqtda o'tadi *(real device manual smoke kerak)*

### Risk

- **`Phoenix.rebirth()` ba'zi platformalarda flicker beradi** — splash overlay qo'shish (200ms)

---

## Sprint 3 — Customer Home + Catalog

**Maqsad:** Customer Home, Category, Catalog (filter, search, pagination) to'liq ishlaydi.

**Davomi:** 1 hafta

**Reference:** `docs/08-customer-features.md` §1-3, `docs/07-api-reference.md`

**Backend dependency:** Sprint 3 (catalog API) tugagan bo'lishi shart.

### Vazifalar

- [x] **Shared models**
  - [x] `shared/models/multilingual_text.dart`
  - [x] `shared/models/product.dart`
  - [x] `shared/models/shop.dart`
  - [x] `shared/models/category.dart`
  - [x] `shared/models/region.dart`
  - [x] `shared/models/banner.dart` (`HomeBanner` — Flutter `Banner` widget bilan to'qnashmaslik uchun)
  - [x] `shared/models/paginated.dart` — generic `Paginated<T>` API meta uchun
- [x] **Repositories**
  - [x] `shared/repositories/product_repository.dart` — list, getBySlug, search, `ProductFilter`, `ProductSort`
  - [x] `shared/repositories/category_repository.dart` — tree, getBySlug
  - [x] `shared/repositories/shop_repository.dart` — list, getBySlug
  - [x] `shared/repositories/banner_repository.dart` — list
  - [x] Hammasi root scope DI'da registratsiya qilingan
- [x] **Customer router** (`customer/router.dart`) — go_router (deep link query params: `/catalog?category=...`)
- [x] **Customer bottom navigation** — Home, Categories, Cart, Orders, Profile (Cart/Orders Sprint 4-5)
- [x] **Home screen**
  - [x] HomeBloc — banners, featured shops, featured products, categories
  - [x] BannerCarousel widget (page indicators bilan)
  - [x] FeaturedShopsList horizontal
  - [x] FeaturedProductsGrid (ProductCard reuse)
  - [x] CategoriesGrid
  - [x] Pull to refresh
  - [x] Shimmer loading state
- [x] **Category drill-down**
  - [x] CategoriesScreen — top-level
  - [x] Sub-category recursive navigation (`SubCategoryScreen`)
- [x] **Catalog (product list)**
  - [x] CatalogScreen — filter sheet (price range, sort)
  - [x] ProductGrid widget (2-column)
  - [x] Infinite scroll (CatalogBloc + ScrollController, 600px threshold)
  - [ ] Scroll pozitsiyasini saqlash (Scroll position restoration) va kesh prompti — foydalanuvchi mahsulot ichiga kirib orqaga qaytganda ro'yxat eng tepaga sakrab ketmasligi kerak.
- [x] **Search**
  - [x] SearchScreen — debounced input (`_DebounceTransformer`, 300ms)
  - [x] Recent searches (Hive `cache` boxida)
  - [x] Empty results state
- [x] **Shared widgets**
  - [x] `shared/widgets/product_card.dart` (sale badge + favorite toggle bilan)
  - [x] `shared/widgets/product_card_skeleton.dart` (shimmer)
  - [x] `shared/widgets/shimmer_placeholder.dart`
  - [x] `shared/widgets/empty_state.dart`
  - [x] `shared/widgets/error_state.dart`

### Acceptance criteria

- [x] Home screen banner, featured products, kategoriyalar ko'rinadi (BLoC + ErrorState fallback)
- [x] Catalog filter (narx, sort) ishlaydi va URL'ga sinxron (`/catalog?category=...&search=...`)
- [x] Search 300ms debounce — `_DebounceTransformer` `EventTransformer` orqali
- [x] Backend ishlamasa `ErrorState` + retry tugma har screen'da
- [ ] 100 mahsulot ichida scroll smooth (60fps) *(real device profile kerak)*

---

## Sprint 4 — Product Detail + Cart

**Maqsad:** Product detail to'liq, cart CRUD, favorites.

**Davomi:** 1 hafta

**Reference:** `docs/08-customer-features.md` §4, §5, §8

### Vazifalar

- [x] **Product detail screen**
  - [x] Image gallery (swipeable, hero animation, fullscreen tap to zoom)
  - [x] Title + price + old_price (strikethrough)
  - [x] ShopCard widget — logo, name, "Verified ✓", phone (`tel:`), Telegram link
  - [x] **Shop services block** — `ShopServicesBlock` (chip list with icons)
  - [x] Description (multilingual, "Show more" expansion)
  - [x] Attributes (kategoriyaga xos, key-value)
  - [x] Add to cart button (with quantity stepper)
  - [x] Buy now (skip cart, navigatsiya `/cart`'ga)
  - [x] Favorites toggle (heart, optimistic update via FavoritesBloc)
- [x] **Cart screen**
  - [x] CartBloc — repository-backed sync (mock + Remote stubs)
  - [x] Multi-shop grouping (har shop bo'limi alohida card'da)
  - [x] Item: thumbnail, title, price, quantity stepper, swipe-to-remove
  - [x] Total per shop + grand total
  - [x] "Buyurtma berish" tugma (Sprint 5 placeholder — multi-shop banner bilan)
  - [x] Empty state: "Sevimli mebellaringizni qidiring [Catalog]"
- [x] **Favorites**
  - [x] FavoritesBloc — repository-backed
  - [x] Profile ostida ListTile orqali (`/favorites` route)
  - [x] Product grid + remove
- [x] **Cart repository**
  - [x] addItem(productId, quantity)
  - [x] updateQuantity(itemId, quantity)
  - [x] removeItem(itemId)
  - [x] Optimistic UI update + rollback on error (CartBloc)

### Acceptance criteria

- [x] Product detail rasmlar gallery'da, swipe + page indicator ishlaydi
- [x] Shop services chip'lar to'g'ri icon bilan ko'rsatiladi
- [x] Cart'ga qo'shish (mock backend'ga yoziladi) va UI darhol yangilanadi (CartBloc + bottom-nav badge)
- [x] Multi-shop cart UI'da grouping — har shop alohida card

---

## Sprint 5 — Checkout + Orders

**Maqsad:** Checkout flow + order tracking + realtime status update.

**Davomi:** 1 hafta

**Reference:** `docs/08-customer-features.md` §6-7, `docs/04-realtime.md`

### Vazifalar

- [x] **Address management**
  - [x] `customer/features/profile/addresses/` — list, add, edit, delete (popup menu + dismissible)
  - [x] Region picker — drill-down (viloyat → shahar → tuman, search bar bilan)
  - [x] Map widget (lat/lng tap) — V1 placeholder `MapPreview` (Sprint 11 paid SDK)
- [x] **Checkout flow**
  - [x] CheckoutBloc — multi-step state machine
  - [x] Step 1: items review (per shop)
  - [x] Step 2: address selection (default avto-tanlash)
  - [x] Step 3: delivery method (per shop: standard / express / pickup)
  - [ ] Step 4: payment method (V1: cash_on_delivery yoki P2P — UI'da hech qanday plastik karta kiritish maydonlari chizilmaydi, murakkablikni oldini olish uchun faqat oddiy radio button bo'ladi).
  - [x] Step 5: confirm — totals + multi-shop banner
  - [x] **Multi-shop split** — har shop uchun alohida `POST /orders`
  - [x] Loading + error handling (`insufficient_stock` 5% mock chance)
- [x] **Orders list**
  - [x] OrdersBloc — tabs (All, Active, Completed, Cancelled)
  - [x] OrderTile — order_number, shop, total, status badge, thumbnails
  - [x] Pull to refresh
- [x] **Order detail**
  - [x] OrderDetailBloc
  - [x] Status timeline widget (`OrderStatusTimeline`)
  - [x] Items list, shop info, address, cancellation reason banner
  - [x] Cancel button (faqat `pending`/`confirmed` — reason input dialog)
- [x] **Realtime integratsiyasi**
  - [x] `OrderRepository.watch(orderId)` — Stream (mock: pending → confirmed → preparing har 8s)
  - [x] OrderDetailBloc'da subscribe
  - [x] Status update kelganda timeline UI yangilanadi (live indikator)
  - [x] `OrderTrackingService` — connection state stream (Supabase subscribe callback)
- [x] **Empty/error states** — har screen'da

### Acceptance criteria

- [x] Cart 2 shop'dan mahsulot bilan checkout → 2 ta order yaratiladi (per-shop loop, har biriga alohida POST)
- [x] Order detail ekraniga kirilganda mock 8s'dan keyin status update streamlanadi va timeline yangilanadi
- [x] Cancel — faqat `pending`/`confirmed` holatida tugma ko'rinadi (cancellable getter)
- [x] Address picker — region tree mock'dan keladi (Hive cache 2-step backendga sinxronlanganda)

### Risk

- **Realtime ulanish ba'zan uziladi** — `connectionState` listen va "Ulanish kutilmoqda" indicator
- **Multi-shop checkout error handling** — agar 1-shop muvaffaqiyat, 2-shop fail bo'lsa? Decision: birinchisi success bo'lib qoladi, foydalanuvchiga "1 ta order yaratildi, 2-shop'da xatolik" deb ko'rsatish

---

## Sprint 6 — Seller Onboarding + Verification

**Maqsad:** Customer'dan seller'ga o'tish flow, hujjat upload, status tracking.

**Davomi:** 1 hafta

**Reference:** `docs/09-seller-features.md` §1-2, `docs/11-storage-image-upload.md`

**Backend dependency:** Sprint 5 (onboarding API) tugagan.

### Vazifalar

- [x] **OnboardingBloc** — multi-step state machine + draft autosave (350ms debounce)
- [x] **Multi-step form**
  - [x] Step 1: Welcome screen — bullet points + storefront ikona
  - [x] Step 2: Yuridik holat (radio: individual / self_employed / llc / corporation)
  - [x] Step 3: Shaxsiy ma'lumot (legal_name, contact_phone, contact_email, telegram)
  - [ ] Step 4: Do'kon ma'lumoti (V1 da interaktiv xaritadan voz kechiladi. O'rniga faqat Dropdown [Viloyat → Tuman] va ko'cha nomi uchun oddiy Text Field ishlatiladi).
  - [x] Step 5: Verification choice (now / later)
  - [x] Step 6: Done — "Sotuvchi rejimiga o'tish" → `switchAppMode(seller)`
- [x] **Save progress** — Hive box `onboarding_draft`, har step'da debounced save
- [x] **`POST /seller/onboarding`** — `MockSellerOnboardingRepository.submit` + Remote stub
- [x] **Verification screen**
  - [x] VerificationBloc — documents stream + status stream
  - [x] Status banner (none/pending/in_review/approved/rejected) + rejection reason
  - [x] Upload widget — passport_front, passport_back, selfie_with_passport
  - [x] business_type'ga qarab qo'shimcha (LLC/JSC: business_certificate + tax_id)
  - [x] Image picker (camera + gallery via bottom sheet)
  - [x] Mock storage upload (Supabase wired in remote stub for Sprint 6 backend)
  - [x] Submit `POST /seller/verification/manual` (mock advances pending → in_review 6s)
  - [x] Re-submit (rejected status) — uploads unlocked, "Resubmit" CTA
- [x] **Image upload helper (`shared/utils/image_upload.dart`)**
  - [x] Format check (JPEG/PNG/WEBP) — `ImagePickConfig.allowedExtensions`
  - [x] Size check (max 10 MB) — `ImagePickError`
  - [x] Resize (image_picker maxWidth=2048, quality=85)
- [x] **Seller skeleton boot**
  - [x] Verified: dashboard with KPI cards (placeholder values for Sprint 7)
  - [x] Pending/rejected/none: banner + verification CTA, gated tabs

### Acceptance criteria

- [x] Customer "Sotuvchi bo'lish" → 6-step wizard → submit → seller mode'ga o'tadi
- [x] Step'larda app'ni yopib qaytib kelgan foydalanuvchi joyidan davom etadi (Hive draft + lastStep)
- [x] Hujjat upload paytida loading indicator (`uploading` flag, per-tile spinner)
- [x] Submit'dan keyin pending banner ko'rinadi (mock 6s'dan keyin in_review'ga o'tadi)
- [x] Upload xato bo'lsa snackbar — retry tugma orqali qayta tanlash mumkin

### Risk

- **Region picker UX** — 14 viloyat × shahar × tuman ko'p, search bilan yengillashtirish

---

## Sprint 7 — Seller Dashboard + Products

**Maqsad:** Seller dashboard KPI, mahsulot CRUD, image gallery.

**Davomi:** 1 hafta

**Reference:** `docs/09-seller-features.md` §3-4, `docs/11-storage-image-upload.md`

**Backend dependency:** Sprint 6 (seller ops API) tugagan.

### Vazifalar

- [x] **Seller shell** — `seller_app.dart` SellerHomeShell (gating bilan)
- [x] **Seller bottom nav** — Dashboard, Products, Orders, Analytics, Profile (lock ikonalari approved emas paytda)
- [x] **Dashboard screen**
  - [x] DashboardBloc — snapshot + new order stream
  - [x] Verification status banner (approved emas → boshqa tablar lock)
  - [x] KPI cards — bugungi orders, revenue, pending, active products / tariff limit
  - [x] "Yangi orderlar" top 5 (`_RecentOrderTile`)
  - [x] Realtime new order subscribe (`MockSellerDashboardRepository.newOrders` har 25s)
  - [x] Yangi order kelganda haptic (`HapticFeedback.mediumImpact`) + snackbar
- [x] **Products list**
  - [x] SellerProductsBloc — repo stream'iga subscribe
  - [x] Filter (multi-select chip: draft/pending/approved/rejected/archived)
  - [x] Search bar (name + SKU)
  - [x] FAB "+" → create
- [x] **Product create/edit**
  - [x] Multi-step form (6 step)
  - [x] Step 1: Name + description (multilingual tabs uz/ru/en)
  - [x] Step 2: Category picker (drill-down) + dynamic attributes (parent category bo'yicha)
  - [x] Step 3: Price + stock + SKU + old_price
  - [x] Step 4: Image gallery
  - [x] Step 5: Dimensions (length/width/height/weight)
  - [x] Step 6: Final review + "Save draft" / "Submit for review"
- [x] **Image gallery widget**
  - [x] Multi-image picker (max 10) — `ImageGalleryEditor`
  - [x] Drag reorder (`ReorderableListView` + custom drag handle)
  - [x] Primary image toggle (yulduzcha + tagi)
  - [x] Delete confirmation dialog
  - [x] Upload progress per image (25/50/75/100% steps + overlay spinner)
- [x] **Tariff limit error handling**
  - [x] `TariffLimitException` → `showTariffLimitDialog` AlertDialog
  - [x] "Pro tarifiga o'tish" CTA (Sprint 9 placeholder snackbar)
- [x] **Analytics (basic)**
  - [x] Sales line chart — custom `RevenueLineChart` (CustomPainter, fl_chart'siz)
  - [x] Top products list (recent orders'dan aggregate)

### Acceptance criteria

- [x] Pending verification'dagi seller dashboard ochsa, banner ko'rinadi va Products/Orders/Analytics tablari lock'lanadi
- [x] Approved seller mahsulot qo'shadi → mock'da `pending_review` (8s'dan keyin avto-approve)
- [x] Image gallery drag reorder ishlaydi (`ProductFormImagesReordered`), primary toggle yulduzcha bilan saqlanadi
- [x] Tariff limit chiqsa, `showTariffLimitDialog` "Pro tarifiga o'tish" CTA bilan ochiladi
- [ ] Seller Dashboard'dagi mahsulotlar ro'yxatida `pending_review` holatidagi mahsulotlar uchun aniq ko'rinib turuvchi 'Moderatsiya kutilmoqda' sariq yorlig'i (badge) ko'rsatilishi shart.

---

## Sprint 8 — Seller Orders + Shop Settings

**Maqsad:** Order fulfillment to'liq, shop settings, services config.

**Davomi:** 1 hafta

**Reference:** `docs/09-seller-features.md` §5-6

**Backend dependency:** Sprint 6 (seller ops API).

### Vazifalar

- [x] **Orders list**
  - [x] SellerOrdersBloc — 4 tab (newTab/active/done/cancelled)
  - [x] Realtime `INSERT` (mock 25s timer) — list'ga avtomatik qo'shiladi
  - [x] "Yangi" tab'ga `Badge.count` (`unreadNewIds`)
- [x] **Order detail (seller side)**
  - [x] SellerOrderDetailBloc
  - [x] State machine action buttons (`SellerOrderTransitions` extension):
    - `pending` → [Tasdiqlash] [Bekor qilish]
    - `confirmed` → [Tayyorlanmoqda] [Yuborilgan] [Bekor qilish]
    - `preparing` → [Yuborilgan] [Bekor qilish]
    - `shipped` → [Yetkazildi] [Bekor qilish]
    - terminal states: read-only
  - [x] Customer kontakt (telefon, address) — `tel:` orqali qo'ng'iroq
  - [x] Cancel reason input (text dialog)
- [x] **Shop settings**
  - [x] ShopSettingsBloc
  - [x] Logo / cover upload (mock URL synthesis)
  - [x] Multilingual name/description editor (uz/ru/en tabs)
  - [x] Brand color picker — custom `pickBrandColor` (12 swatch + HSV slider)
  - [x] Address + region picker (mavjud `RegionPickerScreen`)
  - [x] Working hours — `WorkingHoursEditor` (har kun uchun TimePicker + closed switch)
  - [x] Visibility toggle (`public` / `hidden`)
- [x] **Services configuration**
  - [x] ServicesBloc
  - [x] 6 ta service_type (free_delivery, assembly, warranty, installment, express, custom_order)
  - [x] Per-service Switch
  - [x] Per-service config (min_order_amount, fee_amount, warranty_months, installment_months)
  - [x] Bulk save (`SellerServicesRepository.save`)
- [x] **Seller profile**
  - [x] Shop info link (Shop settings'ga)
  - [x] Verification link
  - [x] Tariff link (Sprint 9 placeholder snackbar)
  - [x] "Xaridor rejimi" → `switchAppMode(customer)`
  - [x] Logout

### Acceptance criteria

- [x] Yangi order kelganda mock dashboard list'ga avtomatik qo'shiladi (realtime)
- [x] State machine: pending → confirmed → preparing → shipped → delivered tartibi enforced ([SellerOrderTransitions](lib/shared/repositories/seller_order_repository.dart))
- [x] Cancel orderda reason yoziladi va `OrderStatusEvent.note` ga saqlanadi
- [x] Shop visibility `hidden`'ga o'zgartirilsa, snapshot persist qilinadi (Customer catalog'da hide qilish — Sprint 11 polish)

---

## Sprint 9 — Tariff Upgrade UX

**Maqsad:** P2P pul o'tkazma flow to'liq UX.

**Davomi:** 4-5 kun

**Reference:** `docs/10-tariff-upgrade-ux.md`

**Backend dependency:** Sprint 7 (tariff API).

### Vazifalar

- [x] **Tariff page**
  - [x] TariffBloc — list + current + pending watch + history
  - [x] Tariff cards (Free/Basic/Pro/Enterprise) — `TariffCard` widget
  - [x] "JORIY ✓" badge (current plan)
  - [x] "⭐ TAVSIYA" badge (Pro recommended)
  - [x] Monthly/Yearly toggle (`PeriodToggle` + `−17%` save chip)
- [x] **Payment Instructions Bottom Sheet**
  - [x] Tariff narxi (header)
  - [x] Karta raqami widget (gradient card, tap → Clipboard)
  - [x] "SHOP-{shop_id}" izoh ListTile + alohida copy button
  - [x] "📋 Karta raqamini ko'chirish" — snackbar
  - [x] "📸 To'lov skrinshotini yuklash" — image picker (resize/quality enforced)
  - [x] Telegram alternativ tugma (`tg://resolve?domain=MebellarSupportBot`)
- [x] **Skrinshot upload flow**
  - [x] Image picker → 2048px max + 85% quality (`ImageUploadHelper`)
  - [x] Mock URL synth (`payments/upgrade-{ts}.{ext}`); Remote stub holds the contract
  - [x] Loading state (per-image overlay spinner)
  - [x] Success → `Navigator.pop(subscription)` → `TariffPendingScreen`
- [x] **Pending status screen**
  - [x] "⏳ To'lov tasdiqlash kutilmoqda" headline
  - [x] 24h SLA real-time countdown (per-second ticker)
  - [x] "Joriy tarif amal qilishda davom etadi" hint
  - [x] [Tarix] tugma + [Bekor qilish] tugma (cancellable while pending)
- [x] **Approval/Rejection handler (mock)**
  - [x] Approved (12s) → success dialog + tariff page refresh
  - [x] Rejected → rejection_reason dialog + retry CTA
  - Sprint 10 da real OneSignal push subscription ulanadi
- [x] **Tariff history** — `TariffHistoryScreen` (status chip + amount + date)

### Acceptance criteria

- [x] Free seller "Pro tarifiga o'tish" → bottom sheet → karta raqami clipboard'da (visual feedback: snackbar)
- [x] Skrinshot upload → mock storage URL yaratiladi → submit → pending status
- [x] Mock admin 12s'dan keyin tasdiqlaydi/rad qiladi → pending screen avto-yangilanadi va dialog ko'rsatiladi

---

## Sprint 10 — Cross-mode Notifications

**Maqsad:** OneSignal handler + cross-mode pending route + cold start. 6 holat (5.6.4 jadvali) test'dan o'tadi.

**Davomi:** 1 hafta

**Reference:** `docs/05-notifications-deep-linking.md`

**Backend dependency:** Sprint 9 (push notifications).

### Vazifalar

- [ ] **OneSignal SDK setup** (Sprint 11 polish — real device push uchun)
  - [ ] iOS APNs config
  - [ ] Android FCM config
  - [ ] User identification (Supabase user_id ni external_id sifatida)
- [x] **NotificationHandler (`core/notifications/notification_handler.dart`)**
  - [x] `handleTap(notification)` — payload mode + route routing
  - [x] Mode mos: direct push (caller context bilan)
  - [x] Mode farqli: pending_route saqlash + `switchAppMode` post-frame
- [x] **Pending route consumption**
  - [x] CustomerApp + SellerApp `_consumePendingRoute()` — Sprint 1'dan beri ishlaydi
  - [x] Stale check 5 daqiqa (`NotificationHandler._staleAfter`)
  - [x] Defensive guards (mode mismatch, ts parse failure)
- [x] **Cold start handling**
  - [x] `NotificationHandler.peek()` — main() boot paytida saqlangan payload'ni ko'rib, initial mode override qilish uchun
  - [x] Sprint 11 da real OneSignal `getInitialNotification()` ulanadi
- [x] **Foreground vs Background listeners (mock)**
  - [x] `MockNotificationsRepository` har 45s timer bilan yangi push simulyatsiya qiladi (foreground)
  - [x] Simulator screen 6 holatni qo'lda firepenade'ga ruxsat beradi
- [x] **Manual test (6 holat — Notification simulator screen)**
  - [x] App ochiq, mode mos — `tapForeground` → direct nav
  - [x] App ochiq, mode farqli — `tapForeground` → switchAppMode + consume
  - [x] App fonda, mode mos — `stashOnly` → consume on resume
  - [x] App fonda, mode farqli — `stashOnly` → consume after mode switch
  - [x] App butunlay yopiq, mode mos — `coldStart` → boot consumes
  - [x] App butunlay yopiq, mode farqli — `coldStart` → boot switches mode + consumes
- [x] **Notification badge** — Customer Profile tab + ikkala AppBar'da bell icon (per-mode `Badge.count`)
- [x] **In-app notification list** — shared `NotificationsScreen` (customer + seller `mode` filter bilan)

### Acceptance criteria

- [x] **6 holat test'i** — `NotificationSimulatorScreen` ikkala mode'dan chaqirilib, har bir holat uchun snackbar tasdiqlovchi natija beradi
- [x] App butunlay yopiq holatda saqlangan pending route + app_mode override boot paytida `peek()` orqali tekshiriladi va target mode'ga o'tiladi
- [x] Stale 5+ daqiqa pending — `consumeFor` `null` qaytaradi va saqlanganni tozalaydi (test: `stale routes are discarded`)
- [x] Unread badge realtime yangilanadi (`NotificationsRepository.watchUnread(mode:)` + `Badge.count` AppBar action)

### Risk

- **iOS background mode delivery** — App Store reviewer test qilishi mumkin, `UNUserNotificationCenter` config to'g'ri bo'lishi shart
- **Android 13+ notification permission** — runtime permission so'rash

---

## Sprint 11 — Polish + QA

**Maqsad:** Empty/error states, performance, deep link, sentry, internal testing.

**Davomi:** 1 hafta

**Reference:** `docs/13-security.md`

### Vazifalar

- [x] **Empty/error states har screen'da** — `EmptyState`/`ErrorState` widgetlari Sprint 3'dan beri har feature'ga (catalog, cart, favorites, orders, addresses, products, services, tariff history) tarqatildi
- [x] **Performance audit (kod-darajasidagi)**
  - [x] List'larda `const` + `ListView.builder` + item key'lar
  - [x] `cached_network_image` har joyda placeholder + errorWidget bilan
  - [x] `BlocBuilder.buildWhen` + `BlocSelector` — Customer ProductCard, Dashboard KPI, NotificationsBloc
  - [x] Hive cache wrapper — `CacheStore` (TTL + invalidate prefix)
  - DevTools profile + Lighthouse-class measurements: Sprint 12 internal QA
- [x] **Offline behavior (mock)**
  - [x] `ConnectivityService` (mock + remote stub) — `MockConnectivityService.overrideStatus`
  - [x] `CacheStore` JSON wrapper bilan cached fetch fallback uchun tayyor
  - [x] `OfflineBanner` widget — Customer + Seller shell top'ida AnimatedSize
- [x] **Deep linking**
  - [x] `DeepLinkService.parse` — `mebellar://orders/abc`, `https://mebellar.uz/...`, `mebellar://seller/...` patterns
  - [x] Customer shell deep link listener — same-mode → `_router.go`, cross-mode → save pending route
  - Real OS-level App Links wiring (`uni_links`) — Sprint 12
- [x] **Sentry integratsiyasi**
  - [x] `initSentry` (Sprint 1'dan beri) + 0 DSN bo'lsa skip
  - [x] `tagSentryAppMode` — `switchAppMode` har chaqiruvda tag yozadi
  - [x] `identifySentryUser` / `clearSentryUser` — user_id only (PII narrow)
  - [x] PII redaction — Authorization/Cookie header drop + sensitive payload keys
- [ ] **Code obfuscation va symbol upload** — Sprint 12 release flow
- [ ] **Translation review** — uz/ru native speaker pass: Sprint 12
- [ ] **Internal testing** — TestFlight + Play Internal: Sprint 12 release flow
- [x] **Onboarding tutorial** — `CustomerTutorialScreen` 3 slide, first-launch Hive flag (`tutorial_seen_v1`), Skip CTA
- [ ] **Force Update (Majburiy yangilash) mexanizmi** — App boot bo'lganda backend'dan (`/api/v1/app-config`) `min_version` ni tekshirish va versiya eski bo'lsa, foydalanuvchini do'konga yo'naltiruvchi bloklovchi oyna (blocking screen) chiqarish.
- [ ] **Account Deletion (Akkauntni o'chirish)** — Apple App Store talabiga ko'ra, Profile sozlamalarida ochiq-oydin ko'rinadigan 'Akkauntni o'chirish' tugmasini qo'shish va u bosilganda backend'da ishonchli soft-delete (`deleted_at`) jarayonini ta'minlash.

### Acceptance criteria

- [ ] App size <50 MB (Android), <100 MB (iOS) — Sprint 12 release build
- [ ] Cold start time <3 sekund — Sprint 12 device QA
- [ ] Sentry'da crash-free sessions >99.5% (TestFlight'da) — Sprint 12
- [ ] 5 ta tester'dan kamida 3 tasi "ishlatish oson" javobi — Sprint 12 internal testing
- [ ] App version eski bo'lganda Force Update ekrani chiqishi test qilindi.
- [ ] Akkauntni o'chirish funksiyasi rostdan ham bazada `deleted_at` ni to'ldirishi tasdiqlandi.

---

## Sprint 12 — Launch Prep

**Maqsad:** App Store + Play Store submission.

**Davomi:** 1 hafta

### Vazifalar

- [ ] **App Store assets**
  - [ ] Screenshots (6.7", 5.5", iPad — har biri 3-5 ta)
  - [ ] App preview video (optional, lekin tavsiya)
  - [ ] App icon (1024×1024)
  - [ ] Description (uz/ru/en)
  - [ ] Keywords
  - [ ] Categories
  - [ ] Privacy Policy URL — `https://mebellar.uz/privacy`
  - [ ] Support URL
- [ ] **Play Store assets**
  - [ ] Feature graphic (1024×500)
  - [ ] Screenshots (phone + tablet)
  - [ ] Description
  - [ ] Categories
  - [ ] Content rating
  - [ ] Data safety form (privacy)
- [ ] **Privacy policy + ToS in-app**
  - Profile → "Sirlilik siyosati" / "Foydalanish shartlari"
  - WebView yoki external browser
- [ ] **Onboarding tutorial**
  - 3-4 slides birinchi marta foydalanuvchiga
  - Skip tugma
  - Hive flag — once shown, hech qachon ko'rinmaydi
- [ ] **Final QA** — production backend bilan smoke test
- [ ] **App Store submission** (review 1-3 kun)
- [ ] **Play Store submission** (review 1-2 kun)
- [ ] **Coordinated launch** — backend Sprint 12 deploy + mobile app live

### Acceptance criteria

- [ ] Apple App Review pass
- [ ] Play Store published
- [ ] Pilot foydalanuvchilar (Sprint 11'dagi 5 ta) production app'da test qiladi
- [ ] Real order ishlash zanjirini boshidan oxirigacha o'tdi

### Risk

- **Apple App Review reject** — sabablar:
  - Account deletion'siz `DELETE /me` (Sprint 11'da implement qilingan)
  - Location permission justification
  - Test account yaratib berish (review uchun)
- **Play Store data safety form** — har permission'ni izohlash kerak

---

## Sinxron point'lar (Backend bilan)

| Mobile Sprint | Backend Sprint kutadi | Sinxron deliverable |
|---|---|---|
| Sprint 0 | Sprint 0 (parallel) | OneSignal app, Sentry account |
| Sprint 1 | **Sprint 1+2** | `GET /me` ishlaydi (staging) |
| Sprint 2 | — | Mobile-only |
| Sprint 3 | **Sprint 3** | Catalog API contract |
| Sprint 4-5 | **Sprint 4** | Cart, orders, addresses |
| Sprint 6 | **Sprint 5** | Onboarding + verification |
| Sprint 7-8 | **Sprint 6** | Seller ops |
| Sprint 9 | **Sprint 7** | Tariff API |
| Sprint 10 | **Sprint 9** | Push notifications, cross-mode test |
| Sprint 11 | **Sprint 11** | Production env, monitoring |
| Sprint 12 | **Sprint 12** | Coordinated launch |

> **Critical path:** Mobile Sprint 1 backend Sprint 2 tugashini kutadi (2 hafta). Bundan keyin parallel ishlanadi.
>
> **Tavsiya:** API contract'ni Postman collection sifatida saqlash — backend dasturchi har endpoint'ni Postman'da test qilib, mobile dasturchiga "tayyor" deb belgilashi mumkin.

---

## Risk va contingency

| Risk | Sprint | Plan B |
|------|--------|--------|
| Apple Developer enrollment kechikish | 0 | Android'dan boshlash, iOS keyinroq |
| Universal/App Links sozlashda muammo | 1 | Email link → web sahifa "App'ni oching" fallback |
| Memory leak `popScope`'da | 2 | DevTools'da audit, `dispose` callbacks tekshirish |
| Realtime ulanish flaky | 5 | "Yangilash" tugma manual fetch |
| Region picker UX (14 viloyat × ko'p) | 6 | Search bar + recent picks |
| Image upload timeout | 7 | Chunked upload (V2), retry logic |
| Cross-mode notification iOS background | 10 | UNUserNotificationCenter config + manual test |
| App Store reject | 12 | Reject sababini hal qilib qayta yuborish (1-2 hafta delay) |

---

## Sprint retro shabloni (`docs/RETRO.md`)

```markdown
## Sprint X — YYYY-MM-DD

### Yaxshi nima ketdi
-

### Qiyin bo'ldi
-

### Scope o'zgarishi
- Qo'shildi:
- Olib tashlandi:
- Keyingi sprint'ga ko'chirildi:

### Yangi qarorlar (docs'ga qo'shilishi kerak)
-

### Backend bilan sinxron muammo
-

### Keyingi sprint'ga risk
-
```

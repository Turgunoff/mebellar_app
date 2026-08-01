# Woody V2 — To'liq Texnik Topshiriq

**Versiya:** 2.1 (Greenfield Rewrite + Architectural Refinements)
**Sana:** 2026-05-01
**Status:** Architecture Specification (Review v1.1 applied)
**Muallif:** Eldor Turg'unov

> **v1.0 → v2.1 o'zgarishlar:** Auth race condition (DB trigger), GetIt scope/dispose pattern, hosting region requirement, signed URL caching. Tafsilotlar: **§19**.

---

## 0. Executive Summary

Woody — O'zbekistondagi mebel marketplace platformasi. Ikki tomonli (two-sided) marketplace: xaridorlar (customer) va sotuvchilar (seller). Loyiha hozirgacha Play Store / App Store ga chiqarilmagan, shuning uchun **greenfield rewrite** qilish iqtisodiy va texnik jihatdan asoslangan — eski kod bilan parallel ishlash, migration data va backward compatibility kabi muammolar yo'q.

**Asosiy texnologik qarorlar:**

| Layer | Texnologiya | Sabab |
|-------|-------------|-------|
| Mobile | Flutter (single project, dual entry-point) | Bitta loyiha, ikki MaterialApp — restart pattern bilan mode switch |
| Backend | Python + FastAPI | Async, type-safe, OpenAPI auto-gen, AI/ML uchun future-proof |
| Database | Supabase (Postgres) | Managed Postgres + Auth + Storage + Realtime |
| Auth | Supabase Auth (email/password birinchi faza) | Phone OTP keyingi fazada |
| Storage | Supabase Storage (S3-compatible) | Rasmlar, hujjatlar, passport scanlari |
| Verification | Manual + MyID (2-fazada) | MyID API approval kutilayotganda manual fallback |
| Realtime | Supabase Realtime (Postgres CDC) | Order status updates, chat |
| Push | OneSignal | Mobile push, free tier yetarli |
| Admin | Web admin (Next.js) + Telegram bot | Web — bulk operations, bot — tezkor amallar |
| Hosting | Backend: Railway/Fly.io, Web: Vercel | Solo dev uchun managed |

**Asosiy biznes-modeli:**
- Xaridorlar uchun bepul marketplace
- Sotuvchilar uchun **subscription tariff** (Free / Basic / Pro / Enterprise)
- Har sotuvchi turli **xizmatlar** taklif qila oladi (yetkazib berish, montaj, garantiya, custom buyurtma)
- Verification orqali ishonchli sotuvchilarni ajratish

---

## 1. Maqsad va Scope

### 1.1 Asosiy maqsadlar

1. **MVP-first yondashuv**: birinchi versiya minimal, lekin production-ready bo'lsin
2. **Solo dev maintainability**: bitta odam tomonidan boshqarib bo'ladigan stack
3. **O'zbekiston bozoriga moslashish**: uz/ru/en til, MyID, mahalliy to'lov tizimlari (kelajakda)
4. **Marketplace asosi**: bir nechta sotuvchi, har xil tariff va xizmatlar
5. **Verification trust**: tasdiqlanган sotuvchilar va anonim sotuvchilar farqi aniq

### 1.2 V1 (MVP) ichida

✅ Email/password auth (Supabase Auth)
✅ Customer flow: catalog, search, product detail, cart, checkout (mock payment), order tracking
✅ Seller flow: shop create, product CRUD, order fulfillment, basic analytics
✅ Seller verification: manual passport upload + admin review
✅ Tariff system: Free + 1-2 paid tier (manual upgrade by admin)
✅ Multilingual content (uz/ru/en) — JSONB based
✅ Admin tooling: web dashboard + Telegram bot
✅ Push notifications (order status, new orders for seller)
✅ Realtime order updates
✅ Mode switching: customer ↔ seller via app restart pattern

### 1.3 V2 (post-launch)

- SMS OTP (Eskiz integration)
- MyID verification integration
- To'lov gateway (Click, Payme, Uzum Bank)
- Customer ↔ Seller chat
- Advanced analytics
- Promo codes, kuponlar
- Wishlist sharing
- Reviews & ratings (V1 da read-only, V2 da yozish)
- Multi-warehouse logistics (agar kerak bo'lsa)

### 1.4 V1 ichida YO'Q

❌ Real to'lov (mock checkout — order yaratiladi, "naqd to'lov" deb qabul qilinadi)
❌ SMS OTP (faqat email)
❌ MyID integration (manual verification only)
❌ In-app chat
❌ Advanced search filters (faqat kategoriya + price range)
❌ Promo codes
❌ Multi-currency (faqat UZS)
❌ Bulk product import (CSV)
❌ Seller-to-seller messaging
❌ Affiliate / referral system

---

## 2. Yuqori darajadagi Arxitektura

```
┌─────────────────────┐     ┌─────────────────────┐
│  Customer App       │     │   Seller App        │
│  (Flutter)          │     │   (Flutter)         │
│  — bitta loyihada,  │     │   — restart bilan   │
│    alohida entry    │     │     ochiladi        │
└──────────┬──────────┘     └──────────┬──────────┘
           │                            │
           │  HTTPS (REST + Realtime WS)│
           │                            │
           └──────────┬─────────────────┘
                      │
         ┌────────────▼──────────────┐
         │   Python FastAPI Backend  │
         │   (Railway / Fly.io)      │
         │                           │
         │   • Business logic        │
         │   • MyID / Eskiz proxy    │
         │   • Payment processing    │
         │   • Background tasks      │
         │   • Admin operations      │
         └────────────┬──────────────┘
                      │
                      │  asyncpg / Supabase Python SDK
                      │
         ┌────────────▼──────────────┐
         │       Supabase            │
         │                           │
         │   ┌───────────────────┐   │
         │   │ Postgres + RLS    │   │
         │   │ (minimal RLS,     │   │
         │   │  read-side only)  │   │
         │   └───────────────────┘   │
         │   ┌───────────────────┐   │
         │   │ Supabase Auth     │   │
         │   │ (email/password)  │   │
         │   └───────────────────┘   │
         │   ┌───────────────────┐   │
         │   │ Supabase Storage  │   │
         │   │ (images, docs)    │   │
         │   └───────────────────┘   │
         │   ┌───────────────────┐   │
         │   │ Realtime          │   │
         │   │ (Postgres CDC)    │   │
         │   └───────────────────┘   │
         └───────────────────────────┘
                      │
                      │
         ┌────────────▼──────────────┐
         │   Admin Tools             │
         │                           │
         │   ┌───────────────────┐   │
         │   │ Next.js Web Admin │   │
         │   │ (Vercel)          │   │
         │   └───────────────────┘   │
         │   ┌───────────────────┐   │
         │   │ Telegram Bot      │   │
         │   │ (Python aiogram)  │   │
         │   └───────────────────┘   │
         └───────────────────────────┘
```

### 2.1 Auth + Authorization pattern

**Supabase Auth + Python backend hybrid:**

1. Foydalanuvchi mobile app dan email/password bilan ro'yxatdan o'tadi
2. Supabase Auth foydalanuvchini `auth.users` ga yozadi va JWT qaytaradi
3. Mobile app Python backend ga so'rov yuborganda `Authorization: Bearer <jwt>` header qo'shadi
4. Python backend JWT ni Supabase JWKS orqali verify qiladi (offline)
5. Python backend `auth.uid()` ni JWT dan oladi va biznes-logikada ishlatadi

**Avantaj:** Supabase Auth provayder sifatida (email verification, password reset, refresh token), Python backend authorization rules uchun (kim nima qila oladi).

**RLS minimal:** Faqat **client-side direct queries** uchun (agar kerak bo'lsa). Asosiy authorization Python da. Sabab: RLS debugging og'ir, performance ta'siri bor.

---

## 3. Database Schema (Supabase Postgres)

### 3.1 Asosiy printsiplar

- **UUID primary keys** (auto-generated `gen_random_uuid()`)
- **Soft delete** (har joyda `deleted_at TIMESTAMP`)
- **Timestamps** (`created_at`, `updated_at` — Postgres trigger bilan auto-update)
- **Multilingual** maydonlar `JSONB` formatda: `{"uz": "...", "ru": "...", "en": "..."}`
- **Audit log** alohida jadvalda (kim, qachon, nima qildi)
- **Naming**: `snake_case`, jadvallar ko'plikda (`products`, `users`)

### 3.2 Schema

#### 3.2.1 Users & Profiles

```sql
-- Supabase Auth boshqaradi: auth.users (id, email, encrypted_password, email_confirmed_at, ...)

-- Public profile (auth.users ga 1:1 bog'lanadi)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  phone TEXT UNIQUE, -- kelajakda OTP uchun
  avatar_url TEXT,
  preferred_language TEXT DEFAULT 'uz' CHECK (preferred_language IN ('uz', 'ru', 'en')),
  date_of_birth DATE,
  gender TEXT CHECK (gender IN ('male', 'female', 'other')),
  is_blocked BOOLEAN DEFAULT FALSE,
  blocked_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Foydalanuvchining manzillari (yetkazib berish uchun)
CREATE TABLE user_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  label TEXT NOT NULL, -- "Uy", "Ish", "Onamning uyi"
  region_id UUID REFERENCES regions(id),
  district TEXT,
  address_line TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Viloyat / shahar
CREATE TABLE regions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name JSONB NOT NULL, -- {"uz": "Toshkent", "ru": "Ташкент", "en": "Tashkent"}
  parent_id UUID REFERENCES regions(id), -- ierarxiya: viloyat → shahar → tuman
  level INT NOT NULL, -- 1=viloyat, 2=shahar/tuman, 3=mahalla
  is_active BOOLEAN DEFAULT TRUE
);
```

#### 3.2.2 Sellers & Shops

**Muhim**: bitta foydalanuvchi → bitta seller_profile → ko'p shops bo'lishi mumkin (kelajakda). MVP da 1:1 yetadi, lekin schema multi-shop ga tayyor bo'lsin.

```sql
-- Seller profile (verification uchun shaxsiy ma'lumotlar)
CREATE TABLE seller_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  -- Yuridik holat
  business_type TEXT NOT NULL CHECK (business_type IN ('individual', 'self_employed', 'llc', 'corporation')),
  -- individual = jismoniy shaxs
  -- self_employed = YaTT (yakka tartibdagi tadbirkor)
  -- llc = MChJ
  -- corporation = AJ

  -- Shaxsiy ma'lumot
  legal_name TEXT NOT NULL, -- Toliq F.I.O. yoki kompaniya nomi
  passport_series TEXT, -- AB1234567 format
  inn TEXT, -- STIR
  registration_address TEXT,

  -- Verification
  verification_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending', 'in_review', 'approved', 'rejected')),
  verification_method TEXT CHECK (verification_method IN ('manual', 'myid', 'auto')),
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES profiles(id),
  rejection_reason TEXT,

  -- Hujjatlar (Supabase Storage URL'lari)
  passport_front_url TEXT,
  passport_back_url TEXT,
  selfie_with_passport_url TEXT,
  business_certificate_url TEXT, -- YaTT/MChJ uchun
  myid_payload JSONB, -- MyID javobi (kelajakda)

  -- Bog'lanish
  contact_phone TEXT NOT NULL,
  contact_email TEXT,
  telegram_username TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Do'kon (har sotuvchining bir yoki bir nechta do'koni bo'lishi mumkin)
CREATE TABLE shops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_profile_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
  slug TEXT UNIQUE NOT NULL, -- URL uchun: "mebel-master"

  -- Multilingual
  name JSONB NOT NULL,
  description JSONB,
  short_description JSONB,

  -- Branding
  logo_url TEXT,
  cover_url TEXT,
  brand_color TEXT, -- "#FF5733"

  -- Manzil va ish vaqti
  address TEXT,
  region_id UUID REFERENCES regions(id),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  working_hours JSONB, -- {"mon": "9:00-18:00", "tue": "9:00-18:00", ...}

  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE, -- admin tomonidan asosiy sahifaga chiqarilgan
  visibility TEXT DEFAULT 'public' CHECK (visibility IN ('public', 'hidden', 'draft')),

  -- Tariff (subscription)
  tariff_id UUID REFERENCES tariffs(id),
  tariff_started_at TIMESTAMPTZ,
  tariff_expires_at TIMESTAMPTZ,
  auto_renew BOOLEAN DEFAULT FALSE,

  -- Hisoblanadigan stats (cache, periodic update)
  total_products INT DEFAULT 0,
  total_orders INT DEFAULT 0,
  total_revenue NUMERIC(15, 2) DEFAULT 0,
  average_rating NUMERIC(3, 2),
  review_count INT DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_shops_seller ON shops(seller_profile_id);
CREATE INDEX idx_shops_active ON shops(is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_shops_slug ON shops(slug);
```

#### 3.2.3 Tariffs & Subscriptions

**Tariff sistemasi:** har do'kon bitta tarifda bo'ladi. Tarif limit va imkoniyatlarni belgilaydi.

```sql
-- Tarif rejasi (admin tomonidan boshqariladi)
CREATE TABLE tariffs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL, -- "free", "basic", "pro", "enterprise"
  name JSONB NOT NULL,
  description JSONB,

  -- Narx
  price_monthly NUMERIC(15, 2) NOT NULL DEFAULT 0,
  price_yearly NUMERIC(15, 2),
  currency TEXT DEFAULT 'UZS',

  -- Limitlar
  max_products INT, -- NULL = cheksiz
  max_photos_per_product INT DEFAULT 10,
  max_categories INT,
  can_use_promo BOOLEAN DEFAULT FALSE,
  can_use_analytics BOOLEAN DEFAULT FALSE,
  can_use_priority_support BOOLEAN DEFAULT FALSE,
  can_use_featured_listing BOOLEAN DEFAULT FALSE,
  commission_percent NUMERIC(5, 2) DEFAULT 0, -- platforma komissiyasi (%)

  -- Display
  is_active BOOLEAN DEFAULT TRUE,
  display_order INT DEFAULT 0,
  is_recommended BOOLEAN DEFAULT FALSE, -- "Most popular" yorlig'i

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Misol uchun seed:
-- INSERT INTO tariffs ... ('free', ..., 0, max_products=10),
--                         ('basic', ..., 99000, max_products=100),
--                         ('pro', ..., 299000, max_products=NULL, can_use_analytics=true),
--                         ('enterprise', ..., 999000, ... custom)

-- Subscription tarixi (audit + tariff o'zgarishi)
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  tariff_id UUID NOT NULL REFERENCES tariffs(id),

  status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'cancelled', 'pending_payment')),
  starts_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  cancelled_at TIMESTAMPTZ,

  -- Payment
  amount NUMERIC(15, 2) NOT NULL,
  payment_id UUID REFERENCES payments(id),
  payment_method TEXT, -- "manual", "click", "payme", ...

  -- Audit
  changed_by UUID REFERENCES profiles(id), -- admin yoki system
  notes TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_shop ON subscriptions(shop_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
```

#### 3.2.4 Shop Services (har do'kon turlicha xizmat ko'rsatadi)

Bu sening "har xil sotuvchilar har xil xizmat" talabiga javob beradi. Joyini qattiq belgilamasdan, **flexible feature flags** orqali:

```sql
-- Standart xizmatlar ro'yxati (admin tomonidan boshqariladi)
CREATE TABLE service_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  -- Misollar:
  -- 'free_delivery'         — Bepul yetkazib berish
  -- 'paid_delivery'         — Pulli yetkazib berish
  -- 'pickup'                — O'zi olib ketish
  -- 'assembly'              — Yig'ib berish (montaj)
  -- 'installation'          — O'rnatib berish
  -- 'warranty_1y'           — 1 yil garantiya
  -- 'warranty_3y'           — 3 yil garantiya
  -- 'custom_order'          — Buyurtma asosida ishlash
  -- 'bulk_discount'         — Ko'p miqdorda chegirma
  -- 'cash_on_delivery'      — Yetkazganda to'lov
  -- 'installment'           — Bo'lib to'lash

  name JSONB NOT NULL,
  description JSONB,
  icon TEXT, -- icon name (lucide / material)
  category TEXT, -- 'delivery', 'guarantee', 'payment', 'extras'

  -- Konfiguratsiya: bu xizmat qanday parametrlar oladi
  -- Misol: free_delivery uchun {"min_order_amount": 500000}
  config_schema JSONB,

  is_active BOOLEAN DEFAULT TRUE,
  display_order INT DEFAULT 0
);

-- Har do'kon o'zi yoqgan xizmatlar
CREATE TABLE shop_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  service_type_id UUID NOT NULL REFERENCES service_types(id),

  is_enabled BOOLEAN DEFAULT TRUE,
  config JSONB, -- service_type.config_schema ga mos
  -- Misollar:
  -- {"min_order_amount": 1000000, "delivery_zones": ["tashkent", "samarkand"]}
  -- {"price_per_km": 5000, "free_distance_km": 5}
  -- {"warranty_months": 12, "covers": ["manufacturing_defects"]}

  custom_description JSONB, -- "Toshkent shahri ichida 24 soat"

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(shop_id, service_type_id)
);

CREATE INDEX idx_shop_services_shop ON shop_services(shop_id) WHERE is_enabled = TRUE;
```

**Frontend da:** product detail sahifada "Bu do'kon nima taklif qiladi" bo'limi:
- 🚚 Bepul yetkazib berish (1,000,000 so'mdan)
- 🔧 Yig'ib berish (50,000 so'm)
- 🛡️ 12 oy garantiya
- 💰 Yetkazganda to'lov

#### 3.2.5 Categories & Products

```sql
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID REFERENCES categories(id),
  slug TEXT UNIQUE NOT NULL,
  name JSONB NOT NULL,
  description JSONB,
  icon_url TEXT,
  cover_url TEXT,

  -- Ierarxiya
  depth INT NOT NULL DEFAULT 0,
  path TEXT, -- "/furniture/sofas/corner-sofas"

  -- Display
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,

  -- Filterable attributes (kategoriyaga xos atributlar)
  -- Misol: "sofa" uchun: ["material", "color", "seats", "dimensions"]
  attribute_schema JSONB,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_slug ON categories(slug);

CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  category_id UUID REFERENCES categories(id),

  slug TEXT UNIQUE NOT NULL, -- "stol-yog'och-100x60"
  sku TEXT, -- sotuvchining ichki kodi

  name JSONB NOT NULL,
  description JSONB,
  short_description JSONB,

  -- Narx
  price NUMERIC(15, 2) NOT NULL,
  old_price NUMERIC(15, 2), -- chegirmagacha bo'lgan narx
  currency TEXT DEFAULT 'UZS',

  -- Inventar
  stock INT NOT NULL DEFAULT 0,
  is_in_stock BOOLEAN GENERATED ALWAYS AS (stock > 0) STORED,
  track_inventory BOOLEAN DEFAULT TRUE,

  -- Atributlar (kategoriyaga xos)
  attributes JSONB DEFAULT '{}', -- {"material": "yog'och", "color": "qo'ng'ir", "width_cm": 100}

  -- Moderatsiya
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'pending_review', 'approved', 'rejected', 'archived')),
  rejection_reason TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,

  -- Display
  is_featured BOOLEAN DEFAULT FALSE,
  view_count INT DEFAULT 0,
  favorite_count INT DEFAULT 0,
  order_count INT DEFAULT 0,
  average_rating NUMERIC(3, 2),
  review_count INT DEFAULT 0,

  -- O'lcham va og'irlik (yetkazib berish narxi uchun)
  weight_kg NUMERIC(8, 3),
  dimensions JSONB, -- {"length_cm": 100, "width_cm": 60, "height_cm": 75}

  -- SEO
  meta_title JSONB,
  meta_description JSONB,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  published_at TIMESTAMPTZ
);

CREATE INDEX idx_products_shop ON products(shop_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_category ON products(category_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_featured ON products(is_featured) WHERE status = 'approved';
CREATE INDEX idx_products_search_uz ON products USING gin (to_tsvector('simple', (name->>'uz' || ' ' || COALESCE(description->>'uz', ''))));
-- ru, en uchun ham shunday indekslar

CREATE TABLE product_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  alt_text JSONB,
  display_order INT DEFAULT 0,
  is_primary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_product_images_product ON product_images(product_id);
```

#### 3.2.6 Orders, Cart, Favorites

```sql
-- Cart server-side (mobile + web sync uchun)
-- Agar siz faqat mobile bo'lsa, cart ni Hive da local saqlash ham mumkin
CREATE TABLE cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  quantity INT NOT NULL CHECK (quantity > 0),
  added_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, product_id)
);

CREATE TABLE favorites (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, product_id)
);

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number TEXT UNIQUE NOT NULL, -- "ORD-2026-00001" (sequence dan)

  user_id UUID NOT NULL REFERENCES profiles(id),
  shop_id UUID NOT NULL REFERENCES shops(id),
  -- Bitta orderda bitta do'kon mahsulotlari (multi-shop split orderda alohida orderlar)

  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN (
      'pending',         -- yangi yaratildi, sotuvchi javob kutmoqda
      'confirmed',       -- sotuvchi qabul qildi
      'preparing',       -- tayyorlanmoqda
      'ready_to_ship',   -- yuborishga tayyor
      'shipped',         -- yo'lda
      'delivered',       -- yetkazildi
      'completed',       -- foydalanuvchi qabul qildi
      'cancelled',       -- bekor qilindi
      'refunded'         -- pul qaytarildi
    )),

  -- Narx
  subtotal NUMERIC(15, 2) NOT NULL,
  delivery_fee NUMERIC(15, 2) DEFAULT 0,
  discount NUMERIC(15, 2) DEFAULT 0,
  total NUMERIC(15, 2) NOT NULL,
  currency TEXT DEFAULT 'UZS',
  commission NUMERIC(15, 2) DEFAULT 0, -- platforma komissiyasi (tariff dan)

  -- Yetkazish
  delivery_method TEXT NOT NULL CHECK (delivery_method IN ('pickup', 'shop_delivery', 'courier')),
  delivery_address_snapshot JSONB, -- order vaqtidagi snapshot
  recipient_name TEXT,
  recipient_phone TEXT,
  delivery_notes TEXT,

  -- To'lov
  payment_method TEXT CHECK (payment_method IN ('cash_on_delivery', 'click', 'payme', 'card', 'manual')),
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),

  -- Bekor qilish
  cancellation_reason_code TEXT,
  cancellation_reason_text TEXT,
  cancelled_by UUID REFERENCES profiles(id),
  cancelled_at TIMESTAMPTZ,

  -- Vaqtlar
  confirmed_at TIMESTAMPTZ,
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,

  -- Qo'shimcha
  customer_note TEXT,
  seller_note TEXT,
  metadata JSONB DEFAULT '{}',

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_shop ON orders(shop_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created ON orders(created_at DESC);

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),

  -- Snapshot (order yaratilgan vaqtidagi narx va nom)
  product_name_snapshot JSONB NOT NULL,
  product_image_snapshot TEXT,
  unit_price NUMERIC(15, 2) NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  total_price NUMERIC(15, 2) NOT NULL,

  -- Tanlangan xizmatlar (montaj, garantiya, ...)
  selected_services JSONB DEFAULT '[]',

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order status tarixi (audit + customer ga ko'rsatish uchun)
CREATE TABLE order_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status TEXT,
  to_status TEXT NOT NULL,
  changed_by UUID REFERENCES profiles(id),
  changed_by_role TEXT, -- 'customer', 'seller', 'admin', 'system'
  note TEXT,
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id),
  subscription_id UUID REFERENCES subscriptions(id),

  amount NUMERIC(15, 2) NOT NULL,
  currency TEXT DEFAULT 'UZS',

  provider TEXT NOT NULL, -- 'click', 'payme', 'manual', 'cash'
  provider_transaction_id TEXT,
  status TEXT NOT NULL CHECK (status IN ('pending', 'success', 'failed', 'refunded')),

  raw_response JSONB,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);
```

#### 3.2.7 Reviews & Ratings (V2 da yozish, V1 da read-only)

```sql
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  product_id UUID NOT NULL REFERENCES products(id),
  order_id UUID REFERENCES orders(id), -- verified purchase

  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title TEXT,
  content TEXT,
  images JSONB DEFAULT '[]',

  is_verified_purchase BOOLEAN DEFAULT FALSE,
  is_published BOOLEAN DEFAULT TRUE,

  helpful_count INT DEFAULT 0,
  reported_count INT DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, product_id) -- bir user bir mahsulotga bir review
);
```

#### 3.2.8 Notifications

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  type TEXT NOT NULL,
  -- 'order_created', 'order_confirmed', 'order_shipped', 'order_delivered',
  -- 'product_approved', 'product_rejected',
  -- 'verification_approved', 'verification_rejected',
  -- 'subscription_expiring', 'subscription_expired',
  -- 'system_announcement'

  title JSONB NOT NULL,
  body JSONB NOT NULL,

  data JSONB DEFAULT '{}', -- deep link uchun: {"order_id": "...", "screen": "order_detail"}

  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,

  -- Push notification status
  push_sent BOOLEAN DEFAULT FALSE,
  push_sent_at TIMESTAMPTZ,
  push_error TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_unread ON notifications(user_id) WHERE is_read = FALSE;
```

#### 3.2.9 Audit Log

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES profiles(id),
  actor_role TEXT,

  action TEXT NOT NULL,
  -- 'user.blocked', 'product.approved', 'shop.tariff_changed',
  -- 'order.cancelled_by_admin', 'seller.verified', ...

  entity_type TEXT NOT NULL, -- 'user', 'product', 'shop', 'order'
  entity_id UUID NOT NULL,

  before_state JSONB,
  after_state JSONB,

  ip_address TEXT,
  user_agent TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_actor ON audit_logs(actor_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);
```

### 3.3 Postgres Triggers

```sql
-- updated_at avtomatik
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Har jadvalga apply qilish
CREATE TRIGGER set_updated_at_profiles
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
-- ... va h.k. har jadval uchun

-- Order number generator
CREATE SEQUENCE order_number_seq START 1;
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
BEGIN
  RETURN 'ORD-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(NEXTVAL('order_number_seq')::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;
```

### 3.4 Helper Functions

```sql
-- Multilingual helper
CREATE OR REPLACE FUNCTION i18n(field JSONB, lang TEXT DEFAULT 'uz')
RETURNS TEXT AS $$
  SELECT COALESCE(field->>lang, field->>'uz', field->>'en', field->>'ru')
$$ LANGUAGE sql IMMUTABLE;

-- Misol: SELECT id, i18n(name, 'ru') FROM products;
```

---

## 4. Backend (Python + FastAPI)

### 4.1 Stack tanlovi

| Komponent | Tanlov | Sabab |
|-----------|--------|-------|
| Framework | **FastAPI** | Async, Pydantic v2, OpenAPI auto-gen, modern |
| ASGI server | **Uvicorn** + **Gunicorn** workers (prod) | Standart |
| DB driver | **asyncpg** + **SQLAlchemy 2.0** (async) | Type-safe, complex queries |
| Migrations | **Supabase CLI** (`supabase migration`) | Schema central |
| Validation | **Pydantic v2** | FastAPI bilan native |
| Auth | **PyJWT** + Supabase JWKS verification | JWT verify offline |
| Storage SDK | **supabase-py** | Storage upload/download |
| Background jobs | **arq** (Redis-based) | Lightweight, async-native |
| HTTP client | **httpx** (async) | MyID, Eskiz, OneSignal API'lar |
| Logging | **structlog** + JSON | Production-ready |
| Monitoring | **Sentry** | Free tier yetadi |
| Testing | **pytest** + **pytest-asyncio** + **httpx** | Standart |

### 4.2 Loyiha tuzilishi

```
mebellar-backend/
├── pyproject.toml              # Poetry yoki uv
├── README.md
├── .env.example
├── docker-compose.yml          # local Postgres (dev)
├── Dockerfile
├── alembic.ini                 # agar Alembic ishlatsa (alt)
│
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI app instance
│   ├── config.py               # pydantic-settings
│   ├── lifespan.py             # startup/shutdown (DB pool, etc.)
│   │
│   ├── core/
│   │   ├── database.py         # SQLAlchemy engine, session
│   │   ├── supabase.py         # Supabase client (storage, auth admin)
│   │   ├── security.py         # JWT verify, password hashing (admin)
│   │   ├── exceptions.py       # Custom exception classes
│   │   ├── i18n.py             # Multilingual helpers
│   │   ├── logging.py          # structlog config
│   │   └── deps.py             # FastAPI dependencies (current_user, db, ...)
│   │
│   ├── models/                 # SQLAlchemy ORM models
│   │   ├── base.py
│   │   ├── user.py
│   │   ├── seller.py
│   │   ├── shop.py
│   │   ├── product.py
│   │   ├── order.py
│   │   ├── tariff.py
│   │   └── ...
│   │
│   ├── schemas/                # Pydantic schemas (request/response)
│   │   ├── user.py
│   │   ├── product.py
│   │   ├── order.py
│   │   └── ...
│   │
│   ├── repositories/           # DB query layer (data access)
│   │   ├── base.py
│   │   ├── user_repo.py
│   │   ├── product_repo.py
│   │   └── ...
│   │
│   ├── services/               # Business logic layer
│   │   ├── auth_service.py
│   │   ├── order_service.py
│   │   ├── product_service.py
│   │   ├── seller_service.py
│   │   ├── verification_service.py     # MyID + manual
│   │   ├── tariff_service.py
│   │   ├── notification_service.py
│   │   └── payment_service.py
│   │
│   ├── api/
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   ├── router.py       # main v1 router
│   │   │   │
│   │   │   ├── auth.py         # /auth (mostly delegates to Supabase)
│   │   │   ├── profile.py      # /me, /addresses
│   │   │   ├── shops.py        # /shops, /shops/{id}
│   │   │   ├── products.py     # /products (public), /products/search
│   │   │   ├── categories.py
│   │   │   ├── cart.py         # /cart
│   │   │   ├── favorites.py
│   │   │   ├── orders.py       # /orders (customer + seller)
│   │   │   ├── reviews.py
│   │   │   │
│   │   │   ├── seller/
│   │   │   │   ├── shop.py     # /seller/shop (own shop CRUD)
│   │   │   │   ├── products.py # /seller/products
│   │   │   │   ├── orders.py   # /seller/orders
│   │   │   │   ├── analytics.py
│   │   │   │   ├── verification.py  # /seller/verification
│   │   │   │   └── tariff.py   # /seller/tariff
│   │   │   │
│   │   │   └── admin/
│   │   │       ├── users.py
│   │   │       ├── sellers.py  # verification queue, approve/reject
│   │   │       ├── products.py # moderation
│   │   │       ├── orders.py
│   │   │       ├── tariffs.py
│   │   │       └── audit.py
│   │   │
│   │   └── webhooks/
│   │       ├── supabase.py     # auth events
│   │       ├── click.py        # to'lov
│   │       └── payme.py
│   │
│   ├── integrations/
│   │   ├── myid/
│   │   │   ├── client.py
│   │   │   └── schemas.py
│   │   ├── eskiz/              # SMS (V2)
│   │   ├── onesignal/
│   │   ├── click/
│   │   └── payme/
│   │
│   ├── jobs/                   # arq background tasks
│   │   ├── worker.py           # arq worker entry
│   │   ├── notifications.py    # send push, email
│   │   ├── analytics.py        # daily aggregations
│   │   └── cleanup.py          # soft-delete cleanup, cache invalidation
│   │
│   └── utils/
│       ├── slug.py             # slug generation
│       ├── images.py           # image processing
│       └── ...
│
├── tests/
│   ├── conftest.py
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
└── scripts/
    ├── seed_data.py            # demo data
    └── ...
```

### 4.3 Auth flow detallar

> **Muhim arxitektura qarori:** profile yaratish **client-side sync** orqali emas, **Postgres trigger** orqali amalga oshiriladi. Sababi: agar mobile app Supabase Auth'da signup qilib, keyin Python backend'ga sync so'rovi yuborayotganda internet uzilsa, sizda **"yetim foydalanuvchi"** paydo bo'ladi (`auth.users`'da bor, `public.profiles`'da yo'q). Trigger atomik — `auth.users` insert va `public.profiles` insert bitta tranzaksiyada bajariladi.

**Postgres trigger (Supabase migration'ga qo'shiladi):**

```sql
-- Yangi auth.users qator yaratilganda avtomatik profile yaratish
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER -- auth schema'ga yozish uchun kerak
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    full_name,
    preferred_language,
    phone
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'preferred_language', 'uz'),
    NEW.phone -- agar phone signup'da berilgan bo'lsa
  );
  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    -- Idempotent: profile allaqachon mavjud (rare race)
    RETURN NEW;
  WHEN OTHERS THEN
    -- Trigger xatosi auth.users insert'ni bloklamasligi kerak
    -- Lekin loglash kerak — Supabase Logs orqali ko'riladi
    RAISE WARNING 'handle_new_user error for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

**Mobile app dan ro'yxatdan o'tish flow:**

```
1. User → Supabase Auth: signUp(email, password, options: {
     data: { full_name, preferred_language: 'uz' }
   })
2. Supabase: auth.users ga INSERT
3. Trigger AVTOMATIK: public.profiles ga INSERT (atomik, bitta tranzaksiyada)
4. Supabase → User: email verification link
5. User clicks link → Supabase confirms (email_confirmed_at to'ldiriladi)
6. User → Supabase Auth: signIn → access_token (JWT) + refresh_token
7. Mobile app → Python backend: GET /api/v1/me
   Header: Authorization: Bearer <jwt>
8. Python backend:
   - JWT verify via JWKS (cached)
   - Profile fetch (ALWAYS exists thanks to trigger)
   - Return profile + roles
```

**Bonus afzalliklar:**
- Test'lar oson: SQL'da `INSERT INTO auth.users` qilsangiz, profile avtomatik
- Admin manual user create qilsa ham profile yaratiladi
- Network tushib qolgan client'lar muammosi yo'q
- `POST /api/v1/auth/sync` endpoint'i kerak emas — o'chirildi

**Edge case'ga e'tibor:** trigger ichida `EXCEPTION WHEN OTHERS` o'rashning sababi — agar profile yaratishda biror xato bo'lsa (masalan, NOT NULL constraint), bu **`auth.users` insert'ni rollback qilmasligi** kerak. Aks holda foydalanuvchi umuman ro'yxatdan o'ta olmaydi. Xatolar Supabase Logs'da ko'rinadi va keyinroq tuzatiladi.

**JWT verification (Python backend):**

```python
# app/core/security.py
import httpx
import jwt
from jwt import PyJWKClient
from functools import lru_cache

@lru_cache(maxsize=1)
def get_jwks_client():
    return PyJWKClient(f"{settings.SUPABASE_URL}/auth/v1/keys")

async def verify_supabase_jwt(token: str) -> dict:
    jwks = get_jwks_client()
    signing_key = jwks.get_signing_key_from_jwt(token)
    payload = jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256", "ES256"],
        audience="authenticated",
        issuer=f"{settings.SUPABASE_URL}/auth/v1",
    )
    return payload  # contains sub (user_id), email, role, etc.
```

**Dependency injection:**

```python
# app/core/deps.py
from fastapi import Depends, HTTPException, Header

async def get_current_user(
    authorization: str = Header(...),
    db: AsyncSession = Depends(get_db),
) -> Profile:
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Missing bearer token")

    token = authorization.removeprefix("Bearer ")
    try:
        payload = await verify_supabase_jwt(token)
    except jwt.PyJWTError:
        raise HTTPException(401, "Invalid token")

    user_id = payload["sub"]
    profile = await db.get(Profile, user_id)
    if not profile or profile.is_blocked:
        raise HTTPException(403, "Profile not found or blocked")
    return profile

async def require_seller(profile: Profile = Depends(get_current_user)) -> Profile:
    if not profile.seller_profile or profile.seller_profile.verification_status != "approved":
        raise HTTPException(403, "Seller account not verified")
    return profile

async def require_admin(profile: Profile = Depends(get_current_user)) -> Profile:
    if not profile.is_admin:
        raise HTTPException(403, "Admin only")
    return profile
```

**Endpoint misoli:**

```python
# app/api/v1/seller/products.py
@router.post("/products", response_model=ProductOut)
async def create_product(
    payload: ProductCreate,
    seller: Profile = Depends(require_seller),
    db: AsyncSession = Depends(get_db),
):
    return await product_service.create_for_seller(db, seller, payload)
```

### 4.4 API Endpoint Map (V1)

#### Public (no auth)

```
GET    /api/v1/health
GET    /api/v1/categories
GET    /api/v1/categories/{slug}
GET    /api/v1/regions
GET    /api/v1/products                    ?category=&shop=&search=&min_price=&max_price=&sort=&page=
GET    /api/v1/products/{slug}
GET    /api/v1/shops
GET    /api/v1/shops/{slug}
GET    /api/v1/shops/{slug}/products
GET    /api/v1/banners
GET    /api/v1/tariffs                     # public — sellerlar ko'radi
GET    /api/v1/service-types               # public
```

#### Authenticated (any user)

```
# Auth: signup/signin/refresh/reset — Supabase Auth orqali to'g'ridan-to'g'ri (mobile SDK).
# Profile yaratish — Postgres trigger orqali avtomatik (4.3-bo'limga qarang).
# Backend'da /auth/sync kabi endpoint YO'Q.

GET    /api/v1/me                          # profile + roles
PATCH  /api/v1/me
DELETE /api/v1/me                          # soft delete
GET    /api/v1/me/addresses
POST   /api/v1/me/addresses
PATCH  /api/v1/me/addresses/{id}
DELETE /api/v1/me/addresses/{id}

GET    /api/v1/cart
POST   /api/v1/cart/items
PATCH  /api/v1/cart/items/{id}
DELETE /api/v1/cart/items/{id}

GET    /api/v1/favorites
POST   /api/v1/favorites/{product_id}
DELETE /api/v1/favorites/{product_id}

GET    /api/v1/orders                      # o'z buyurtmalari
POST   /api/v1/orders                      # checkout
GET    /api/v1/orders/{id}
POST   /api/v1/orders/{id}/cancel

GET    /api/v1/notifications
PATCH  /api/v1/notifications/{id}/read
POST   /api/v1/notifications/read-all

POST   /api/v1/seller/onboarding           # registration as seller (creates seller_profile + shop)
```

#### Seller (require_seller dependency)

```
GET    /api/v1/seller/shop                 # o'z do'koni
PATCH  /api/v1/seller/shop
POST   /api/v1/seller/shop/logo
POST   /api/v1/seller/shop/cover

GET    /api/v1/seller/products
POST   /api/v1/seller/products
GET    /api/v1/seller/products/{id}
PATCH  /api/v1/seller/products/{id}
DELETE /api/v1/seller/products/{id}
POST   /api/v1/seller/products/{id}/images
DELETE /api/v1/seller/products/{id}/images/{image_id}

GET    /api/v1/seller/orders               # do'koniga kelgan buyurtmalar
GET    /api/v1/seller/orders/{id}
POST   /api/v1/seller/orders/{id}/confirm
POST   /api/v1/seller/orders/{id}/ship
POST   /api/v1/seller/orders/{id}/deliver
POST   /api/v1/seller/orders/{id}/cancel

GET    /api/v1/seller/services             # yoqilgan xizmatlar
PUT    /api/v1/seller/services             # yoqish/o'chirish

GET    /api/v1/seller/tariff               # joriy tarif
POST   /api/v1/seller/tariff/upgrade       # so'rov yuborish (manual approve)

GET    /api/v1/seller/analytics/overview
GET    /api/v1/seller/analytics/sales      ?from=&to=
GET    /api/v1/seller/analytics/products

GET    /api/v1/seller/verification         # joriy holat
POST   /api/v1/seller/verification/manual  # passport upload
POST   /api/v1/seller/verification/myid    # MyID flow (V2)
```

#### Admin (require_admin)

```
GET    /api/v1/admin/dashboard             # KPI summary
GET    /api/v1/admin/users                 # filter, search
GET    /api/v1/admin/users/{id}
POST   /api/v1/admin/users/{id}/block
POST   /api/v1/admin/users/{id}/unblock

GET    /api/v1/admin/sellers/pending       # verification queue
POST   /api/v1/admin/sellers/{id}/approve
POST   /api/v1/admin/sellers/{id}/reject

GET    /api/v1/admin/products/pending      # moderation queue
POST   /api/v1/admin/products/{id}/approve
POST   /api/v1/admin/products/{id}/reject

GET    /api/v1/admin/orders
POST   /api/v1/admin/orders/{id}/cancel    # admin cancel

GET    /api/v1/admin/tariffs
POST   /api/v1/admin/tariffs               # CRUD
PATCH  /api/v1/admin/tariffs/{id}
POST   /api/v1/admin/shops/{id}/tariff     # manual tariff change

GET    /api/v1/admin/categories
POST   /api/v1/admin/categories            # CRUD
PATCH  /api/v1/admin/categories/{id}

GET    /api/v1/admin/banners
POST   /api/v1/admin/banners

GET    /api/v1/admin/audit-logs            ?actor=&entity=&from=&to=

POST   /api/v1/admin/broadcast             # push notif to users
```

### 4.5 Background Jobs (arq)

```python
# app/jobs/worker.py
from arq.connections import RedisSettings

class WorkerSettings:
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    functions = [
        send_push_notification,
        send_email,
        recalculate_shop_stats,
        check_expiring_subscriptions,
        cleanup_soft_deleted,
        process_image_upload,
    ]
    cron_jobs = [
        cron(check_expiring_subscriptions, hour=9),    # har kuni 09:00
        cron(recalculate_shop_stats, hour=2),          # har kuni 02:00
        cron(daily_admin_summary, hour=23),            # har kuni 23:00 → Telegram bot
    ]
```

### 4.6 Configuration

```python
# app/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # App
    APP_NAME: str = "Woody Backend"
    ENV: str = "development"  # development | staging | production
    DEBUG: bool = False

    # Database
    DATABASE_URL: str  # postgresql+asyncpg://...

    # Supabase
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_KEY: str  # admin operations

    # Redis (jobs + cache)
    REDIS_URL: str

    # Integrations
    ONESIGNAL_APP_ID: str
    ONESIGNAL_API_KEY: str
    SENTRY_DSN: str | None = None

    # MyID (V2)
    MYID_BASE_URL: str | None = None
    MYID_CLIENT_ID: str | None = None
    MYID_CLIENT_SECRET: str | None = None

    # Eskiz (V2)
    ESKIZ_EMAIL: str | None = None
    ESKIZ_PASSWORD: str | None = None

    # Telegram bot
    TELEGRAM_BOT_TOKEN: str
    ADMIN_TELEGRAM_IDS: list[int] = []

    class Config:
        env_file = ".env"

settings = Settings()
```

---

## 5. Mobile App (Flutter — Dual Entry Point Pattern)

### 5.1 Loyiha tuzilishi

```
mebellar-app/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── main.dart                  # bootstrap + mode detection
│   │
│   ├── core/                      # SHARED across both apps
│   │   ├── di/                    # GetIt + Injectable setup
│   │   ├── network/
│   │   │   ├── api_client.dart    # Dio instance, interceptors
│   │   │   ├── supabase_client.dart
│   │   │   └── error_handler.dart
│   │   ├── storage/
│   │   │   ├── hive_boxes.dart
│   │   │   └── secure_storage.dart
│   │   ├── auth/
│   │   │   ├── auth_repository.dart
│   │   │   └── token_manager.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_typography.dart
│   │   │   ├── customer_theme.dart   # different brand for each
│   │   │   └── seller_theme.dart
│   │   ├── localization/
│   │   │   └── ... (uz, ru, en)
│   │   ├── error/
│   │   │   ├── failure.dart
│   │   │   └── either.dart
│   │   ├── widgets/               # truly shared widgets
│   │   │   ├── primary_button.dart
│   │   │   ├── text_field.dart
│   │   │   └── ...
│   │   └── utils/
│   │
│   ├── shared/                    # SHARED domain models & services
│   │   ├── models/
│   │   │   ├── product.dart
│   │   │   ├── shop.dart
│   │   │   ├── order.dart
│   │   │   └── ...
│   │   ├── repositories/
│   │   │   ├── product_repository.dart
│   │   │   ├── shop_repository.dart
│   │   │   └── ...
│   │   └── widgets/               # shared cross-mode widgets
│   │       ├── product_card.dart
│   │       ├── order_tile.dart
│   │       └── shop_header.dart
│   │
│   ├── customer/
│   │   ├── customer_app.dart      # MaterialApp + GoRouter (customer)
│   │   ├── router.dart
│   │   ├── features/
│   │   │   ├── home/
│   │   │   ├── catalog/
│   │   │   ├── product_detail/
│   │   │   ├── search/
│   │   │   ├── cart/
│   │   │   ├── checkout/
│   │   │   ├── orders/
│   │   │   ├── favorites/
│   │   │   └── profile/
│   │   └── widgets/
│   │
│   ├── seller/
│   │   ├── seller_app.dart        # MaterialApp + GoRouter (seller)
│   │   ├── router.dart
│   │   ├── features/
│   │   │   ├── onboarding/        # first-time seller registration + verification
│   │   │   ├── dashboard/
│   │   │   ├── products/
│   │   │   ├── orders/
│   │   │   ├── analytics/
│   │   │   ├── shop_settings/
│   │   │   ├── verification/
│   │   │   ├── tariff/
│   │   │   └── profile/
│   │   └── widgets/
│   │
│   └── auth/                      # shared auth screens (login, register)
│       ├── login_screen.dart
│       ├── register_screen.dart
│       ├── verify_email_screen.dart
│       └── forgot_password_screen.dart
│
├── test/
└── assets/
    ├── images/
    ├── icons/
    └── translations/
        ├── uz.json
        ├── ru.json
        └── en.json
```

### 5.2 Entry point va mode switching

> **Muhim arxitektura qarori:** `GetIt.I.reset()` ni to'g'ridan-to'g'ri chaqirish **memory leak**'ga olib keladi — Hive box'lar, Supabase realtime channellari, Dio HTTP client'lar, OneSignal listenerlar va boshqa singleton'larning ochiq resource'lari yopilmasdan qoladi. Yechim: **GetIt scope'lardan foydalanish** va **har singletonga `dispose` callback registration**.

**DI ikki qatlamga bo'linadi:**

| Scope | Mazmuni | Mode switch'da | Dispose |
|-------|---------|----------------|---------|
| **Root scope** (boot vaqtida) | `Hive` boxes, `SupabaseClient`, `Dio`, `AuthRepository`, `TokenManager`, `OneSignal`, `EasyLocalization` | **Saqlanadi** (qayta yaratilmaydi) | App butunlay yopilganda |
| **Mode scope** (`customer` yoki `seller`) | BLoC'lar, mode-specific repositories, realtime subscriptions, mode-specific cache | **Tashlanadi va qayta yaratiladi** | `popScope()` da dispose chaqiriladi |

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';

enum AppMode { customer, seller }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ROOT scope — bir marta yaratiladi, app yopilguncha turadi
  await _initRootScope();

  final mode = _getInitialMode();
  await _initModeScope(mode);

  runApp(
    Phoenix(
      child: switch (mode) {
        AppMode.seller => const SellerApp(),
        AppMode.customer => const CustomerApp(),
      },
    ),
  );
}

Future<void> _initRootScope() async {
  await Hive.initFlutter();
  final settingsBox = await Hive.openBox('settings');
  final cacheBox = await Hive.openBox('cache');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Root scope registration — dispose callback bilan
  GetIt.I.registerSingleton<Box>(settingsBox, instanceName: 'settings');
  GetIt.I.registerSingleton<Box>(cacheBox, instanceName: 'cache');
  GetIt.I.registerSingleton<SupabaseClient>(Supabase.instance.client);

  GetIt.I.registerLazySingleton<Dio>(
    () => buildDioClient(),
    dispose: (dio) => dio.close(force: true), // HTTP connection pool yopiladi
  );

  GetIt.I.registerLazySingleton<AuthRepository>(
    () => AuthRepository(GetIt.I<SupabaseClient>(), GetIt.I<Dio>()),
    dispose: (repo) async => repo.dispose(),
  );

  // OneSignal, Sentry, Firebase — global, mode-agnostic
  await _initOneSignal();
}

Future<void> _initModeScope(AppMode mode) async {
  // Yangi scope ochiladi — popScope() chaqirilganda hammasi dispose bo'ladi
  GetIt.I.pushNewScope(scopeName: mode.name);

  switch (mode) {
    case AppMode.customer:
      _registerCustomerDependencies();
    case AppMode.seller:
      _registerSellerDependencies();
  }
}

void _registerCustomerDependencies() {
  // Customer BLoC'lar
  GetIt.I.registerFactory(() => HomeBloc(GetIt.I<ProductRepository>()));
  GetIt.I.registerFactory(() => CartBloc(GetIt.I<CartRepository>()));
  // ...

  // Customer-specific real-time subscriptions
  GetIt.I.registerLazySingleton<OrderTrackingService>(
    () => OrderTrackingService(GetIt.I<SupabaseClient>()),
    dispose: (svc) async => svc.dispose(), // RealtimeChannel yopiladi
  );
}

void _registerSellerDependencies() {
  GetIt.I.registerFactory(() => DashboardBloc(GetIt.I<ShopRepository>()));
  GetIt.I.registerFactory(() => SellerProductsBloc(GetIt.I<ProductRepository>()));
  // ...

  // Seller real-time order broadcaster
  GetIt.I.registerLazySingleton<NewOrdersListener>(
    () => NewOrdersListener(GetIt.I<SupabaseClient>()),
    dispose: (listener) async => listener.dispose(),
  );
}

AppMode _getInitialMode() {
  final box = GetIt.I<Box>(instanceName: 'settings');
  final saved = box.get('app_mode') as String?;
  return saved == 'seller' ? AppMode.seller : AppMode.customer;
}

// Mode switcher — XAVFSIZ va leak-free
Future<void> switchAppMode(BuildContext context, AppMode newMode) async {
  // 1. Mode'ni saqla
  await GetIt.I<Box>(instanceName: 'settings').put('app_mode', newMode.name);

  // 2. Aktiv scope'ni dispose qilamiz — bu har registered singleton'ning
  //    dispose callback'ini avtomatik chaqiradi (RealtimeChannel.unsubscribe(),
  //    StreamSubscription.cancel(), va h.k.)
  await GetIt.I.popScope();

  // 3. Yangi mode scope'ini ochamiz
  await _initModeScope(newMode);

  // 4. Phoenix bilan widget tree'ni qayta tug'amiz
  //    DIQQAT: rebirth FAQAT widget tree'ni yangilaydi, GetIt'ga ta'sir qilmaydi.
  //    Shuning uchun popScope() oldindan chaqirilgani muhim.
  if (context.mounted) {
    Phoenix.rebirth(context);
  }
}
```

**Dispose pattern misollari:**

```dart
// Realtime subscription — Supabase channel
class OrderTrackingService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  OrderTrackingService(this._client);

  void watchOrders(String userId) {
    _channel = _client
      .channel('orders:user:$userId')
      .onPostgresChanges(...)
      .subscribe();
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe(); // CRITICAL: WebSocket yopiladi
    _channel = null;
  }
}

// BLoC — close() metodini override qiling
class CartBloc extends Bloc<CartEvent, CartState> {
  StreamSubscription? _cartSubscription;

  @override
  Future<void> close() async {
    await _cartSubscription?.cancel();
    return super.close();
  }
}
```

**Hive box'lar:** Root scope'da turadi va **mode switch'da yopilmaydi**. Sababi: cache, favorites, cart, settings — bularning hammasi mode'dan mustaqil. Faqat user logout bo'lganda tozalanadi (alohida flow).

**Eslatma — flutter_phoenix nuance:** `Phoenix.rebirth()` widget tree'ni qayta yaratadi, lekin `main()` qayta chaqirilmaydi. Shuning uchun GetIt scope manipulyatsiyasi `rebirth`'dan **oldin** qilinishi shart. Aks holda yangi widget tree eski mode dependencies bilan qoshiladi.

```dart
// lib/customer/customer_app.dart
class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => GetIt.I<AuthBloc>()),
        BlocProvider(create: (_) => GetIt.I<HomeBloc>()),
        BlocProvider(create: (_) => GetIt.I<CartBloc>()),
        // ... customer-specific blocs
      ],
      child: MaterialApp.router(
        title: 'Woody',
        theme: customerLightTheme,
        darkTheme: customerDarkTheme,
        routerConfig: customerRouter,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}

// lib/seller/seller_app.dart — exactly the same structure but for seller
```

### 5.3 Mode switch UX

**Customer mode'dan seller bo'lish:**

```
1. Profile screen → "Sotuvchi bo'lish" tugma
2. Onboarding bottom sheet:
   "Woody'da sotishni boshlang. 5 daqiqada ro'yxatdan o'ting."
   [Boshlash]
3. Multi-step form (still in customer app):
   - Yuridik holat (Jismoniy / YaTT / MChJ)
   - Do'kon nomi va tavsifi
   - Bog'lanish ma'lumotlari
   - Manzil
4. Verification choice:
   - "Passport rasmini yuborish" (manual, 1-3 kun)
   - "MyID orqali" (V2 da, hozir disabled)
5. Backend: POST /api/v1/seller/onboarding
   - seller_profile yaratiladi (status='pending')
   - shop yaratiladi (visibility='draft', tariff='free')
6. Success screen: "Tasdiqlash uchun yuborildi. 1-3 ish kuni ichida javob beramiz."
   [Sotuvchi rejimiga o'tish]
7. switchAppMode(context, AppMode.seller) → app restart
8. SellerApp ochiladi → Dashboard "Tasdiqlanmoqda" status bilan
```

**Tasdiqlangandan keyin seller'dan customer'ga qaytish:**

```
Seller app → Profile → "Xaridor rejimi" tugma → switchAppMode → restart → Customer app
```

**Birinchi marta login bo'lganda mode tanlash:**

Login screen common bo'ladi (auth/login_screen.dart). Login bo'lgandan keyin:
- Agar foydalanuvchining `seller_profile` yo'q → `app_mode = customer` (default)
- Agar bor va approved → ostidagi screen "Qaysi rejimga kirasiz?" deb so'raydi (faqat birinchi safar):
  - 🛍️ Xaridor sifatida
  - 🏪 Sotuvchi sifatida

### 5.4 Deferred component'lar (bundle size optimization)

Seller-specific og'ir paketlar (`fl_chart`, `pdf`, `qr_flutter`) faqat seller app'da `import` qilinadi. Customer app build'i bularga referens bermaydi → tree-shaking ularni olib tashlaydi.

**Lekin** ikkala app bitta APK'da bo'lgani uchun bu paketlar baribir APK'ga kiradi. Real bundle saving uchun **Flutter deferred imports** ishlatish mumkin:

```dart
// seller_app.dart
import 'features/analytics/analytics_screen.dart' deferred as analytics;

// foydalanish:
Future<void> openAnalytics(BuildContext context) async {
  await analytics.loadLibrary();
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => analytics.AnalyticsScreen(),
  ));
}
```

**Lekin diqqat:** deferred loading hali ham flaky, ayniqsa iOS'da. MVP'da oddiy import qiling, optimization keyinroq.

### 5.5 Realtime integratsiyasi

Order status update'lar uchun Supabase Realtime:

```dart
// lib/seller/features/orders/data/realtime_orders_source.dart
class RealtimeOrdersSource {
  final SupabaseClient _supabase;
  StreamSubscription? _subscription;

  Stream<Order> watchNewOrders(String shopId) {
    final controller = StreamController<Order>();

    _subscription = _supabase
      .channel('public:orders:shop_id=eq.$shopId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'shop_id',
          value: shopId,
        ),
        callback: (payload) {
          final order = Order.fromJson(payload.newRecord);
          controller.add(order);
        },
      )
      .subscribe();

    return controller.stream;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
```

---

## 6. Seller Verification Flow

### 6.1 Manual verification (V1 — birinchi yo'l)

**Foydalanuvchi tomonidan:**

1. Seller onboarding'dan keyin "Verification" sahifasiga o'tadi
2. Yuklash kerak bo'lgan hujjatlar:
   - **Jismoniy shaxs** uchun:
     - Passport old tomon (rasm yoki PDF)
     - Passport orqa tomon
     - Selfie (passport bilan)
   - **YaTT (yakka tartibdagi tadbirkor)** uchun:
     - Yuqoridagilar +
     - YaTT guvohnomasi (PDF)
     - STIR
   - **MChJ** uchun:
     - Direktor passporti (yuqoridagi kabi)
     - MChJ ustavi (PDF)
     - Davlat ro'yxat guvohnomasi
     - STIR
3. Hujjatlar Supabase Storage'ga yuklanadi (`verification/` bucket, private)
4. Backend: `POST /api/v1/seller/verification/manual` chaqiriladi:
   ```json
   {
     "passport_front_url": "...",
     "passport_back_url": "...",
     "selfie_url": "...",
     "business_certificate_url": null,
     "inn": "123456789"
   }
   ```
5. `seller_profile.verification_status = 'in_review'` ga o'tadi
6. Admin'ga notifikatsiya (Telegram bot + web admin queue)

**Admin tomonidan:**

Web admin / Telegram bot orqali:

1. Pending list'dan tanlaydi
2. Hujjatlarni ko'radi (rasmlarni zoom qiladi)
3. Tasdiqlash yoki rad etish:
   - **Approve** → `verification_status = 'approved'`, `verification_method = 'manual'`, `verified_at = NOW()`. Foydalanuvchiga push notif: "Sotuvchi sifatida tasdiqlandingiz!"
   - **Reject** → `verification_status = 'rejected'`, `rejection_reason` to'ldiriladi. Push notif: "Hujjatlaringiz qabul qilinmadi: <sabab>"

**SLA:** 1-3 ish kuni (admin panelda taymer bilan).

### 6.2 MyID Verification (V2 — keyingi faza)

MyID — O'zbekiston Respublikasining elektron raqamli identifikatsiya tizimi (https://myid.uz). Ikki integratsiya rejimi bor:

**1. MyID OAuth flow (avtomatik):**

```
1. User → "Verify via MyID" tugma
2. App → Backend: GET /api/v1/seller/verification/myid/url
3. Backend → MyID API: POST /oauth2/authorize → redirect URL
4. User browser'da MyID portaliga o'tadi
5. User passport ma'lumotlarini tasdiqlaydi (face ID + biometric)
6. MyID → Backend webhook: /api/v1/webhooks/myid?code=...&state=...
7. Backend → MyID: token exchange → user data
8. Backend: seller_profile ni MyID ma'lumotlari bilan to'ldiradi
9. verification_status = 'approved' (avtomatik!)
```

**2. MyID Document API (qo'lda upload bilan):**

User passport bilan selfie yuboradi → backend MyID API'ga yuboradi → MyID face match + passport OCR → response.

**Muhim eslatmalar (MyID haqida halol):**

- API access **majburiy yuridik shaxs** (MChJ yoki YaTT registratsiyasi). Solo physical person ololmaydi.
- API approval 2-4 hafta (hujjatlar topshirib, shartnoma imzolash)
- Har verification chaqirig'i **pulli** (~5,000–15,000 so'm, hajmga bog'liq)
- Sandbox mavjud, lekin test data cheklangan
- Production'ga chiqish uchun whitelist'ga IP qo'shtirish kerak

**Tavsiya:** MyID integration'ni V2 ga qoldir, V1'da faqat manual. Bu sening biznesingni tezroq ishga tushirishga yordam beradi.

### 6.3 Verification status'ga ta'sirlar

| Status | Ko'rinish | Mahsulot qo'shish | Order qabul qilish | Rangi |
|--------|-----------|-------------------|--------------------|-------|
| `pending` | "Hujjatlar yuklash kerak" | ❌ | ❌ | gray |
| `in_review` | "Tasdiqlash kutilmoqda" | ❌ | ❌ | yellow |
| `approved` | "Tasdiqlangan ✓" | ✅ | ✅ | green |
| `rejected` | "Rad etildi: <sabab>" | ❌ | ❌ | red |

Customer side'da:
- Tasdiqlangan do'kon yonida ✓ "Verified" yorlig'i
- Rejected/pending sotuvchi mahsulotlari catalog'da ko'rinmaydi

---

## 7. Tariff System (Seller Subscriptions)

### 7.1 Boshlang'ich tariflar (seed data)

```
┌─────────────┬─────────┬──────────┬─────────┬──────────────────────────────┐
│ Tariff      │ Price/m │ Products │ Comm %  │ Features                     │
├─────────────┼─────────┼──────────┼─────────┼──────────────────────────────┤
│ Free        │ 0       │ 10       │ 5%      │ Basic listing                │
│ Basic       │ 99,000  │ 100      │ 3%      │ + Priority support           │
│ Pro         │ 299,000 │ ∞        │ 2%      │ + Analytics, Featured slots  │
│ Enterprise  │ Custom  │ ∞        │ Custom  │ + Manager, custom features   │
└─────────────┴─────────┴──────────┴─────────┴──────────────────────────────┘
```

(Narxlar va limitlar misol uchun, sen real biznes-strategiyangga moslashtiringiz.)

### 7.2 Tariff lifecycle

**Default**: yangi sotuvchi = `free` tariff.

**Upgrade flow (V1 — manual):**

```
1. Seller → Tariff sahifasi → "Upgrade to Pro" tugma
2. App → Backend: POST /api/v1/seller/tariff/upgrade { "tariff_code": "pro" }
3. Backend:
   - subscriptions jadvaliga `status='pending_payment'` yaratadi
   - Admin'ga notifikatsiya
4. Admin foydalanuvchi bilan bog'lanadi (telegram), to'lovni qo'lda qabul qiladi
5. Admin web admin'da "Confirm payment" tugma → backend:
   - subscriptions.status = 'active'
   - shops.tariff_id, tariff_started_at, tariff_expires_at update
   - Push notif sellerga
```

**V2'da:** Click/Payme integration → avtomatik upgrade.

**Expiration handling:**

Cron job har kuni 09:00:
- Tariff'i 7 kun ichida tugaydiganlarga: "Tariff expiring" notifikatsiya
- Tariff'i tugaganlarga: avtomatik `free` ga downgrade
  - Cheklov: agar `free.max_products = 10` bo'lsa va sellerda 50 mahsulot bor — 40tasi `archived` ga o'tadi (chiroyli pattern: eng kam ko'rilganlardan boshlab)

### 7.3 Tariff limit enforcement

Mahsulot qo'shishda:

```python
# app/services/product_service.py
async def create_product(db, seller_profile, payload) -> Product:
    shop = seller_profile.primary_shop
    tariff = shop.tariff

    if tariff.max_products is not None:
        current_count = await product_repo.count_active_for_shop(db, shop.id)
        if current_count >= tariff.max_products:
            raise BusinessError(
                code="tariff_limit_exceeded",
                message=f"Tariff limit: {tariff.max_products} products"
            )

    # ... create product
```

---

## 8. Admin Tools

### 8.1 Web Admin (Next.js)

**Stack:**
- Next.js 15 (App Router)
- TypeScript
- shadcn/ui (yoki Refine.dev — admin framework)
- TanStack Query (data fetching)
- Supabase Auth (admin role check)
- Recharts (grafiklar)

**Sahifalar (V1):**

```
/login                    — Supabase Auth, role='admin' guard
/                         — Dashboard (KPI: today orders, revenue, pending verifications)
/users                    — DataTable, filter, ban/unban
/users/[id]               — Detail
/sellers/pending          — Verification queue (priority)
/sellers/[id]             — Hujjatlar ko'rish, approve/reject
/products/pending         — Moderation queue
/products/[id]            — Detail, approve/reject
/orders                   — Filter, status, export CSV
/tariffs                  — CRUD
/categories               — Tree CRUD (drag & drop ordering)
/banners                  — CRUD
/audit                    — Full text search
/broadcast                — Push notification yuborish
```

**Hosting:** Vercel free tier (sen uchun yetarli).

### 8.2 Telegram Admin Bot

**Stack:** Python + `aiogram 3.x` (modern, async)

**Komanda ro'yxati:**

```
/start                    — Auth check
/dashboard                — Bugungi stats (kratkiy)
/pending                  — Pending counts: sellers, products, orders
/sellers                  — Pending sellers list (inline keyboard)
/seller_<id>              — Detail (deep link from button)
/products                 — Pending products list
/orders                   — Recent orders
/order_<id>               — Detail
/users <query>            — Search by phone/email
/audit                    — Last 20 audit logs
/broadcast                — Multi-step: target audience, message, send
/web                      — Magic link to web admin
/help                     — Komandalar
```

**Auto notifikatsiyalar:**

- Yangi seller registration → "🆕 Yangi sotuvchi: Shop X. Tasdiqlash uchun: /seller_<id>"
- Yangi order → "🛒 Yangi order #ORD-2026-00123 — 1,250,000 so'm — Shop Y"
- 7 kun ichida tariff expiring (sellerlar uchun siz uchun emas)
- Daily summary 23:00: "📊 Bugun: 15 order, 12,500,000 so'm, 3 yangi seller"

**Auth:**

```python
# allowed admin telegram IDs (.env)
ADMIN_IDS = [123456789, 987654321]

@router.message()
async def auth_filter(message: Message):
    if message.from_user.id not in ADMIN_IDS:
        return
    # ... continue
```

**Deployment:**

- Long-polling mode (sodda)
- Backend bilan bir process'da `arq` worker ostida ishlasa bo'ladi
- Yoki alohida small Railway service ($5/oy)

---

## 9. Storage Strategy (Supabase Storage)

### 9.1 Bucket'lar

| Bucket | Public/Private | Access | Maqsad |
|--------|----------------|--------|--------|
| `products` | Public read | Seller write (own products) | Mahsulot rasmlari |
| `shops` | Public read | Owner write | Logo, cover |
| `avatars` | Public read | Owner write | User avatar |
| `banners` | Public read | Admin write | Asosiy sahifa bannerlari |
| `verification` | **Private** | Owner write, Admin read | Passport, hujjatlar |
| `categories` | Public read | Admin write | Kategoriya rasmlari |

### 9.2 Image processing

Mobile app yuborgan rasm:
1. Client side resize (max 2048x2048, JPG quality 85)
2. Backend `POST /api/v1/seller/products/{id}/images` qabul qiladi
3. Backend Pillow (Python) bilan:
   - Original (max 2048px)
   - Thumbnail (300x300, srcset uchun)
   - Watermark (optional, shop logo bilan)
4. Supabase Storage'ga yuklaydi (3 ta variant)
5. `product_images` jadvaliga URL'lar yoziladi

### 9.3 Verification hujjatlari va Signed URL strategiya

> **Performance muammosi:** private bucket'dan har rasm ko'rsatish uchun Supabase'ga signed URL so'rash kerak. Admin moderation queue'sida 50 ta sotuvchi × 3 ta hujjat = **150 ta API chaqirig'i** har sahifa ochilganda. Bu admin panel'ning eng sekin bo'lagiga aylanadi.

**Yechim: Backend-side caching + batch endpoint.**

#### Strategiya

1. Verification hujjatlari `verification/` bucket'da (private) saqlanadi
2. Admin so'rovida backend **bir vaqtda barcha kerakli URL'larni** generate qiladi
3. URL'lar Redis'da **cache** qilinadi (TTL = signed URL valid muddatdan kichikroq)
4. Browser'da TanStack Query `staleTime` bilan keyingi cache layer

#### Backend implementation

```python
# app/services/storage_service.py
from datetime import timedelta
from typing import Iterable

class StorageService:
    SIGNED_URL_TTL = timedelta(hours=1)
    CACHE_TTL = timedelta(minutes=50)  # 10 daqiqa buffer

    def __init__(self, supabase: SupabaseClient, redis: Redis):
        self.supabase = supabase
        self.redis = redis

    async def get_signed_urls(
        self,
        bucket: str,
        paths: Iterable[str],
    ) -> dict[str, str]:
        """Batch signed URL generation with Redis cache."""
        result: dict[str, str] = {}
        missing: list[str] = []

        # 1) Redis'dan cached URL'larni o'qish
        cache_keys = [f"signed_url:{bucket}:{p}" for p in paths]
        cached = await self.redis.mget(cache_keys)

        for path, cached_url in zip(paths, cached):
            if cached_url:
                result[path] = cached_url.decode()
            else:
                missing.append(path)

        # 2) Etishmagan URL'larni Supabase'dan batch fetch
        if missing:
            response = self.supabase.storage.from_(bucket).create_signed_urls(
                paths=missing,
                expires_in=int(self.SIGNED_URL_TTL.total_seconds()),
            )
            # 3) Redis'ga save (pipeline bilan tezroq)
            pipe = self.redis.pipeline()
            for item in response:
                path = item["path"]
                url = item["signedURL"]
                result[path] = url
                pipe.setex(
                    f"signed_url:{bucket}:{path}",
                    int(self.CACHE_TTL.total_seconds()),
                    url,
                )
            await pipe.execute()

        return result
```

#### Admin batch endpoint

```python
# app/api/v1/admin/storage.py
from pydantic import BaseModel

class SignedUrlsRequest(BaseModel):
    bucket: str
    paths: list[str]  # max 50 per request

class SignedUrlsResponse(BaseModel):
    urls: dict[str, str]

@router.post("/admin/storage/signed-urls", response_model=SignedUrlsResponse)
async def get_signed_urls(
    payload: SignedUrlsRequest,
    admin: Profile = Depends(require_admin),
    storage: StorageService = Depends(get_storage_service),
):
    if len(payload.paths) > 50:
        raise HTTPException(400, "Max 50 paths per request")
    urls = await storage.get_signed_urls(payload.bucket, payload.paths)
    return SignedUrlsResponse(urls=urls)
```

#### Web admin (Next.js) — TanStack Query layer

```typescript
// hooks/useSignedUrls.ts
export function useSignedUrls(bucket: string, paths: string[]) {
  return useQuery({
    queryKey: ['signed-urls', bucket, paths.sort().join(',')],
    queryFn: async () => {
      const res = await api.post('/admin/storage/signed-urls', {
        bucket,
        paths,
      });
      return res.data.urls as Record<string, string>;
    },
    // Backend Redis cache 50 daqiqa, browser cache 45 daqiqa
    staleTime: 45 * 60 * 1000,
    gcTime: 60 * 60 * 1000,
  });
}

// Verification queue sahifasida ishlatish
function VerificationQueue() {
  const { data: pending } = useQuery({ queryKey: ['pending-sellers'], ... });

  // Barcha kerakli path'larni bir vaqtda yig'amiz
  const allPaths = useMemo(
    () => pending?.flatMap(s => [
      s.passport_front_url,
      s.passport_back_url,
      s.selfie_with_passport_url,
    ].filter(Boolean)) ?? [],
    [pending],
  );

  // BITTA so'rov bilan barcha URL'lar
  const { data: urls } = useSignedUrls('verification', allPaths);

  return pending?.map(seller => (
    <SellerCard
      key={seller.id}
      seller={seller}
      passportFrontUrl={urls?.[seller.passport_front_url]}
      // ...
    />
  ));
}
```

#### Image preloading

Verification rasmlari odatda 1-3 MB. Admin sahifani ochganda rasmlar ko'rinmaydi → URL keladi → rasm yuklanadi (slow). Yaxshilanish:

```tsx
// Sahifa ochilganda darhol prefetch
<link rel="preload" as="image" href={passportFrontUrl} />

// yoki Next.js Image component bilan priority
<Image src={passportFrontUrl} priority alt="Passport front" />
```

#### Mobile app (seller)

Sotuvchi o'z verification holati sahifasida o'z hujjatlarini ko'radi. Bu yerda 3-5 ta rasm — caching kerak emas, har sessiyada qaytadan signed URL olish maqbul. Lekin **mobile app cache'da signed URL'ni saqlamasin** — TTL muammosi (foydalanuvchi 2 soatdan keyin ochsa expired URL).

#### Xulosa

| Layer | Cache TTL | Saqlash joyi |
|-------|-----------|--------------|
| Supabase signed URL | 1 soat | — (Supabase ichida) |
| Backend Redis | 50 daqiqa | Server |
| Browser TanStack Query | 45 daqiqa | Memory |
| Mobile app | **Cache QILMA** | — |

Bu pattern admin panel'ni 150 API call → 1 API call'ga tushuradi.

---

## 10. Localization Strategy

### 10.1 UI matnlari

`easy_localization` — `assets/translations/{uz,ru,en}.json`:

```json
// uz.json
{
  "common": {
    "save": "Saqlash",
    "cancel": "Bekor qilish",
    "loading": "Yuklanmoqda..."
  },
  "auth": {
    "login": "Kirish",
    "register": "Ro'yxatdan o'tish"
  },
  "products": {
    "out_of_stock": "Mavjud emas",
    "in_stock": "Mavjud"
  }
}
```

### 10.2 Content matnlari

Backend'dan kelgan multilingual content (`{uz, ru, en}` JSONB) Dart'da:

```dart
// shared/models/multilingual_text.dart
class MultilingualText {
  final String? uz;
  final String? ru;
  final String? en;

  String get(String lang) {
    return switch (lang) {
      'ru' => ru ?? uz ?? en ?? '',
      'en' => en ?? uz ?? ru ?? '',
      _ => uz ?? ru ?? en ?? '',
    };
  }
}

// Ishlatish
Text(product.name.get(currentLanguage))
```

### 10.3 Tilni o'zgartirish

- Profile → Til tanlash
- App restart **shart emas** — `easy_localization.setLocale()` reactive
- Backend ham `Accept-Language` header'iga qarab javob qaytaradi (kelajakda — V1'da JSONB butun obyektda yuboriladi, frontend tanlaydi)

---

## 11. Security & Privacy

### 11.1 Asosiy tamoyillar

1. **Hech qanday password backend'da saqlanmaydi** — Supabase Auth boshqaradi
2. **JWT verify har endpoint'da** — middleware bilan
3. **Rate limiting** (FastAPI middleware: `slowapi`):
   - Login attempts: 5 / 15min / IP
   - SMS OTP (V2): 3 / hour / phone
   - General API: 100 / minute / user
4. **CORS strict**: faqat known origins
5. **Supabase RLS minimal** — Python backend authorization main, RLS faqat fallback
6. **Verification hujjatlari encrypted at rest** (Supabase default)
7. **PII access audit qilinadi** — `audit_logs`'da yozish
8. **Sensitive logs masked** — passport raqamlari, tokenlar

### 11.2 Critical bo'limlar

| Endpoint | Threat | Mitigation |
|----------|--------|------------|
| Verification upload | Fake hujjatlar | Manual review, MyID (V2) |
| Order creation | Race condition (stock) | Postgres `SELECT ... FOR UPDATE` lock |
| Tariff change | Privilege escalation | Faqat admin, audit log |
| Admin endpoints | Compromise | IP whitelist (optional), 2FA (V2) |
| File upload | Malicious file | MIME check, size limit, virus scan (V2) |
| Order cancellation | Abuse | State machine validation |

### 11.3 Privacy

- Foydalanuvchi `DELETE /api/v1/me` — soft delete (90 kun keyin hard delete)
- Soft delete: `deleted_at` to'ldiriladi, lekin `auth.users` hali qoladi (orderlar uchun reference)
- 90 kundan keyin GDPR-compliant hard delete (cron job)
- Verification hujjatlari verified bo'lgandan keyin **6 oy ichida o'chiriladi** (compliance)

---

## 12. Development & Deployment

### 12.1 Local development

```bash
# 1. Supabase CLI orqali local Supabase
supabase init
supabase start  # Postgres + Auth + Storage container'lar ko'tariladi

# 2. Backend
cd mebellar-backend
poetry install
cp .env.example .env  # SUPABASE_URL=http://localhost:54321 ...
poetry run uvicorn app.main:app --reload

# 3. Mobile
cd mebellar-app
flutter pub get
flutter run --dart-define=ENV=dev
```

### 12.2 CI/CD

**Backend:** GitHub Actions
- On push to `main`:
  - Lint (ruff), type check (mypy), test (pytest)
  - Build Docker image
  - Deploy to Railway/Fly.io

**Mobile:**
- On push to `main`:
  - Test (flutter test)
  - Build APK + IPA (Codemagic / GitHub Actions with Fastlane)
  - Internal testing track (Play Console)

**Web admin:** Vercel auto-deploy on push.

### 12.3 Environments

| Env | Backend | Supabase | Mobile build |
|-----|---------|----------|--------------|
| dev | localhost | local | `--dart-define=ENV=dev` |
| staging | staging.api.mebellar.uz | staging Supabase project | `--dart-define=ENV=staging` |
| prod | api.mebellar.uz | prod Supabase project | `--dart-define=ENV=prod` |

### 12.4 Hosting region — CRITICAL

> **Performance muammosi:** Python backend va Supabase Postgres o'rtasida har request 5-15 ta SQL query bo'ladi. Agar ular **turli kontinentlarda** joylashgan bo'lsa, har query'da 100-200ms qo'shimcha kechikish, **jami so'rov 1-3 sekund** uzayadi. Bu user'ni ko'radigan latency.

**Qoida:** FastAPI backend va Supabase **albatta bitta region**'da bo'lishi shart.

#### O'zbekiston foydalanuvchilari uchun region tanlash

Supabase regionlari (https://supabase.com/docs/guides/platform/regions):

| Supabase region | Toshkent latency (ping) | Tavsif |
|-----------------|--------------------------|--------|
| `eu-central-1` (Frankfurt) | ~80-120ms | **TAVSIYA** — kabel marshruti yaxshi |
| `ap-south-1` (Mumbai) | ~100-150ms | Geografik yaqin, lekin marshruti har xil |
| `eu-west-2` (London) | ~110-140ms | Alternativa |
| `ap-southeast-1` (Singapore) | ~150-200ms | Sekinroq |
| `us-east-1` | 200ms+ | **TANLAMANG** |

**Tavsiya: `eu-central-1` (Frankfurt)** — eng yaxshi balans.

#### Backend hosting Frankfurt'da

| Provider | Frankfurt mintaqasi | Status |
|----------|--------------------|--------|
| **Fly.io** | `fra` (Frankfurt) | ✅ Bevosita qo'llab-quvvatlaydi |
| **Railway** | `europe-west4` (Amsterdam) | ✅ Yaqin (~150km Frankfurt'dan, ~5ms) |
| **Render** | Frankfurt | ✅ Qo'llab-quvvatlaydi |
| **Hetzner Cloud** | Falkenstein/Nuremberg (DE) | ✅ Eng arzon, manual setup |

**Boshlash uchun:** Fly.io Frankfurt — `fly.toml`'da:

```toml
primary_region = "fra"
```

#### Latency budget

So'rovlar uchun maqsadli budget:

| Komponent | Target latency |
|-----------|---------------|
| Tashkent → Frankfurt backend (TLS handshake) | ~100ms |
| Backend → Supabase Postgres (same region) | <5ms per query |
| Backend processing (5 queries + business logic) | ~50ms |
| Frankfurt backend → Tashkent response | ~100ms |
| **Jami end-to-end** | **~250-300ms** |

Agar backend Frankfurt'da, Supabase US-East'da bo'lsa: Frankfurt → Virginia ~100ms × 5 query = +500ms, jami 750-800ms. Bu **3x sekinroq**.

#### Qanday tekshirish kerak

Boshlanishidan oldin sinab ko'ring:

```bash
# Tashkent'dagi mashinangizdan
ping -c 10 db.<your-project>.supabase.co

# Backend deploy qilingandan keyin (Fly.io)
fly ssh console
ping -c 10 db.<your-project>.supabase.co  # bu <5ms bo'lishi shart
```

Agar `fly ssh console` ichidan Supabase'ga ping >50ms — region noto'g'ri.

#### CDN va static assets

Supabase Storage'ning o'z CDN'i bor (CloudFront), lekin global cache emas. Mahsulot rasmlari uchun Cloudflare CDN qo'shish (V2):

- O'zbekiston'da Cloudflare PoP yo'q, lekin Singapur/Frankfurt PoP tezroq
- Xayolda: `mebellar.uz` → Cloudflare → Supabase Storage origin
- Birinchi request slow (50-100ms cache miss), keyingilari tezkor (<20ms)

V1'da bu shart emas — to'g'ridan-to'g'ri Supabase Storage URL'lari ishlatish maqbul.

---

## 13. Migration Plan (Greenfield Phasing)

### Bosqich 0 — Tayyorgarlik (1 hafta)

- [ ] Supabase project yaratish (free tier, dev + prod)
- [ ] GitHub repo'lar (`mebellar-backend`, `mebellar-app`, `mebellar-admin-web`, `mebellar-bot`)
- [ ] Domain sotib olish (`mebellar.uz`), DNS sozlash
- [ ] Branding minimal (logo, colors)
- [ ] Railway/Fly.io account, Vercel account

### Bosqich 1 — DB schema + Backend skeleton (2 hafta)

- [ ] Supabase migrations: hamma jadvallarni yozish
- [ ] `handle_new_user()` trigger (auth.users → profiles avtomatik sync)
- [ ] Seed data: regions, categories, tariffs, service_types
- [ ] FastAPI loyiha skeleton
- [ ] JWT verification (Supabase JWKS), `/me` endpoint
- [ ] Health checks, logging, Sentry
- [ ] Hosting: Fly.io Frankfurt (`fra` region), Supabase `eu-central-1`
- [ ] Deploy to staging (basic)

### Bosqich 2 — Mobile skeleton (2 hafta)

- [ ] Flutter loyiha, dual entry point
- [ ] Auth screens (login, register, email verify)
- [ ] AppMode switching (Phoenix)
- [ ] DI, theming, localization (uz/ru/en)
- [ ] Customer + Seller bottom navigation skeleton
- [ ] Supabase SDK + Dio integration

### Bosqich 3 — Customer features (3-4 hafta)

- [ ] Catalog (list, filter, search)
- [ ] Product detail
- [ ] Cart (server-side)
- [ ] Checkout (mock payment, address selection)
- [ ] Order list + tracking
- [ ] Favorites
- [ ] Profile + addresses

### Bosqich 4 — Seller features (3-4 hafta)

- [ ] Onboarding (multi-step form)
- [ ] Manual verification flow (upload + status)
- [ ] Shop settings (logo, cover, info)
- [ ] Product CRUD (with images)
- [ ] Orders list + actions (confirm, ship, deliver, cancel)
- [ ] Dashboard (basic stats)
- [ ] Tariff page (view + upgrade request)
- [ ] Services configuration

### Bosqich 5 — Admin tooling (2 hafta)

- [ ] Next.js web admin: auth, dashboard, sellers queue, products queue, orders
- [ ] Telegram bot: auth, key commands, notifications
- [ ] Audit log viewing

### Bosqich 6 — Polish + QA (2 hafta)

- [ ] Edge case handling
- [ ] Error states, empty states
- [ ] Performance: lazy loading, image caching, pagination
- [ ] Translations review (native speakers)
- [ ] Internal testing (5-10 friends/family)

### Bosqich 7 — Launch prep (2 hafta)

- [ ] App Store assets (screenshots, descriptions, metadata)
- [ ] Privacy policy, ToS (yuridik konsultatsiya)
- [ ] App Store + Play Store submission
- [ ] Marketing landing page
- [ ] Onboarding tutorial in-app

**Jami: ~16-19 hafta = 4-5 oy** (haftada 35-40 soat).

**Realistik**: solo dev rewrite project'lar 2x kechikadi → **8-10 oy** kutib turish kerak. Buni rejaga kirit.

---

## 14. Risks & Mitigations

| Risk | Ehtimol | Ta'sir | Mitigation |
|------|---------|--------|------------|
| Solo dev burnout | **Yuqori** | **Kritik** | Realistic timeline (8-10 oy), MVP scope strict, scope creep'ga "yo'q" |
| Supabase vendor lock-in | O'rta | Yuqori | RLS minimal, business logic Python'da, schema standart Postgres |
| Python ekosistemasiga adaptatsiya | O'rta | O'rta | FastAPI hujjatlash, kichik PoC oldindan |
| MyID approval delay | Yuqori | O'rta | V1'da manual only, MyID V2 |
| App Store rejection | O'rta | Yuqori | Guidelines o'qish, test account beruv, content moderation |
| Yuridik shaxs kerakligi | Yuqori | Yuqori | YaTT tezroq ochish (1-2 hafta) — to'lov, MyID, App Store uchun |
| Image storage costs | Past | O'rta | Compression, thumbnail strategy, cleanup cron |
| RLS bug → data leak | O'rta | **Kritik** | RLS minimal ishlatish, Python authorization main, test coverage |
| Deferred component flakiness | O'rta | Past | MVP'da disabled, V2'da optional |
| Bundle size oshib ketishi | Yuqori | O'rta | Asset compression, tree-shaking, deferred imports keyinroq |
| Sotuvchi onboarding'da abandonment | Yuqori | Yuqori | Multi-step, save progress, "verify keyinroq" opsiya |
| Kunlik admin yuk | O'rta | O'rta | Telegram bot, web admin, audit auto-log |

---

## 15. Costs (oylik)

### Boshlang'ich (0-1000 user)

| Item | Cost |
|------|------|
| Supabase Free tier | $0 |
| Railway (backend + bot) | $5-10 |
| Vercel (web admin) | $0 |
| Domain (.uz) | ~$30/yil |
| OneSignal | $0 |
| Sentry | $0 (free tier) |
| **Jami** | **~$10-15/oy** |

### Growth (1K-10K user)

| Item | Cost |
|------|------|
| Supabase Pro | $25 |
| Railway scaling | $20-40 |
| Vercel | $0 (still free) |
| OneSignal | $0 |
| Eskiz SMS (V2) | $20-50 |
| MyID API calls (V2) | $50-100 |
| Sentry | $26 (Team plan) |
| **Jami** | **~$140-240/oy** |

### Scale (10K-100K user)

| Item | Cost |
|------|------|
| Supabase Team | $599 |
| Backend (multi-region) | $100-200 |
| CDN (Cloudflare Pro) | $20 |
| Sentry Business | $80 |
| **Jami** | **~$800-1000/oy** |

(Bu rejada endi solo dev emas, kichik komanda kerak.)

---

## 16. Open Questions

Bu savollarga javob bermasdan TZ to'liq emas. Iloji boricha tezroq aniqlik kiritish kerak:

### 16.1 Biznes savollari

1. **Sotuvchi modeli:** marketplace komissiyasi nechta foiz? (Wildberries 5-15%, Ozon 5-30%, Etsy 6.5%). Bu sening tariff narxlariga ta'sir qiladi.
2. **Dispute resolution:** customer order'dan norozi bo'lsa kim qaror qabul qiladi? Sen, sotuvchi, refund policy?
3. **Sotuvchiga to'lov:** customer naqd to'lasa, sotuvchi pulni o'zi oladi. Kelajakda online to'lov bo'lsa — sen platforma sifatida pulni qabul qilasanmi va sotuvchiga keyinroq o'tkazasanmi (escrow)? Yoki direct seller'ga? Bu juridik va texnik jihatdan katta savol.
4. **Yetkazib berish:** sen umumiy yetkazib berish servis'i bo'lasanmi (Yandex Go, masalan), yoki har sotuvchi o'zi tashkillaydimi? V1'da har sotuvchi o'zi — bu sodda.

### 16.2 Texnik savollar

5. **Foydalanuvchi soni 1-yil ichida prognozi?** 1K, 10K, 100K? Bu Supabase tier va backend resurslarga ta'sir qiladi.
6. **Geolokatsiya:** faqat O'zbekistonmi yoki kelajakda Markaziy Osiyo? Bu localization, currency, regions schema'siga ta'sir qiladi.
7. **Multi-warehouse logistika:** bitta sotuvchining bir nechta filiali bo'lishi mumkinmi? V1'da yo'q deb belgilash, V2'da ko'rib chiqish.
8. **Web app kerakmi?** Faqat mobile + admin web yoki customer uchun ham web (mebellar.uz)? Web bo'lsa Flutter Web yoki Next.js? (Tavsiya: V1 mobile only, V2 web).
9. **Chat:** customer-seller chat V1'da kerakmi? Yo'q deb belgiladim, lekin sen tasdiqla.

### 16.3 Yuridik / operatsion

10. **YaTT/MChJ ochilganmi?** App Store, MyID, to'lov tizimlari uchun majburiy.
11. **Privacy Policy / ToS** kim yozadi? Yurist bilan maslahatlashish.
12. **Verification hujjatlari saqlash muddati** O'zbekiston qonunchiligida nima talab qilinadi?
13. **Yangi sotuvchini intervyu qilasanmi** yoki faqat hujjat yetadimi? UX'ga ta'sir.

---

## 17. Yakuniy tavsiyalar

### ✅ KUCHLI TOMON

1. **Greenfield rewrite** real foyda — Play Store'da bo'lmagani uchun migration risk yo'q
2. **Dual-entry pattern** to'g'ri tanlov — birlashtirilgan single-app'dan yaxshi, alohida ikki app'dan sodda
3. **Supabase + Python hybrid** — pragmatik, vendor lock-in minimal
4. **Manual verification fallback** — MyID API blokada bo'lganida ham ishlay olasan

### ⚠️ DIQQAT QILISH KERAK

1. **Solo dev timeline** — 8-10 oy realistik, 4-5 oy optimistik. Burnout dan saqlanish uchun MVP strict.
2. **Tariff system'ni murakkab qilmang** — V1'da 2-3 tariff yetadi, manual upgrade
3. **Verification UX** — abandonment yuqori bo'ladi, save progress majburiy
4. **YaTT/MChJ** — App Store, MyID, payment uchun **majburiy**, V1 boshlanishidan oldin oching

### ❌ QILMANG

1. **MyID'ni V1'ga kirgizmang** — manual yetadi, MyID approval kutadi
2. **Real to'lovni V1'ga kiritmang** — mock checkout, "naqd" yetadi, real payment murakkab integration
3. **Chat'ni V1'ga kiritmang** — alohida feature, alohida vaqt
4. **Multi-shop'ni V1'ga kiritmang** — schema tayyor, lekin UI 1 shop / 1 seller
5. **Web app'ni V1'ga qo'shmang** — mobile birinchi, web bo'lsa keyin

---

## 19. Architectural Refinements (Review v1.1)

Bu bo'lim TZ v1.0 review jarayonida aniqlangan **kritik xavotirlar** va ularning yechimlarini saqlab qo'yadi. Hujjat asosiy bo'limlarida tegishli qismlar yangilangan, lekin trace qilish uchun bu yerda qisqacha jamlangan.

### 19.1 Auth Sync race condition — **HAL QILINDI**

**Muammo:** Mobile app Supabase Auth'da signup qilib, keyin Python backend'ga `/auth/sync` so'rovini yuborayotganda internet uzilsa — foydalanuvchi `auth.users`'da bor, lekin `public.profiles`'da yo'q. "Yetim foydalanuvchi" muammosi.

**Yechim:** Postgres `AFTER INSERT ON auth.users` trigger orqali **atomik** profile yaratish. Tafsilotlar: **§4.3**.

**Ta'sir:** `POST /api/v1/auth/sync` endpoint'i o'chirib tashlandi. Mobile app endi backend'ga sync chaqirig'i yubormaydi.

### 19.2 GetIt + memory leaks — **HAL QILINDI**

**Muammo:** Mode switch'da `GetIt.I.reset()` chaqirilganda Hive box'lar, Supabase RealtimeChannel'lar, Dio HTTP client'lar va StreamSubscription'lar `dispose` chaqirilmasdan tashlanardi → memory leak, "ghost" WebSocket connections.

**Yechim:** Ikki qatlamli DI:
- **Root scope** (Hive, Supabase, Dio, Auth) — app boot vaqtida bir marta yaratiladi, mode switch'da saqlanadi
- **Mode scope** (BLoC'lar, realtime listeners, mode-specific repos) — `pushNewScope()` orqali, `popScope()` da avtomatik dispose

Har singleton `dispose:` callback bilan ro'yxatga olinadi. Tafsilotlar: **§5.2**.

### 19.3 Backend ↔ Supabase latency — **REGION QOIDASI BELGILANDI**

**Muammo:** FastAPI va Supabase turli regionlarda bo'lsa, har request 1-3 soniya kechikishi mumkin.

**Yechim:** Majburiy region matching qoidasi. Backend va Supabase **albatta `eu-central-1` (Frankfurt)**'da. Tafsilotlar: **§12.4**.

**Latency budget:**
- Backend ↔ DB: <5ms per query (same region)
- Tashkent ↔ Frankfurt: ~100ms (TLS handshake)
- End-to-end target: 250-300ms

### 19.4 Signed URL caching for admin — **HAL QILINDI**

**Muammo:** Verification queue ochilganda 50 sotuvchi × 3 hujjat = 150 ta signed URL request → admin panel sekin.

**Yechim:** Backend batch endpoint + Redis caching (50 daqiqa TTL) + browser TanStack Query (45 daqiqa stale time). 150 chaqiriq → 1 chaqiriq. Tafsilotlar: **§9.3**.

### 19.5 Boshqa diqqat qiladigan joylar (review davomida ochilgan)

Bular hal qilindi yoki keyingi review'da ko'riladi:

| Masala | Status | Ko'rinish |
|--------|--------|-----------|
| `flutter_phoenix.rebirth()` `main()`'ni qayta chaqirmaydi | **Hal qilindi** | §5.2'da scope manipulyatsiya rebirth'dan oldin |
| `EXCEPTION WHEN OTHERS` trigger'da auth'ni bloklaydi | **Hal qilindi** | §4.3'da fallback handling |
| Order stock race condition | **Belgilandi** | §11.2'da `SELECT ... FOR UPDATE` |
| Verification hujjatlari saqlash muddati | **Open question** | §11.3, yurist konsultatsiyasi kerak |
| Tariff downgrade UX (mahsulotlar archived bo'lganda) | **Belgilandi** | §7.2, lekin UI design kerak |

---

## 20. Keyingi qadamlar

1. **TZ ni 2-3 kun o'qib chiq**, savollar yoz, men bilan iteratsiya qil
2. **16-bo'limdagi ochiq savollarga javob ber** — bu TZ ni final qiladi
3. **Yuridik shaxs ochish** boshlash (paralel)
4. **Supabase project + GitHub repo'lar yaratish** (1 kun ish)
5. **Hafta 1-2 plan** — DB schema + backend skeleton + `handle_new_user` trigger, deliverable: "auth ishlaydi, profile avtomatik yaratiladi"
6. **Har hafta retro** — nima qilindi, nima qolgan, scope o'zgarishi (o'zing bilan)

---

**Hujjat oxiri**.

> Eslatma: bu TZ "starting point". Kod yozish boshlanguncha 2-3 marta iteratsiya qilinishi tabiiy. Real implementation paytida yangi savollar paydo bo'ladi — TZ'ga qaytib kiritib bor.

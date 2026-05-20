-- Brings the local migration tree in sync with what the live DB already has
-- (Supabase Studio had been used to evolve `products`, `product_variants` and
-- `product_images` outside version control), and introduces the
-- attribute_definitions / attribute_options pair that powers the
-- dynamic-attributes refactor.
--
-- Specs that used to be typed columns (width_cm, height_cm, depth_cm,
-- material) intentionally live in products.attributes JSONB from this point
-- on — they're category-specific and don't belong on the row. The legacy
-- typed columns stay in the schema (no-op for new products) and will be
-- dropped in a later cleanup migration once no rows reference them.

-- 1) Reconcile products with the columns the Dart repo writes today. Every
--    ADD is guarded with IF NOT EXISTS because this migration races against
--    the Studio-applied drift that already exists on the live DB.
alter table public.products
  add column if not exists seller_id             uuid references public.profiles(id),
  add column if not exists status                text not null default 'pending_review',
  add column if not exists production_time_days  text,
  add column if not exists has_delivery          boolean not null default false,
  add column if not exists delivery_price        numeric(12, 2) not null default 0,
  add column if not exists has_installation      boolean not null default false,
  add column if not exists warranty_months       int not null default 12;

create index if not exists products_seller_id_idx on public.products(seller_id);

-- 2) product_variants — schema only. RLS policies are owned by the
--    create_b1_seller_tables migration (`Sellers manage their variants` ALL,
--    `Public reads variants of active products` SELECT); duplicating them
--    here would trigger the multiple-permissive-policies linter.
create table if not exists public.product_variants (
  id              uuid primary key default gen_random_uuid(),
  product_id      uuid not null references public.products(id) on delete cascade,
  sku             text not null,
  color_name      text,
  price           numeric(12, 2) not null,
  discount_price  numeric(12, 2),
  created_at      timestamptz not null default now(),
  unique (product_id, sku)
);
create index if not exists product_variants_product_id_idx
  on public.product_variants(product_id);

alter table public.product_variants enable row level security;

-- 3) product_images — same arrangement as product_variants; RLS is owned by
--    `create_b1_seller_tables` and `tighten_product_images_select_policy`.
create table if not exists public.product_images (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references public.products(id) on delete cascade,
  image_url   text not null,
  is_main     boolean not null default false,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists product_images_product_id_idx
  on public.product_images(product_id);

alter table public.product_images enable row level security;

-- 4) attribute_definitions: schema for what's collectable per category /
--    subcategory. A definition is scoped to exactly one level — the form
--    merges category-wide and subcategory-specific rows at fetch time.
--    `key` is the canonical JSONB key (snake_case, locale-agnostic) and is
--    treated as immutable; renaming it orphans existing products.attributes
--    rows, so labels should be edited via label_uz / label_ru instead.
create table if not exists public.attribute_definitions (
  id              uuid primary key default gen_random_uuid(),
  category_id     uuid references public.categories(id) on delete cascade,
  subcategory_id  uuid references public.subcategories(id) on delete cascade,
  key             text not null,
  label_uz        text not null,
  label_ru        text not null,
  data_type       text not null check (data_type in ('select', 'multiselect', 'number', 'text', 'bool')),
  unit            text,
  is_required     boolean not null default false,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now(),
  constraint attribute_definitions_scope_xor
    check ((category_id is null) <> (subcategory_id is null)),
  constraint attribute_definitions_unique_category_key
    unique (category_id, key),
  constraint attribute_definitions_unique_subcategory_key
    unique (subcategory_id, key)
);
create index if not exists attribute_definitions_category_idx
  on public.attribute_definitions(category_id);
create index if not exists attribute_definitions_subcategory_idx
  on public.attribute_definitions(subcategory_id);

-- 5) attribute_options: lookup table for `select` / `multiselect` definitions.
--    `value` is the canonical token persisted in products.attributes; the
--    customer detail view resolves it to label_uz / label_ru at render time.
create table if not exists public.attribute_options (
  id              uuid primary key default gen_random_uuid(),
  attribute_id    uuid not null references public.attribute_definitions(id) on delete cascade,
  value           text not null,
  label_uz        text not null,
  label_ru        text not null,
  sort_order      int not null default 0,
  unique (attribute_id, value)
);
create index if not exists attribute_options_attribute_idx
  on public.attribute_options(attribute_id);

-- 6) RLS for the new attribute tables. Reads are public so the catalog can
--    resolve labels; writes are admin-only via the service_role key (no
--    policy = no permission for anon / authenticated).
alter table public.attribute_definitions enable row level security;
alter table public.attribute_options     enable row level security;

create policy "Public read attribute_definitions"
  on public.attribute_definitions for select using (true);
create policy "Public read attribute_options"
  on public.attribute_options for select using (true);

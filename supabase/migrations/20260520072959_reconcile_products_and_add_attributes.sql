-- Reconciles the products table with what the Dart layer has been writing in
-- production (drift between the original migration and Supabase Studio edits),
-- adds the auxiliary product_variants / product_images tables that the seller
-- repository assumes exist, and introduces the attribute_definitions /
-- attribute_options pair that powers the dynamic-attributes refactor.
--
-- Specs that used to be typed columns (width_cm, height_cm, depth_cm,
-- material) intentionally live in products.attributes JSONB from this point
-- on — they're category-specific and don't belong on the row.

-- 1) Reconcile products with the columns the Dart repo already writes.
alter table public.products
  add column if not exists seller_id             uuid references public.profiles(id),
  add column if not exists status                text not null default 'pending_review',
  add column if not exists production_time_days  text,
  add column if not exists has_delivery          boolean not null default false,
  add column if not exists delivery_price        numeric(12, 2) not null default 0,
  add column if not exists has_installation      boolean not null default false,
  add column if not exists warranty_months       int not null default 12;

create index if not exists products_seller_id_idx on public.products(seller_id);

-- 2) product_variants: one row per buyable SKU under a product. Today the
--    add-product flow always creates a single variant; the model is here so
--    multi-variant (color/size) can be added later without a second migration.
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
create policy "Public read product_variants"
  on public.product_variants for select using (true);
create policy "sellers can insert own product_variants"
  on public.product_variants for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_variants.product_id
        and s.seller_id = (select auth.uid())
    )
  );
create policy "sellers can update own product_variants"
  on public.product_variants for update
  to authenticated
  using (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_variants.product_id
        and s.seller_id = (select auth.uid())
    )
  );
create policy "sellers can delete own product_variants"
  on public.product_variants for delete
  to authenticated
  using (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_variants.product_id
        and s.seller_id = (select auth.uid())
    )
  );

-- 3) product_images: one row per image so the gallery preserves ordering and
--    knows which one is the primary card thumbnail.
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
create policy "Public read product_images"
  on public.product_images for select using (true);
create policy "sellers can insert own product_images"
  on public.product_images for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_images.product_id
        and s.seller_id = (select auth.uid())
    )
  );
create policy "sellers can update own product_images"
  on public.product_images for update
  to authenticated
  using (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_images.product_id
        and s.seller_id = (select auth.uid())
    )
  );
create policy "sellers can delete own product_images"
  on public.product_images for delete
  to authenticated
  using (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_images.product_id
        and s.seller_id = (select auth.uid())
    )
  );

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

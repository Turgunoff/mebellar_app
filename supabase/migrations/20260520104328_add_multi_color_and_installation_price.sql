-- Adds product-level multi-color support and an explicit installation price.
--
-- Until now color was a single value on `product_variants.color_name`. The
-- form now lets the seller pick multiple colors for a single product (full
-- per-color variant rows are out of scope; we store the canonical color
-- slugs as a `text[]` on the product itself). The variant row still carries
-- its `color_name` for back-compat with downstream consumers — populated
-- with the first selected color.
--
-- `installation_price` mirrors the `delivery_price` pattern: a typed numeric
-- column, zeroed when the corresponding boolean toggle is off so a stale
-- value never lingers behind a disabled flag.

alter table public.products
  add column if not exists colors             text[]        not null default '{}',
  add column if not exists installation_price numeric(12,2) not null default 0;

-- GIN index over colors lets the catalog efficiently filter by colour later
-- (e.g. `where colors && array['black','grey']`). No-op until the catalog
-- adds the filter; cheap to maintain on writes.
create index if not exists products_colors_gin_idx
  on public.products using gin (colors);

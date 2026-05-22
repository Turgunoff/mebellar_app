-- The catalogue surfaces `pending_review` products to customers (see the
-- permissive `products` SELECT policy), but `product_variants` was readable
-- by the public only for `active` products — so customers never saw any
-- variant-level pricing, including `discount_price`. Align variant
-- visibility with the products the app actually shows.
drop policy if exists "Public reads variants of active products"
  on public.product_variants;

create policy "Public reads variants of visible products"
  on public.product_variants
  for select
  using (
    exists (
      select 1
      from public.products p
      where p.id = product_variants.product_id
        and p.status in ('active', 'pending_review')
    )
  );

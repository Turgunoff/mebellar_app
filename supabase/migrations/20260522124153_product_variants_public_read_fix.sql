-- Correction to 20260522124018: the moderation status vocabulary is
-- `pending_review` / `approved` (never `active`), so gating variant reads on
-- `status in ('active','pending_review')` still hid every approved product's
-- pricing. The `products` table itself is effectively fully public, so a
-- variant should simply be readable whenever its parent product exists.
drop policy if exists "Public reads variants of visible products"
  on public.product_variants;

create policy "Public reads variants of visible products"
  on public.product_variants
  for select
  using (
    exists (
      select 1
      from public.products p
      where p.id = product_variants.product_id
    )
  );

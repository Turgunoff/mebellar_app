-- Sellers manage products they own — ownership is established by
-- products.shop_id → shops.seller_id. Reads remain public so any user
-- (anon included) can browse the catalogue.
--
-- The EXISTS clause uses (select auth.uid()) for plan-level caching, in
-- line with the rest of the schema (see 20260512000005).

create policy "sellers can insert own products"
  on public.products for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.shops
      where shops.id = products.shop_id
        and shops.seller_id = (select auth.uid())
    )
  );

create policy "sellers can update own products"
  on public.products for update
  to authenticated
  using (
    exists (
      select 1
      from public.shops
      where shops.id = products.shop_id
        and shops.seller_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.shops
      where shops.id = products.shop_id
        and shops.seller_id = (select auth.uid())
    )
  );

create policy "sellers can delete own products"
  on public.products for delete
  to authenticated
  using (
    exists (
      select 1
      from public.shops
      where shops.id = products.shop_id
        and shops.seller_id = (select auth.uid())
    )
  );

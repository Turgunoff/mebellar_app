-- Seller-side RLS for the order fulfillment flow.
--
-- Before this migration `orders` / `order_items` carried customer-only
-- policies (auth.uid() = user_id), so a seller could not read or update the
-- orders that contain their products. These policies add the transitive
-- ownership path:  order -> order_items -> products -> shop owner.
-- `public.is_shop_owner(uuid)` is an existing SECURITY DEFINER helper that
-- resolves shops.seller_id = auth.uid() without recursive RLS evaluation.

-- A seller may read an order if it contains at least one of their products.
drop policy if exists "orders seller read" on public.orders;
create policy "orders seller read"
  on public.orders
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.order_items oi
      join public.products p on p.id = oi.product_id
      where oi.order_id = orders.id
        and public.is_shop_owner(p.shop_id)
    )
  );

-- A seller may update an order (status transitions: confirm / preparing /
-- shipped / delivered / cancel) only for orders containing their products.
-- NOTE: this scopes WHICH rows, not WHICH columns — a status state-machine /
-- column guard belongs in a BEFORE UPDATE trigger (tracked as a follow-up).
drop policy if exists "orders seller update" on public.orders;
create policy "orders seller update"
  on public.orders
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.order_items oi
      join public.products p on p.id = oi.product_id
      where oi.order_id = orders.id
        and public.is_shop_owner(p.shop_id)
    )
  )
  with check (true);

-- order_items inherit seller visibility from product ownership.
drop policy if exists "order_items seller read" on public.order_items;
create policy "order_items seller read"
  on public.order_items
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.products p
      where p.id = order_items.product_id
        and public.is_shop_owner(p.shop_id)
    )
  );

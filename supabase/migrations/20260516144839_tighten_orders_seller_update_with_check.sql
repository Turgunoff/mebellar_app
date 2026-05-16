-- Replace the permissive `WITH CHECK (true)` on `orders seller update` with
-- the same transitive-ownership predicate used in USING. This clears the
-- `rls_policy_always_true` advisor finding: the post-update row must still be
-- an order that contains one of the seller's products. (order_items are not
-- mutated by an orders update, so this never rejects a legitimate status
-- transition — it only removes the "always true" escape hatch.)
alter policy "orders seller update"
  on public.orders
  with check (
    exists (
      select 1
      from public.order_items oi
      join public.products p on p.id = oi.product_id
      where oi.order_id = orders.id
        and public.is_shop_owner(p.shop_id)
    )
  );

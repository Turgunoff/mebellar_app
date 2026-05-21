-- Allows a seller to read the name + phone of any customer who has placed
-- an order containing one of the seller's products. The existing
-- "profiles_select_own" policy covers self-reads; this adds the lateral
-- buyer-read path required by SupabaseSellerOrderRepository._fetchBuyerContact.
create policy "seller_read_buyer_profile"
  on public.profiles
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.orders o
      join public.order_items oi on oi.order_id = o.id
      join public.products p on p.id = oi.product_id
      where o.user_id = profiles.id
        and public.is_shop_owner(p.shop_id)
    )
  );

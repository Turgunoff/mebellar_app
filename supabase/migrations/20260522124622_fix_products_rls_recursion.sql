-- Break the infinite recursion (Postgres 42P17) introduced by
-- 20260522123722_products_public_read_approved_only: the products SELECT
-- policy's order-history clause queried order_items, and order_items'
-- "order_items seller read" policy queries products back, so Postgres
-- re-enters policy evaluation indefinitely.
--
-- Same fix as 20260520121500_fix_orders_rls_recursion: move the cross-table
-- EXISTS into a SECURITY DEFINER helper that bypasses RLS, so the policy body
-- is a flat boolean and never re-enters another table's policy chain.

create or replace function public.user_has_ordered_product(p_product_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.product_id = p_product_id
      and o.user_id = auth.uid()
  );
$$;

-- Harmless for anon: auth.uid() is null so it always returns false and leaks
-- nothing, which lets the catalog's role-agnostic policy call it for any
-- caller. For an authenticated caller it only ever reveals their own history.
revoke all on function public.user_has_ordered_product(uuid) from public;
grant execute on function public.user_has_ordered_product(uuid)
  to anon, authenticated;

drop policy if exists "Public read products" on public.products;
create policy "Public read products"
  on public.products for select
  using (
    status = 'approved'
    or seller_id = (select auth.uid())
    or public.user_has_ordered_product(id)
  );

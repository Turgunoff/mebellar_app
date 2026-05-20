-- Fix "infinite recursion detected in policy for relation order_items"
-- (Postgres 42P17) — produced any time both buyer and seller policies are
-- evaluated on the same query against orders / order_items.
--
-- Root cause: the previous customer policies on `order_items` queried
-- `orders` inside their USING / WITH CHECK clauses, and the seller
-- policies on `orders` queried `order_items`. When Postgres evaluates
-- policy A whose body selects from table B (whose own policy A' selects
-- back from A), it recurses indefinitely — there is no fixed-point
-- shortcut in the RLS planner.
--
-- Fix: replace the cross-table EXISTS subqueries with SECURITY DEFINER
-- helpers (`user_owns_order`, `seller_can_access_order`) that bypass RLS
-- internally. The policy bodies become flat boolean expressions, so
-- Postgres never re-enters policy evaluation on the related table.

-- ─── Helpers ─────────────────────────────────────────────────────────────

create or replace function public.user_owns_order(target_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.orders
    where id = target_order_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.seller_can_access_order(target_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.order_items oi
    join public.products p on p.id = oi.product_id
    join public.shops    s on s.id = p.shop_id
    where oi.order_id = target_order_id
      and s.seller_id = auth.uid()
  );
$$;

revoke all on function public.user_owns_order(uuid) from public;
grant execute on function public.user_owns_order(uuid) to authenticated;

revoke all on function public.seller_can_access_order(uuid) from public;
grant execute on function public.seller_can_access_order(uuid) to authenticated;

-- ─── orders ──────────────────────────────────────────────────────────────

-- Buyer SELECT — unchanged in intent, re-declared idempotently so a fresh
-- `supabase db reset` plus this migration leaves the same final state as
-- applying this migration on top of the live database.
drop policy if exists "authenticated users can select own orders"
  on public.orders;
create policy "authenticated users can select own orders"
  on public.orders for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "authenticated users can insert own orders"
  on public.orders;
create policy "authenticated users can insert own orders"
  on public.orders for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "users can cancel own orders" on public.orders;
create policy "users can cancel own orders"
  on public.orders for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Seller SELECT / UPDATE — rewritten to use the SECURITY DEFINER helper
-- so Postgres never re-enters order_items' policy chain.
drop policy if exists "orders seller read" on public.orders;
create policy "orders seller read"
  on public.orders for select
  to authenticated
  using (public.seller_can_access_order(id));

drop policy if exists "orders seller update" on public.orders;
create policy "orders seller update"
  on public.orders for update
  to authenticated
  using (public.seller_can_access_order(id))
  with check (public.seller_can_access_order(id));

-- ─── order_items ─────────────────────────────────────────────────────────

-- Buyer SELECT / INSERT — rewritten via user_owns_order(...) so the
-- cross-table reference no longer re-enters orders' policy chain.
drop policy if exists "authenticated users can select items for own orders"
  on public.order_items;
create policy "authenticated users can select items for own orders"
  on public.order_items for select
  to authenticated
  using (public.user_owns_order(order_id));

drop policy if exists "authenticated users can insert items for own orders"
  on public.order_items;
create policy "authenticated users can insert items for own orders"
  on public.order_items for insert
  to authenticated
  with check (public.user_owns_order(order_id));

-- Seller SELECT — products is queried, but products' policies don't loop
-- back to order_items, so this one is safe as-is. We re-declare it for
-- idempotency: a `supabase db reset` plus the buyer-only migration plus
-- this one must produce the live policy list.
drop policy if exists "order_items seller read" on public.order_items;
create policy "order_items seller read"
  on public.order_items for select
  to authenticated
  using (
    exists (
      select 1
      from public.products p
      where p.id = order_items.product_id
        and public.is_shop_owner(p.shop_id)
    )
  );

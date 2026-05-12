-- Wrap auth.uid() in (select auth.uid()) so the planner caches the result
-- once per query instead of re-evaluating it per row. Behaviour identical;
-- only the plan changes.
-- See: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

-- ── profiles ──
alter policy "profiles_select_own" on public.profiles
  using ((select auth.uid()) = id);
alter policy "profiles_update_own" on public.profiles
  using ((select auth.uid()) = id);

-- ── sellers ──
alter policy "sellers_select_own" on public.sellers
  using ((select auth.uid()) = id);
alter policy "sellers_insert_own" on public.sellers
  with check ((select auth.uid()) = id);
alter policy "sellers_update_own" on public.sellers
  using ((select auth.uid()) = id);

-- ── shops ──
alter policy "shops_insert_own" on public.shops
  with check ((select auth.uid()) = seller_id);
alter policy "shops_update_own" on public.shops
  using ((select auth.uid()) = seller_id);

-- ── favorites ──
alter policy "Users can view own favorites" on public.favorites
  using ((select auth.uid()) = user_id);
alter policy "Users can insert own favorites" on public.favorites
  with check ((select auth.uid()) = user_id);
alter policy "Users can delete own favorites" on public.favorites
  using ((select auth.uid()) = user_id);

-- ── orders ──
alter policy "authenticated users can select own orders" on public.orders
  using ((select auth.uid()) = user_id);
alter policy "authenticated users can insert own orders" on public.orders
  with check ((select auth.uid()) = user_id);
alter policy "users can cancel own orders" on public.orders
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ── order_items (auth.uid() is inside an EXISTS subquery) ──
alter policy "authenticated users can select items for own orders"
  on public.order_items
  using (exists (
    select 1 from public.orders
    where orders.id = order_items.order_id
      and orders.user_id = (select auth.uid())
  ));
alter policy "authenticated users can insert items for own orders"
  on public.order_items
  with check (exists (
    select 1 from public.orders
    where orders.id = order_items.order_id
      and orders.user_id = (select auth.uid())
  ));

-- ── cart_items ──
alter policy "cart: users select own rows" on public.cart_items
  using ((select auth.uid()) = user_id);
alter policy "cart: users insert own rows" on public.cart_items
  with check ((select auth.uid()) = user_id);
alter policy "cart: users update own rows" on public.cart_items
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "cart: users delete own rows" on public.cart_items
  using ((select auth.uid()) = user_id);

-- ── device_tokens ──
alter policy "Users can view own tokens" on public.device_tokens
  using ((select auth.uid()) = user_id);
alter policy "Users can insert own tokens" on public.device_tokens
  with check ((select auth.uid()) = user_id);
alter policy "Users can update own tokens" on public.device_tokens
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "Users can delete own tokens" on public.device_tokens
  using ((select auth.uid()) = user_id);

-- ── notifications ──
alter policy "Users can view own notifications" on public.notifications
  using ((select auth.uid()) = user_id);
alter policy "Users can update own notifications" on public.notifications
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "Users can delete own notifications" on public.notifications
  using ((select auth.uid()) = user_id);

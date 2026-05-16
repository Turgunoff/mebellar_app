-- Orders & order items — structural snapshot.
--
-- This file reconciles migration drift: the `orders` / `order_items` tables
-- existed in the live database but their migration file was missing from the
-- repo. The DDL below is idempotent (`if not exists` / `drop policy if
-- exists`) so it is safe both as the historical migration and on a fresh
-- `supabase db reset`. It reflects the live schema verified on 2026-05-16.

create extension if not exists "uuid-ossp";

-- ─── orders ────────────────────────────────────────────────────────────────
create table if not exists public.orders (
  id                  uuid primary key default uuid_generate_v4(),
  user_id             uuid not null references auth.users (id) on delete cascade,
  total_amount        numeric not null,
  status              text not null default 'pending',
  delivery_address    text,
  cancellation_reason text,
  created_at          timestamptz not null default now()
);

-- ─── order_items ───────────────────────────────────────────────────────────
create table if not exists public.order_items (
  id         uuid primary key default uuid_generate_v4(),
  order_id   uuid not null references public.orders (id) on delete cascade,
  product_id uuid not null references public.products (id),
  quantity   integer not null,
  price      numeric not null
);

create index if not exists order_items_order_id_idx
  on public.order_items (order_id);
create index if not exists order_items_product_id_idx
  on public.order_items (product_id);
create index if not exists orders_user_id_idx
  on public.orders (user_id);

alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- ─── Customer RLS — an order belongs to the buyer who placed it ────────────
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
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "authenticated users can select items for own orders"
  on public.order_items;
create policy "authenticated users can select items for own orders"
  on public.order_items for select
  to authenticated
  using (
    exists (
      select 1 from public.orders
      where orders.id = order_items.order_id
        and orders.user_id = (select auth.uid())
    )
  );

drop policy if exists "authenticated users can insert items for own orders"
  on public.order_items;
create policy "authenticated users can insert items for own orders"
  on public.order_items for insert
  to authenticated
  with check (
    exists (
      select 1 from public.orders
      where orders.id = order_items.order_id
        and orders.user_id = (select auth.uid())
    )
  );

-- Realtime — the seller order repository subscribes to `orders` inserts.
do $$
begin
  alter publication supabase_realtime add table public.orders;
exception
  when duplicate_object then null;
end $$;

-- Cart items per authenticated user. Mirrors the storage shape used by the
-- HybridCartRepository in the Flutter client: each row is one
-- (user, product) pair with a snapshot of the product so the cart screen
-- can render without a join back to public.products. Quantity is summed
-- when the same product is added twice (handled in the upsert path).

create table if not exists public.cart_items (
  id               uuid        primary key default gen_random_uuid(),
  user_id          uuid        not null references auth.users(id) on delete cascade,
  product_id       text        not null,
  quantity         integer     not null default 1 check (quantity > 0),
  product_snapshot jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (user_id, product_id)
);

alter table public.cart_items enable row level security;

-- Users may only see, insert, update, and delete their own cart rows.
create policy "Users can view own cart items"
  on public.cart_items for select
  using (auth.uid() = user_id);

create policy "Users can insert own cart items"
  on public.cart_items for insert
  with check (auth.uid() = user_id);

create policy "Users can update own cart items"
  on public.cart_items for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own cart items"
  on public.cart_items for delete
  using (auth.uid() = user_id);

create index if not exists cart_items_user_id_idx on public.cart_items(user_id);

-- Keep updated_at fresh on every row mutation so clients can use it as a
-- sync watermark if we add real-time later.
create or replace function public.set_cart_items_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists cart_items_set_updated_at on public.cart_items;
create trigger cart_items_set_updated_at
  before update on public.cart_items
  for each row execute procedure public.set_cart_items_updated_at();

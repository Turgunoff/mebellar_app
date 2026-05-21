-- Product reviews left by customers on delivered orders.
--
-- Scope (MVP):
--   * One row per (order_item) — a customer reviews a product they bought.
--     Anchoring to the order item (not just the product) lets us enforce the
--     "must have purchased" rule cheaply and surfaces the same customer
--     leaving reviews on different products of one order independently.
--   * Seller writes a single reply per review; further back-and-forth lives
--     in chat, not in reviews.
--   * `rating` is 1..5 — enforced at the column level so a buggy client
--     can't slip a 6-star outlier into the aggregate.

create table if not exists public.reviews (
  id              uuid primary key default gen_random_uuid(),
  order_item_id   uuid not null unique
                    references public.order_items (id) on delete cascade,
  order_id        uuid not null
                    references public.orders (id) on delete cascade,
  product_id      uuid not null
                    references public.products (id) on delete cascade,
  -- Denormalised so RLS + seller listing don't need a 3-hop join to find
  -- the owning shop. Maintained by the trigger below.
  shop_id         uuid not null
                    references public.shops (id) on delete cascade,
  customer_id     uuid not null
                    references auth.users (id) on delete cascade,
  rating          integer not null check (rating between 1 and 5),
  comment         text,
  created_at      timestamptz not null default now(),
  seller_reply    text,
  seller_replied_at timestamptz
);

-- Indexes for the seller "my reviews" list and the product page aggregate.
create index if not exists reviews_shop_id_created_at_idx
  on public.reviews (shop_id, created_at desc);
create index if not exists reviews_product_id_created_at_idx
  on public.reviews (product_id, created_at desc);
create index if not exists reviews_customer_id_idx
  on public.reviews (customer_id);

-- Trigger: every insert backfills `shop_id` from products + verifies that
-- order_items.order_id == orders.id and order.status == 'delivered'. This
-- keeps the RLS policy below short (no need to re-check the chain there).
create or replace function public._reviews_resolve_shop_and_verify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_id  uuid;
  v_status   text;
  v_order_id uuid;
  v_buyer    uuid;
begin
  select p.shop_id into v_shop_id
    from public.products p
   where p.id = new.product_id;
  if v_shop_id is null then
    raise exception 'reviews: product % has no shop', new.product_id;
  end if;
  new.shop_id := v_shop_id;

  select oi.order_id into v_order_id
    from public.order_items oi
   where oi.id = new.order_item_id;
  if v_order_id is null then
    raise exception 'reviews: order_item % not found', new.order_item_id;
  end if;
  if v_order_id <> new.order_id then
    raise exception 'reviews: order_item belongs to a different order';
  end if;

  select o.status, o.user_id into v_status, v_buyer
    from public.orders o
   where o.id = new.order_id;
  if v_status is distinct from 'delivered' then
    raise exception 'reviews: order is not delivered (status=%)', v_status;
  end if;
  if v_buyer is distinct from new.customer_id then
    raise exception 'reviews: customer did not place this order';
  end if;

  return new;
end;
$$;

-- `_reviews_resolve_shop_and_verify` is a trigger-only function. Revoke
-- EXECUTE from every callable role so the database advisor doesn't flag it
-- as a SECURITY DEFINER function exposed via `/rest/v1/rpc/...` — triggers
-- still fire because they're not gated by EXECUTE.
revoke execute on function public._reviews_resolve_shop_and_verify()
  from public, anon, authenticated;

drop trigger if exists reviews_before_insert on public.reviews;
create trigger reviews_before_insert
  before insert on public.reviews
  for each row execute function public._reviews_resolve_shop_and_verify();

-- RLS ----------------------------------------------------------------------

alter table public.reviews enable row level security;

-- Customers see their own reviews on the orders detail screen + the
-- product page renders every review (public read of the aggregated list
-- and per-row text).
create policy "reviews public read"
  on public.reviews
  for select
  using (true);

-- A customer inserts a review for an order they own. The trigger above
-- enforces order ownership + delivery status; this policy adds the
-- auth.uid() guard so an attacker can't write reviews tagged as another
-- user.
create policy "reviews customer insert"
  on public.reviews
  for insert
  with check (customer_id = auth.uid());

-- A customer may edit their own review (typo fixes) but cannot touch
-- `seller_reply`/`seller_replied_at`.
create policy "reviews customer update"
  on public.reviews
  for update
  using (customer_id = auth.uid())
  with check (
    customer_id = auth.uid()
    and seller_reply is not distinct from (
      select r.seller_reply from public.reviews r where r.id = reviews.id
    )
    and seller_replied_at is not distinct from (
      select r.seller_replied_at from public.reviews r where r.id = reviews.id
    )
  );

-- A customer may delete their own review.
create policy "reviews customer delete"
  on public.reviews
  for delete
  using (customer_id = auth.uid());

-- A seller may update ONLY the reply fields on reviews of their products.
-- The `with check` keeps the immutable fields (rating, comment, ids)
-- pinned to their current values so a malicious seller can't rewrite a
-- bad review into a 5-star one.
create policy "reviews seller reply"
  on public.reviews
  for update
  using (public.is_shop_owner(shop_id))
  with check (
    public.is_shop_owner(shop_id)
    and rating       = (select r.rating       from public.reviews r where r.id = reviews.id)
    and comment      is not distinct from (select r.comment      from public.reviews r where r.id = reviews.id)
    and order_item_id = (select r.order_item_id from public.reviews r where r.id = reviews.id)
    and order_id     = (select r.order_id     from public.reviews r where r.id = reviews.id)
    and product_id   = (select r.product_id   from public.reviews r where r.id = reviews.id)
    and customer_id  = (select r.customer_id  from public.reviews r where r.id = reviews.id)
  );

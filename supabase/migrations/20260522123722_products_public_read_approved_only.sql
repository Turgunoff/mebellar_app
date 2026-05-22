-- Hide non-approved products from the public catalogue.
--
-- Until now `products` had a wide-open SELECT policy (`using (true)`), so
-- products still in `draft` / `pending_review` / `rejected` / `archived`
-- leaked into customer browsing, search, the home rail and the "similar
-- products" carousel. Only `approved` rows belong in the customer catalogue.
--
-- The policy keeps two escape hatches so existing flows don't break:
--   1. seller_id = auth.uid()  — a seller always sees their own products
--      (any status) in the seller dashboard.
--   2. the product is referenced by an order_item in an order the caller
--      owns — so a buyer's order history still resolves the product name and
--      image even after the seller later archives it. `order_items` keeps no
--      name/image snapshot; the order screen relies on the embedded join.
--
-- This also drops "Public can view active products" — a Studio-applied drift
-- policy (`status = 'active'`) with no migration file. It never matched a row
-- (products use draft/pending_review/approved/rejected/archived) but as a
-- second permissive SELECT policy it would OR back in alongside the new one.

drop policy if exists "Public read products" on public.products;
drop policy if exists "Public can view active products" on public.products;

create policy "Public read products"
  on public.products for select
  using (
    status = 'approved'
    or seller_id = (select auth.uid())
    or exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.product_id = products.id
        and o.user_id = (select auth.uid())
    )
  );

-- Keep `get_similar_products` strictly approved-only. The function is
-- SECURITY INVOKER, so anon callers already only see approved rows via RLS,
-- but an authenticated buyer would otherwise have their own previously
-- ordered (now non-approved) products surface in the carousel. Filtering
-- here also keeps the server-side LIMIT counting approved rows only.
create or replace function public.get_similar_products(
  p_product_id uuid,
  p_limit integer default 10
)
returns setof public.products
language sql
stable
security invoker
set search_path = public
as $$
  with ref as (
    select category_id, subcategory_id, price, material
    from public.products
    where id = p_product_id
  )
  select p.*
  from public.products p
  cross join ref
  where p.id <> p_product_id
    and p.category_id = ref.category_id
    and p.status = 'approved'
  order by
    -- 1. same subcategory first — the strongest similarity signal
    (p.subcategory_id is not distinct from ref.subcategory_id) desc,
    -- 2. in-stock items ahead of sold-out ones
    (p.stock > 0) desc,
    -- 3. same material gets a nudge
    (p.material is not null and p.material = ref.material) desc,
    -- 4. closest price wins
    abs(p.price - ref.price) asc,
    -- 5. stable tiebreaker — newest first
    p.created_at desc
  limit greatest(p_limit, 0);
$$;

grant execute on function public.get_similar_products(uuid, integer)
  to anon, authenticated;

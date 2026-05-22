-- Rule-based "similar products" recommendation for the product detail page.
-- No ML/AI involved: it ranks catalogue neighbours by shared subcategory,
-- availability, material and price proximity — entirely in SQL.
--
-- Returns `setof products` so PostgREST can embed `shops(name)` on the
-- result, exactly like the plain table queries the customer app uses.
-- SECURITY INVOKER: the caller's RLS on `products` applies unchanged.
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

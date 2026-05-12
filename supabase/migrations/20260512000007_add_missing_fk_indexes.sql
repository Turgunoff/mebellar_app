-- PostgreSQL doesn't auto-index foreign keys. Without a covering index the
-- referenced table can't enforce the FK on UPDATE/DELETE without a
-- sequential scan, and JOINs filtering on the FK column also pay the
-- scan cost. Linter `unindexed_foreign_keys` flagged these four.

create index if not exists favorites_product_id_idx
  on public.favorites(product_id);

create index if not exists order_items_order_id_idx
  on public.order_items(order_id);

create index if not exists orders_user_id_idx
  on public.orders(user_id);

create index if not exists products_shop_id_idx
  on public.products(shop_id);

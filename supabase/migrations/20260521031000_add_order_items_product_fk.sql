-- Adds the missing FK from order_items.product_id → products.id.
--
-- Root cause: order_items was originally created via Supabase Studio before
-- its migration file existed. When the reconcile migration was written
-- (20260511124042), CREATE TABLE IF NOT EXISTS was a no-op on the live DB,
-- so the `references public.products(id)` clause was never executed.
-- PostgREST requires the FK to resolve the products!inner(...) embed used
-- by SupabaseSellerOrderRepository._fetchItemsByOrderId.
alter table public.order_items
  add constraint order_items_product_id_fkey
  foreign key (product_id) references public.products (id);

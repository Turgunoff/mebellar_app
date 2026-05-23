-- The existing shop_assets_{insert,update,delete}_own storage policies
-- accidentally called `storage.foldername(shops.name)` — that's the
-- *shop's* name column (e.g. "Zumar mebel"), not the storage object
-- path. The policy therefore never matched anything legitimate, so
-- every upload returned RLS 403 ("new row violates row-level security
-- policy"), preventing sellers from setting a shop logo or cover.
--
-- The correct expression is `storage.foldername(objects.name)` — the
-- file's storage path, whose first segment is the shop id (path
-- convention: `<shop_id>/<asset-kind>-<timestamp>.<ext>`).

drop policy if exists shop_assets_insert_own on storage.objects;
drop policy if exists shop_assets_update_own on storage.objects;
drop policy if exists shop_assets_delete_own on storage.objects;

create policy shop_assets_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'shop-assets'
    and exists (
      select 1 from public.shops
      where shops.id::text = (storage.foldername(objects.name))[1]
        and shops.seller_id = (select auth.uid())
    )
  );

create policy shop_assets_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'shop-assets'
    and exists (
      select 1 from public.shops
      where shops.id::text = (storage.foldername(objects.name))[1]
        and shops.seller_id = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'shop-assets'
    and exists (
      select 1 from public.shops
      where shops.id::text = (storage.foldername(objects.name))[1]
        and shops.seller_id = (select auth.uid())
    )
  );

create policy shop_assets_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'shop-assets'
    and exists (
      select 1 from public.shops
      where shops.id::text = (storage.foldername(objects.name))[1]
        and shops.seller_id = (select auth.uid())
    )
  );

notify pgrst, 'reload schema';

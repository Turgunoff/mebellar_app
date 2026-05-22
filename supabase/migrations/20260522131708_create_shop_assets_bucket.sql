-- Storage bucket for shop logo / cover images.
--
-- The seller "Do'kon sozlamalari" screen uploads to `shop-assets` via
-- SupabaseShopSettingsRepository.uploadAsset(), but the bucket was never
-- created — every logo/cover pick failed with "Bucket not found". Public so
-- the customer-facing surfaces (seller banners, shop header) can render the
-- images straight from their public URLs.

insert into storage.buckets (id, name, public)
values ('shop-assets', 'shop-assets', true)
on conflict (id) do nothing;

-- Write access is scoped to the shop owner. The repository stores objects
-- under `<shop_id>/<kind>-<ts>.<ext>`, so the first path segment is the shop
-- id; a seller may write only inside the folder of a shop they own.
-- Reads need no policy: a public bucket serves its objects openly.

drop policy if exists "shop_assets_insert_own" on storage.objects;
create policy "shop_assets_insert_own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'shop-assets'
    and exists (
      select 1 from public.shops
      where shops.id::text = (storage.foldername(name))[1]
        and shops.seller_id = (select auth.uid())
    )
  );

drop policy if exists "shop_assets_update_own" on storage.objects;
create policy "shop_assets_update_own"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'shop-assets'
    and exists (
      select 1 from public.shops
      where shops.id::text = (storage.foldername(name))[1]
        and shops.seller_id = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'shop-assets'
    and exists (
      select 1 from public.shops
      where shops.id::text = (storage.foldername(name))[1]
        and shops.seller_id = (select auth.uid())
    )
  );

drop policy if exists "shop_assets_delete_own" on storage.objects;
create policy "shop_assets_delete_own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'shop-assets'
    and exists (
      select 1 from public.shops
      where shops.id::text = (storage.foldername(name))[1]
        and shops.seller_id = (select auth.uid())
    )
  );

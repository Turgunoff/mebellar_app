-- ROOT CAUSE of "new row violates row-level security policy" on
-- shop-assets uploads: `public.shops` has a `name` column (the shop's
-- display name like "Zumar mebel"). Inside the policy's
-- `EXISTS (SELECT 1 FROM shops s WHERE ...)` body, the unqualified
-- `name` rebinds to `s.name`, so the policy effectively checked
--   `s.id::text = (storage.foldername('Zumar mebel'))[1]`
-- which never matches any UUID — every upload was denied.
--
-- Even the seemingly-explicit `storage.objects.name` gets compressed
-- by Postgres at parse time to `objects.name`, which CAN still bind
-- to a same-named column inside the inner query (PG's name resolution
-- prefers the closer scope when an unqualified name is in play).
--
-- Bullet-proof fix: lift the path-segment extraction OUT of the inner
-- subquery. The IN-subquery only returns shop ids the caller owns;
-- the outer expression on storage.objects refers to its own `name`
-- without any inner-scope shadow. The chat-attachments policy worked
-- accidentally because `chats` has no `name` column to collide with.

drop policy if exists shop_assets_insert_own on storage.objects;
drop policy if exists shop_assets_update_own on storage.objects;
drop policy if exists shop_assets_delete_own on storage.objects;
drop policy if exists shop_assets_select_own on storage.objects;

create policy shop_assets_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'shop-assets'
    and (storage.foldername(storage.objects.name))[1] in (
      select s.id::text
      from public.shops s
      where s.seller_id = (select auth.uid())
    )
  );

create policy shop_assets_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'shop-assets'
    and (storage.foldername(storage.objects.name))[1] in (
      select s.id::text
      from public.shops s
      where s.seller_id = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'shop-assets'
    and (storage.foldername(storage.objects.name))[1] in (
      select s.id::text
      from public.shops s
      where s.seller_id = (select auth.uid())
    )
  );

create policy shop_assets_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'shop-assets'
    and (storage.foldername(storage.objects.name))[1] in (
      select s.id::text
      from public.shops s
      where s.seller_id = (select auth.uid())
    )
  );

create policy shop_assets_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'shop-assets'
    and (storage.foldername(storage.objects.name))[1] in (
      select s.id::text
      from public.shops s
      where s.seller_id = (select auth.uid())
    )
  );

notify pgrst, 'reload schema';

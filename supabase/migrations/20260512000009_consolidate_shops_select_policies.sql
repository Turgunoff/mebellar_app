-- The previous setup had two permissive SELECT policies on `shops`:
--   - shops_read_active : anyone (anon + authenticated) sees `is_active=true`
--   - shops_select_own  : sellers see all of their own shops, even inactive
-- Both are evaluated for every SELECT, doubling the planner work. Merge
-- them into one policy with an OR. Behaviour is identical:
--   * anon → only the seller_id branch returns false → only active shops
--   * seller → either branch can match → active shops PLUS their own

drop policy if exists "shops_read_active" on public.shops;
drop policy if exists "shops_select_own" on public.shops;

create policy "shops_select_active_or_own"
  on public.shops for select
  using (
    is_active = true
    or seller_id = (select auth.uid())
  );

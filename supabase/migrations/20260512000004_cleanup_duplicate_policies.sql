-- Drop catch-all "ALL" policies that overlapped with the per-action ones.
-- The duplication was tripping the Supabase linter's
-- multiple_permissive_policies rule because every read / write evaluated
-- both policies. Per-action policies are kept.

drop policy if exists "O'z profilini ko'rish" on public.profiles;
drop policy if exists "shops_manage_own" on public.shops;

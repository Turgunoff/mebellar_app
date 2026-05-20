-- Tighten exposure of the order RLS helpers introduced in
-- 20260520121500_fix_orders_rls_recursion.sql.
--
-- The previous migration only revoked from `public` (the role), but the
-- project's default grants attach `anon` and `authenticated` directly —
-- so `anon` retained EXECUTE on `user_owns_order` /
-- `seller_can_access_order` and they were callable via
-- `/rest/v1/rpc/...` without authentication. SECURITY DEFINER functions
-- exposed to anon would let an unauthenticated probe enumerate order
-- membership; revoke that grant explicitly so only authenticated
-- callers (and the policy planner) reach them.

revoke execute on function public.user_owns_order(uuid)         from anon;
revoke execute on function public.seller_can_access_order(uuid) from anon;

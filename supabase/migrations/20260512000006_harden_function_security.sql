-- handle_new_user is a TRIGGER on auth.users — there is no reason for it
-- to be reachable via PostgREST. Strip EXECUTE so the RPC route is
-- unreachable; the trigger keeps firing on the auth.users insert path.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Pin search_path on the trigger functions to silence the linter and to
-- prevent search_path-based privilege escalation on any future SECURITY
-- DEFINER variant.
alter function public.set_updated_at() set search_path = pg_catalog, public;
alter function public.set_device_tokens_updated_at() set search_path = pg_catalog, public;

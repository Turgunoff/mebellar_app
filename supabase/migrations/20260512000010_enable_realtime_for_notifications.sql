-- Realtime works by streaming logical-replication events from tables that
-- belong to the `supabase_realtime` publication. Without this ALTER, the
-- client's `onPostgresChanges` subscription never fires no matter how many
-- rows are inserted. Add the notifications table so the inbox cubit can
-- live-update from server-side INSERTs (Edge Function fan-out, admin
-- inserts, future order/review triggers — all paths converge here).

alter publication supabase_realtime add table public.notifications;

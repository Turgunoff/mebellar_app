-- Add a JSONB `data` column to notifications so the row can carry routing
-- info (e.g. {"route": "/orders/abc-123", "kind": "order_delivered"}) all
-- the way through the Database Webhook → Edge Function → FCM data payload
-- → Flutter onMessageOpenedApp handler. The handler reads `route` to deep-
-- link the user into the right screen when they tap the push.
--
-- Default to '{}' so existing rows (and inserts that omit the column)
-- still satisfy a NOT NULL constraint.

alter table public.notifications
  add column if not exists data jsonb not null default '{}'::jsonb;

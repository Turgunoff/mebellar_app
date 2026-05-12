-- Unify all alert kinds in a single table, distinguished by `type`.
-- `reference_id` carries the foreign id (order_id, product_id, ...) the
-- notification refers to, used for deep-linking from the inbox tap.
--
-- Conventional `type` values:
--   'order'  — order lifecycle (placed / confirmed / shipped / delivered)
--   'news'   — product / company news
--   'promo'  — discount / campaign
--   'review' — review-related (response received, reminder to leave one)
--   'general'— catch-all default for legacy rows
--
-- We deliberately do NOT add a CHECK constraint on `type` so introducing a
-- new alert kind doesn't require a migration — readers should treat any
-- unknown value as 'general' for icon / colour resolution.

alter table public.notifications
  add column if not exists type text not null default 'general',
  add column if not exists reference_id uuid;

create index if not exists notifications_user_type_idx
  on public.notifications(user_id, type);

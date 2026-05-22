-- Align the products.status CHECK constraint with the app's
-- `SellerProductStatus` enum: draft / pending_review / approved / rejected /
-- archived.
--
-- The live constraint was Studio drift — it used `active` for the published
-- state and omitted `draft`, while the Flutter code (the version-controlled
-- source of truth, incl. its i18n keys) has always used `approved`. That
-- mismatch meant a moderator-published product could never read back with the
-- right status. No rows use `active` (all are `pending_review`), so this is a
-- constraint swap with no data migration.

alter table public.products
  drop constraint if exists products_status_check;

alter table public.products
  add constraint products_status_check
  check (status in ('draft', 'pending_review', 'approved', 'rejected', 'archived'));

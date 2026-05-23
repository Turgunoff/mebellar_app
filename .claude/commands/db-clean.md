---
description: Wipe all user-generated data from Supabase, leaving reference tables intact.
---

⚠️ **DESTRUCTIVE** — wipes every user, shop, product, order, chat,
notification, etc. Reference data (categories, subcategories,
attribute definitions, subscription plans, banners, news, app_settings)
is preserved.

Before running, MUST:

1. Confirm the active Supabase project — run the MCP
   `mcp__supabase__list_projects` and verify the active one is the
   intended target (`Mebellar` / `oifdvxsfrciatzgivtgs`). Abort if
   it's a different project (e.g. Funduz).
2. Tell me current row counts in the user-data tables via
   `mcp__supabase__list_tables`. Stop and ask me to confirm with
   "ha, davom et" before deleting anything.

Once confirmed, run this in dependency-safe order via
`mcp__supabase__execute_sql`:

```sql
begin;

delete from public.chat_messages;
delete from public.chats;
delete from public.reviews;
delete from public.cart_items;
delete from public.favorites;
delete from public.notifications;
delete from public.device_tokens;
delete from public.order_items;
delete from public.orders;
delete from public.subscription_receipts;
delete from public.subscription_history;
delete from public.subscriptions;
delete from public.verification_documents;
delete from public.seller_verifications;
delete from public.product_images;
delete from public.product_variants;
delete from public.products;
delete from public.shop_services;
delete from public.shops;
delete from public.sellers;
delete from public.profiles;

commit;

delete from auth.users;
```

Then clean storage. The `protect_delete` trigger blocks direct
DELETEs — bypass via:

```sql
begin;
set local storage.allow_delete_query = 'true';
delete from storage.objects
where bucket_id in (
  'product-images', 'shop-assets', 'chat-attachments',
  'payment-receipts', 'verification-docs', 'seller-documents'
);
commit;
```

Report final counts. The actual binaries in object storage will be
orphans — leave them for now (no app reference, no harm).

If anything FK-fails, surface the exact error and STOP. Do not try to
DROP TABLE or CASCADE around the failure — the script's order is what
the schema expects, a failure means new FK relationships were added
and the script needs updating.

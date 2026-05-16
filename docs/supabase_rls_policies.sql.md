# Supabase RLS Policies — ROADMAP B.1 Seller Tables

Raw Postgres / SQL to **backfill Row Level Security** for the seller-side
tables the B.1 repositories read and write. Run these in the Supabase SQL
editor (or as a migration) **before** flipping `SELLER_FULFILLMENT_ENABLED`
to `true` in `env/prod.json`.

> **Audit before go-live:** after applying, run the Supabase advisors
> (`get_advisors` → `security`) and confirm there are **no** "RLS disabled"
> or "policy allows public write" findings.

## Conventions

- `auth.uid()` is the signed-in user. The seller's identity is their
  `shops.seller_id`.
- The **service role** (used by admin tooling / Edge Functions) bypasses RLS
  entirely — admin approval flows (verification, tariff receipts) rely on
  that, so no "admin" policy is needed here.
- Schema below reflects what the Dart repositories assume. Where a column is
  marked _assumed_, reconcile it with the live schema before running.

### Shared helper — shop ownership

A `SECURITY DEFINER` helper keeps the ownership check in one place and avoids
recursive RLS evaluation when policies join back to `shops`.

```sql
create or replace function public.is_shop_owner(target_shop_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.shops s
    where s.id = target_shop_id
      and s.seller_id = auth.uid()
  );
$$;

revoke all on function public.is_shop_owner(uuid) from public;
grant execute on function public.is_shop_owner(uuid) to authenticated;
```

---

## 1. `shop_services` — seller delivery/service config

New table backing `SupabaseSellerServicesRepository`.

```sql
create table if not exists public.shop_services (
  shop_id            uuid    not null references public.shops (id) on delete cascade,
  service_type       text    not null,
  enabled            boolean not null default false,
  min_order_amount   numeric,
  fee_amount         numeric,
  warranty_months    integer,
  installment_months integer,
  updated_at         timestamptz not null default now(),
  primary key (shop_id, service_type)
);

alter table public.shop_services enable row level security;

-- Customers browsing a shop page may read its enabled services.
create policy "shop_services public read"
  on public.shop_services
  for select
  using (true);

-- A seller fully manages the service rows of shops they own.
create policy "shop_services owner write"
  on public.shop_services
  for all
  using (public.is_shop_owner(shop_id))
  with check (public.is_shop_owner(shop_id));
```

---

## 2. `shops` — shop settings (working hours, contact, visibility)

`ShopSettings` is the seller-editable view of the `shops` row.

```sql
alter table public.shops enable row level security;

-- Public catalog browsing — anyone reads visible shops.
create policy "shops public read"
  on public.shops
  for select
  using (true);

-- A seller updates only their own shop.
create policy "shops owner update"
  on public.shops
  for update
  using (seller_id = auth.uid())
  with check (seller_id = auth.uid());

-- A seller creates a shop they own (onboarding).
create policy "shops owner insert"
  on public.shops
  for insert
  with check (seller_id = auth.uid());
```

> `working_hours` is assumed to be a `jsonb` column on `shops`. If it lives in
> a separate `shop_working_hours` table, mirror the `shop_services` policy
> pair (public read + `is_shop_owner` write) for it.

---

## 3. `orders` — seller order list, detail & status transitions

Per the existing schema note, `orders` has **no `shop_id`** — an order belongs
to a seller transitively via `order_items.product_id → products.shop_id`.

```sql
alter table public.orders enable row level security;

-- Customers see and create their own orders.
create policy "orders customer read"
  on public.orders
  for select
  using (user_id = auth.uid());

create policy "orders customer insert"
  on public.orders
  for insert
  with check (user_id = auth.uid());

-- A seller reads an order if it contains at least one of their products.
create policy "orders seller read"
  on public.orders
  for select
  using (
    exists (
      select 1
      from public.order_items oi
      join public.products p on p.id = oi.product_id
      where oi.order_id = orders.id
        and public.is_shop_owner(p.shop_id)
    )
  );

-- A seller may update an order (status transitions: confirm / preparing /
-- shipped / delivered / cancel) only for orders containing their products.
-- Note: this does NOT restrict WHICH columns change — enforce the legal
-- status state-machine in a BEFORE UPDATE trigger or an Edge Function.
create policy "orders seller update"
  on public.orders
  for update
  using (
    exists (
      select 1
      from public.order_items oi
      join public.products p on p.id = oi.product_id
      where oi.order_id = orders.id
        and public.is_shop_owner(p.shop_id)
    )
  )
  with check (true);

-- order_items inherit visibility from their parent order.
alter table public.order_items enable row level security;

create policy "order_items participant read"
  on public.order_items
  for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and (
          o.user_id = auth.uid()
          or exists (
            select 1 from public.products p
            where p.id = order_items.product_id
              and public.is_shop_owner(p.shop_id)
          )
        )
    )
  );
```

> **Realtime:** `SupabaseSellerOrderRepository` subscribes to `orders` changes
> via `RealtimeService`. Realtime respects RLS, so add the table to the
> publication: `alter publication supabase_realtime add table public.orders;`

---

## 4. `verification_documents` + `seller_verifications` — KYC

Private documents — **no public read**. Only the owning seller and the
service role (admin review) may touch them.

```sql
-- Per-document rows (passport, license, ...).
alter table public.verification_documents enable row level security;

create policy "verification_documents owner all"
  on public.verification_documents
  for all
  using (seller_id = auth.uid())
  with check (seller_id = auth.uid());

-- Verification request + status (pending / in_review / approved / rejected).
alter table public.seller_verifications enable row level security;

-- Seller reads their own status; status is written by the admin/service role.
create policy "seller_verifications owner read"
  on public.seller_verifications
  for select
  using (seller_id = auth.uid());

create policy "seller_verifications owner submit"
  on public.seller_verifications
  for insert
  with check (seller_id = auth.uid());
```

### Storage bucket — `verification-docs` (private)

```sql
-- Bucket must be created as PRIVATE (not public). Path convention:
--   verification-docs/<seller_uid>/<doc_type>.<ext>
create policy "verification docs owner objects"
  on storage.objects
  for all
  using (
    bucket_id = 'verification-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'verification-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
```

---

## 5. `subscription_receipts` — tariff P2P payment receipts

The seller uploads a payment screenshot; an admin approves it. The seller may
create and read their own receipts; only the service role flips the status.

```sql
alter table public.subscription_receipts enable row level security;

create policy "subscription_receipts owner read"
  on public.subscription_receipts
  for select
  using (seller_id = auth.uid());

create policy "subscription_receipts owner insert"
  on public.subscription_receipts
  for insert
  with check (
    seller_id = auth.uid()
    -- A freshly-uploaded receipt must start unapproved; approval is an
    -- admin/service-role action.
    and status = 'pending'
  );

-- `subscriptions` — the seller reads their own plan + pending request.
alter table public.subscriptions enable row level security;

create policy "subscriptions owner read"
  on public.subscriptions
  for select
  using (seller_id = auth.uid());
```

### Storage bucket — `payment-receipts` (private)

```sql
create policy "payment receipts owner objects"
  on storage.objects
  for all
  using (
    bucket_id = 'payment-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'payment-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
```

> `subscription_plans` (the read-only plan catalog) stays public-readable and
> needs no seller-write policy — it is curated server-side.

---

## Post-apply checklist

- [ ] `is_shop_owner` helper created; `execute` granted to `authenticated`.
- [ ] RLS **enabled** on every table above (a table with policies but RLS off
      is still wide open).
- [ ] `orders` added to the `supabase_realtime` publication.
- [ ] `verification-docs` and `payment-receipts` buckets created as **private**.
- [ ] `get_advisors(type: security)` returns no findings.
- [ ] Manual smoke test: seller A cannot read seller B's orders, services,
      verification docs, or receipts.

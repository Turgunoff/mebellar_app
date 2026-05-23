-- Chat system for order-scoped messaging between customers and sellers.
-- One chat per order; created lazily on first message. Supports text +
-- image messages, read receipts, and unread counts maintained by a
-- trigger so each side gets the right badge without client-side counting.

-- 1. Tables ────────────────────────────────────────────────────────────────

create table public.chats (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  -- Key off shop_id (not seller_id) so chats survive future ownership
  -- transfers — shop_id is the stable identity, seller_id might be
  -- reassigned. Joins to `shops` get us back to the active seller_id.
  shop_id uuid not null references public.shops(id) on delete cascade,
  last_message_at timestamptz,
  last_message_preview text,
  customer_unread_count integer not null default 0,
  seller_unread_count integer not null default 0,
  created_at timestamptz not null default now(),
  -- 1 chat per order — whoever opens it first gets the canonical row;
  -- the other side sees the same thread.
  unique (order_id)
);

create index chats_customer_idx
  on public.chats (customer_id, last_message_at desc nulls last);

create index chats_shop_idx
  on public.chats (shop_id, last_message_at desc nulls last);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_role text not null check (sender_role in ('customer', 'seller')),
  -- A message carries text, an attachment, or both. The CHECK below
  -- enforces "at least one is present" so an empty insert is impossible.
  body text check (body is null or (length(body) > 0 and length(body) <= 4000)),
  attachment_url text,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (body is not null or attachment_url is not null)
);

create index chat_messages_thread_idx
  on public.chat_messages (chat_id, created_at);

-- 2. Trigger: keep chat.last_message_* and unread counts in sync ──────────

create or replace function public._chat_after_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_preview text;
begin
  -- Preview: body when present, otherwise a short attachment marker
  -- so the chat list shows *something* readable instead of an empty row.
  v_preview := coalesce(
    nullif(substring(new.body, 1, 100), ''),
    case when new.attachment_url is not null then '📎' else '' end
  );

  update public.chats
  set
    last_message_at = new.created_at,
    last_message_preview = v_preview,
    customer_unread_count = case
      when new.sender_role = 'seller' then customer_unread_count + 1
      else customer_unread_count
    end,
    seller_unread_count = case
      when new.sender_role = 'customer' then seller_unread_count + 1
      else seller_unread_count
    end
  where id = new.chat_id;

  return new;
end;
$$;

create trigger trg_chat_after_message_insert
  after insert on public.chat_messages
  for each row execute function public._chat_after_message_insert();

-- 3. RLS ───────────────────────────────────────────────────────────────────

alter table public.chats enable row level security;
alter table public.chat_messages enable row level security;

-- 3a. Chats — visible to the customer who owns the order and to the
-- seller who owns the shop. Wrapped `select auth.uid()` so the planner
-- doesn't re-evaluate per-row (same pattern as the project's other RLS).

create policy chats_read on public.chats
  for select using (
    customer_id = (select auth.uid())
    or exists (
      select 1 from public.shops s
      where s.id = chats.shop_id
        and s.seller_id = (select auth.uid())
    )
  );

-- Insert: only the customer initiates a chat (sellers reply, they don't
-- spontaneously start). The customer must own the referenced order
-- (orders.user_id is the customer's auth.uid in this schema).
create policy chats_customer_insert on public.chats
  for insert with check (
    customer_id = (select auth.uid())
    and exists (
      select 1 from public.orders o
      where o.id = chats.order_id
        and o.user_id = (select auth.uid())
    )
  );

-- 3b. Messages — read where the user is a chat participant; insert where
-- they are also the declared sender on the correct side.

create policy chat_messages_read on public.chat_messages
  for select using (
    exists (
      select 1 from public.chats c
      where c.id = chat_messages.chat_id
        and (
          c.customer_id = (select auth.uid())
          or exists (
            select 1 from public.shops s
            where s.id = c.shop_id
              and s.seller_id = (select auth.uid())
          )
        )
    )
  );

create policy chat_messages_insert on public.chat_messages
  for insert with check (
    sender_id = (select auth.uid())
    and exists (
      select 1 from public.chats c
      where c.id = chat_messages.chat_id
        and (
          (c.customer_id = (select auth.uid()) and sender_role = 'customer')
          or (
            sender_role = 'seller'
            and exists (
              select 1 from public.shops s
              where s.id = c.shop_id
                and s.seller_id = (select auth.uid())
            )
          )
        )
    )
  );

-- 4. Mark-as-read RPC ─────────────────────────────────────────────────────
-- Read receipts and unread-counter resets in one transaction. Runs as
-- security definer so the trigger-maintained counters can be zeroed
-- without granting raw UPDATE on chats to users.

create or replace function public.mark_chat_read(p_chat_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
begin
  -- Resolve the caller's role on this chat (or refuse if not a participant).
  select case
    when customer_id = v_uid then 'customer'
    when exists (
      select 1 from public.shops s
      where s.id = shop_id and s.seller_id = v_uid
    ) then 'seller'
    else null
  end
  into v_role
  from public.chats
  where id = p_chat_id;

  if v_role is null then
    raise exception 'not a chat participant';
  end if;

  -- Stamp read_at on every still-unread message from the OTHER side.
  update public.chat_messages
  set read_at = now()
  where chat_id = p_chat_id
    and read_at is null
    and sender_role <> v_role;

  -- Reset our side of the counter.
  update public.chats
  set
    customer_unread_count = case when v_role = 'customer' then 0 else customer_unread_count end,
    seller_unread_count = case when v_role = 'seller' then 0 else seller_unread_count end
  where id = p_chat_id;
end;
$$;

grant execute on function public.mark_chat_read(uuid) to authenticated;

-- 5. Storage bucket for chat attachments ──────────────────────────────────

insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', true)
on conflict (id) do nothing;

-- Path convention: `<chat_id>/<uuid>.<ext>` — first folder segment is the
-- chat id, used by the upload policy to confirm the uploader is a
-- participant of that chat.

create policy chat_attachments_upload on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.chats c
      where c.id::text = (storage.foldername(name))[1]
        and (
          c.customer_id = (select auth.uid())
          or exists (
            select 1 from public.shops s
            where s.id = c.shop_id and s.seller_id = (select auth.uid())
          )
        )
    )
  );

-- Bucket is public, but we still spell the read policy explicitly so
-- anonymous browsers can fetch attachment URLs straight off the CDN.
create policy chat_attachments_read on storage.objects
  for select using (bucket_id = 'chat-attachments');

-- 6. Realtime publication ─────────────────────────────────────────────────
-- New messages and chat-row updates (unread counters, last_message_*)
-- must reach the open thread / list screens without polling.

alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.chats;

-- Per-install FCM registration tokens. One row per (token, user) pair.
-- The token itself is the primary key because the same FCM token must not
-- map to two different users at the same time — when a different user signs
-- in on the same device, the upsert from the client replaces user_id.
--
-- Edge functions / server-side push senders read this table (via the
-- service role key) to look up which tokens to fan out to for personal
-- notifications (e.g. "your order was delivered"). Topic-based broadcasts
-- (the `news` channel) bypass this table entirely.

create table if not exists public.device_tokens (
  token       text        primary key,
  user_id     uuid        not null references auth.users(id) on delete cascade,
  platform    text        not null check (platform in ('android', 'ios', 'web')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

create policy "Users can view own tokens"
  on public.device_tokens for select
  using (auth.uid() = user_id);

create policy "Users can insert own tokens"
  on public.device_tokens for insert
  with check (auth.uid() = user_id);

create policy "Users can update own tokens"
  on public.device_tokens for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own tokens"
  on public.device_tokens for delete
  using (auth.uid() = user_id);

create index if not exists device_tokens_user_id_idx on public.device_tokens(user_id);

create or replace function public.set_device_tokens_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists device_tokens_set_updated_at on public.device_tokens;
create trigger device_tokens_set_updated_at
  before update on public.device_tokens
  for each row execute procedure public.set_device_tokens_updated_at();

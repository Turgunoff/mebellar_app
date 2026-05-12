-- Public broadcast inbox. Distinct from `notifications` because:
--   * `notifications` rows belong to a single user (auth.uid() = user_id RLS)
--   * `news` rows are read by everyone, anon included
--
-- Read-state for a news item is tracked client-side in a Hive set rather
-- than a per-user join table, so anonymous users (who have no auth.uid)
-- still get a working "unread" badge without us inventing a server-side
-- per-device identifier. The trade-off: clearing app data wipes the read
-- state. Acceptable for marketing pings.

create table if not exists public.news (
  id            uuid        primary key default gen_random_uuid(),
  title         text        not null,
  body          text        not null default '',
  data          jsonb       not null default '{}'::jsonb,
  published_at  timestamptz not null default now(),
  is_active     boolean     not null default true,
  created_at    timestamptz not null default now()
);

alter table public.news enable row level security;

-- Anyone (including anon) can read active news items.
create policy "news_public_read"
  on public.news for select
  using (is_active = true);

-- INSERT/UPDATE/DELETE intentionally have NO policy → only service_role
-- (Edge Functions, admin tools) can mutate. Users can't post broadcasts
-- to themselves or each other.

create index if not exists news_active_published_idx
  on public.news(is_active, published_at desc);

alter publication supabase_realtime add table public.news;

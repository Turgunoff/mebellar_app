alter table public.profiles
  add column if not exists is_deleted boolean not null default false;

create index if not exists profiles_is_deleted_idx
  on public.profiles(is_deleted) where is_deleted = true;

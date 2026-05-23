-- PostgREST infers embeds from declared FK constraints; the original
-- `chats.customer_id -> auth.users(id)` FK doesn't help when we want to
-- embed `profiles`, because `profiles.id` is itself only a FK to
-- auth.users (1:1) — no edge directly to chats. Declaring a *second*
-- parallel FK to profiles.id closes that gap. Both cascades fire from
-- the same root (auth.users deletion → profiles deletion → chats
-- deletion), so adding this constraint changes no semantics.

alter table public.chats
  add constraint chats_customer_id_profiles_fkey
  foreign key (customer_id)
  references public.profiles(id)
  on delete cascade;

-- Tell PostgREST to refresh its schema cache so the new relationship
-- becomes embeddable immediately. Equivalent to bouncing the API.
notify pgrst, 'reload schema';

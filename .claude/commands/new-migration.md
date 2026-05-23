---
description: Scaffold a new Supabase migration with the correct timestamp.
---

Create a new file under `supabase/migrations/` named
`<UTC-timestamp>_<snake_case_name>.sql`. Steps:

1. Ask me for the migration's purpose in one short phrase if I didn't
   already say (e.g. "add wishlist table"). Convert it to snake_case
   for the filename.
2. Generate the timestamp via `date -u +%Y%m%d%H%M%S` (UTC, matching
   the existing convention in `supabase/migrations/`).
3. Write the file with a header comment block explaining the intent
   plus the SQL. Default template:

   ```sql
   -- <one-line purpose>
   --
   -- Context: <2–3 lines on why this change exists and what depends on it>
   --
   -- Reversibility: <how to roll back, or "additive only">

   -- <DDL/DML here>

   notify pgrst, 'reload schema';
   ```

4. Tell me to apply it via the Supabase MCP `apply_migration` tool
   (atomic + logged) rather than pasting into the dashboard. Do NOT
   run `apply_migration` automatically — I'll review the SQL first.

Reference: every migration in this repo is idempotent where possible
(`create table if not exists`, `drop policy if exists` before `create
policy`). Follow that style — `supabase db reset` runs all migrations
in order and any non-idempotent step breaks fresh setups.

Beware the project-specific gotchas before writing the SQL — see the
**Supabase RLS gotchas** section of `CLAUDE.md`. In particular:

- `orders.user_id`, not `orders.customer_id`
- Don't reference unqualified `name` inside `EXISTS (SELECT 1 FROM
  shops ...)` — collides with `shops.name`
- For PostgREST embeds with ambiguous FKs, use the constraint name:
  `relation:other_table!constraint_name(...)`

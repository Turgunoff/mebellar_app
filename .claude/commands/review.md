---
description: Review my uncommitted changes with the Flutter code-reviewer subagent.
---

Local diff review — no GitHub needed. Steps:

1. Show what changed: `git status --short` and `git diff` (plus
   `git diff --staged`). If the tree is clean, say so and stop.
2. Launch the **code-reviewer** subagent on the diff. It reads
   `.claude/rules/` + `CLAUDE.md` and reports Blocker / Should-fix / Nit —
   checking token colours, no-Supabase, 3-bundle i18n, Bloc/Cubit fit,
   mode boundaries, and analytics safety.
3. As a fast cross-check, also run `grep -ri supabase lib/` — it must
   return nothing. Flag any hit as a Blocker.
4. Print the findings ordered by severity (`file:line` — problem — fix).
   Do **not** apply fixes automatically; let me choose. End with a
   one-line verdict.

If `$ARGUMENTS` names a path or commit range, scope the diff to that.

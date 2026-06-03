# Rule card — backend (woody_backend)

> Distilled invariants for agents and `/review`. Authoritative narrative
> is `CLAUDE.md` (§Backend, §Chat). `CLAUDE.md` wins.

- **The only backend is `woody_backend`** — FastAPI at `api.woody.uz`
  (routes mount under `/api/v1`; `WoodyApiClient` adds the prefix). It owns
  auth, catalog, orders, per-order chat, seller surfaces, presigned R2.
- The Flutter side speaks **only REST + the Woody WebSocket** feed
  (`wss://api.woody.uz/api/v1/realtime/ws`). **No direct DB, no SQL, no
  RLS, no Supabase** — `grep -i supabase lib/` must stay zero, and
  `supabase_flutter` must never return to `pubspec.yaml`.
- **Schema lives elsewhere** — DB + Alembic migrations are in the
  `woody_backend` repo. This repo never writes SQL. A new data need = a new
  backend endpoint first, then a repository here.
- **Repositories** are abstract interfaces; the impl is `Woody*Repository`
  over `WoodyApiClient`, paired with an in-memory mock for tests. No raw
  `Dio`/`Remote*` layer.
- **Uploads** (product images, chat attachments, KYC docs, tariff receipts)
  go through `R2UploadClient` → `POST /storage/upload-url` (presigned PUT)
  with the correct `R2Bucket`. Never push bytes anywhere else.
- **Realtime degrades gracefully** — order/notification updates fall back
  to refresh-on-open + FCM foreground push until the backend publishes the
  matching realtime event. Don't assume a socket message will always
  arrive.
- **Chat is per-order**: one `chats` row per `order_id` (UNIQUE). The
  customer lazy-creates it on first message; the seller can never spawn a
  chat. Chat stays OPEN forever; the status banner reflects current order
  status.
- **Enums mirror** the backend (`app/domain/enums.py`) and the admin
  (`lib/enums.ts`) — `OrderStatus`, `VerificationStatus`, `ProductStatus`.
  Change one side, change all three (see the workspace `CLAUDE.md`).

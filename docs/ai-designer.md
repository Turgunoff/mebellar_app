# AI Interior Designer

> Companion to the root [`README.md`](../README.md). Where the operational brain [`CLAUDE.md`](../CLAUDE.md) disagrees, it wins.

The AI Interior Designer chat lives under `lib/customer/features/ai_designer/`. The RAG pipeline is **backend-owned** (vision keyword → `ILIKE` products → grounded reply). **There is no AI SDK or API key in the app** — the backend holds the Azure/Foundry key. Gated by the `AI_DESIGNER_ENABLED` backend flag.

## Entry and screen

- `AiChatFab` (`widgets/ai_chat_fab.dart`) — a floating Lottie robot (`assets/lottie/ai_chat_bot.json`) over the home feed.
- Tapping opens route `/ai-designer-chat` → `AiAssistantChatScreen` (`screens/ai_assistant_chat_screen.dart`).
- There is **no grouped-controllers / drawer navigation** — just the FAB plus a full-screen chat route.

## State

`AiDesignerCubit` (`cubit/ai_designer_cubit.dart`) is a **root-scope singleton** for background resilience. `AiDesignerState` carries:

- `messages`;
- `products` — recommended products keyed by message id (in-memory only);
- `localImages` — picked room photos keyed by user-message id; sent to the backend as base64 but **never persisted** (privacy);
- `pending` — a **counter, not a bool**. `sending = pending > 0`. The composer **never disables**, so consecutive sends are allowed and the inline typing indicator stays up until the **last** reply lands (non-blocking inline typing bubble).

## Persistence and quota

- `AiChatStore` (`data/ai_chat_store.dart`) — a Hive box using a **manual Hive adapter (no codegen)** so it stays Shorebird-safe.
- `AiImageQuota` (`data/ai_image_quota.dart`) — image-upload quota.
- `ai_designer_repository.dart`, `models/ai_chat_message.dart`.

## Analytics

`ai_suggest_requested` / `ai_suggest_applied` (the separate seller AI-fill) plus AI-designer usage events (Firebase + Meta).

## Separate seller AI (not this chat)

The add-product form's "AI bilan to'ldirish" CTA → `AddProductCubit.generateFromImages()` → `POST /seller/products/ai-suggest`. Also backend-owned; never auto-saves. See `CLAUDE.md` §"AI product authoring".

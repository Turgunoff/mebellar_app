# Woody / Mebellar

> O'zbekiston bozori uchun ikki tomonlama **mebel marketpleysi** (woody.uz). Xaridorlarni mahalliy mebel sotuvchilari bilan bog'laydi: katalog, savat, buyurtma (COD), buyurtma bo'yicha chat, sotuvchi hamyoni va komissiya tizimi.

Bu repozitoriy **4 ta subproyektni** o'z ichiga oladi va barchasi yagona backend (`api.woody.uz`) bilan ishlaydi.

## 📦 Subproyektlar

| Katalog | Texnologiya | Domen | Rol |
|---|---|---|---|
| [`mebellar_app/`](mebellar_app/) | Flutter | mobil | Customer + Seller (bir binar, ikki rejim) |
| [`woody_backend/`](woody_backend/) | FastAPI | api.woody.uz | Yagona backend (REST + WebSocket) |
| [`woody_admin/`](woody_admin/) | Next.js 16 | admin.woody.uz | Moderatsiya/boshqaruv paneli |
| [`woody_frontend/`](woody_frontend/) | Next.js 14 | woody.uz | Uch tilli marketing landing |

## 📚 Hujjatlar (boshlanish nuqtasi)

Butun platforma hujjatlari [`docs/`](docs/) da kanonik va birlashtirilgan:

| Hujjat | Nima uchun ochiladi |
|---|---|
| 📖 **[TZ.md](TZ.md)** | **Master Technical Specification** — butun platforma uchun yagona haqiqat manbai (system overview, tech stack, core flows, data models, API kontraktlar, texnik qarz reyestri + roadmap). Eski biznes-qoidalar TZ'i shu faylga birlashtirildi. |
| 🏗️ **[docs/architecture/system_design.md](docs/architecture/system_design.md)** | Tizim dizayni — Bloc/Cubit, kesh strategiyasi, single-owner modal pop, FastAPI qatlamlash, tarjima DB strukturasi |
| 🗺️ **[docs/planning/roadmap.md](docs/planning/roadmap.md)** | Bajarilgan vs kelajak bosqichlar (Phase 3: Payme/Click · Phase 4: Referral/Cashback) |
| 🧭 **[docs/README.md](docs/README.md)** | Hujjatlar daraxti indeksi |

Komponent-darajadagi deep-dive'lar va operatsion qo'llanmalar har bir subproyektning `*_tz.md` va `CLAUDE.md` fayllarida.

## 🧱 Stek (qisqacha)

- **Backend:** FastAPI · asyncpg/Postgres · Alembic · Cloudflare R2 · o'z WebSocket · Eskiz (OTP) · Firebase FCM · Azure OpenAI (AI suggest)
- **Mobil:** Flutter · flutter_bloc · GetIt · go_router · Hive · Dio · Crashlytics
- **Admin/Marketing:** Next.js (App Router, server-first) · Tailwind v4 · shadcn/ui

> ℹ️ Tarixiy eslatma: platforma dastlab Supabase'da edi, 2026-05-31 da mustaqil stekka to'liq ko'chirildi. Batafsil: [TZ.md §1 — System Overview](TZ.md#1-system-overview) (Origin note).

## 🚀 Boshlash

Har bir subproyektning o'z setup qo'llanmasi bor — mos `CLAUDE.md` yoki `README.md` ga qarang:
- Backend: [`woody_backend/CLAUDE.md`](woody_backend/CLAUDE.md)
- Mobil: [`mebellar_app/CLAUDE.md`](mebellar_app/CLAUDE.md) (`env/prod.json` majburiy)
- Admin: [`woody_admin/CLAUDE.md`](woody_admin/CLAUDE.md)
- Marketing: [`woody_frontend/DEPLOY.md`](woody_frontend/DEPLOY.md)

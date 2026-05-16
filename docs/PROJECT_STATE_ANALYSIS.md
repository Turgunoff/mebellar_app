# PROJECT_STATE_ANALYSIS.md — Architectural Health Report

> **Prepared by:** Lead Software Architect review pass
> **Date:** 2026-05-16
> **Scope:** Full sweep of `lib/`, `test/`, `integration_test/`, build config, and Supabase backend.
> **Verdict:** ✅ **Code Complete** for the V1 functional scope. `dart analyze` is clean (0 issues) and all **192 tests pass**. One critical *secrets-hygiene* issue (not a code defect) is flagged in §6 for the maintainer to action.

This document is the single source of truth for a new developer joining the team. It describes what the project *is*, how healthy it is, and where the remaining technical debt lives. Read it alongside [`README.md`](../README.md) (onboarding) and [`ROADMAP.md`](../ROADMAP.md) (what's left to build).

---

## 1. Snapshot

| Metric | Value |
| --- | --- |
| Product | **Mebellar** — two-sided furniture (`mebel`) marketplace for Uzbekistan |
| Internal codename | `woody_app` (`pubspec.yaml` → `name:`) |
| Framework | Flutter (Dart SDK `^3.11.5`) |
| Dart source | **360 files**, ~**59,800 lines** under `lib/` |
| Tests | **45 test files**, **192 tests — all green** |
| Static analysis | `dart analyze` — **0 issues** |
| Backend | Supabase (Auth, Postgres, Realtime, Storage) — **23 migrations**, 1 Edge Function |
| Largest screen | `home_screen.dart` — 880 lines (no file exceeds 1000) |

---

## 2. Architecture Overview

The app is a **single Flutter binary hosting two independent product surfaces** — a customer storefront and a seller back-office — that are never mounted at the same time.

### 2.1 Layering

The codebase follows a disciplined layered architecture:

```
UI  (Widgets / Screens)
        │  reads state, dispatches events
        ▼
Logic  (BLoC / Cubit)        ← flutter_bloc
        │  calls
        ▼
Data  (Repository interfaces)
        │  resolved at runtime to…
        ├── Supabase*Repository   (live backend)
        └── Mock*Repository       (canned data)
```

- **`lib/core/`** — cross-cutting infrastructure: DI, auth, networking, i18n, theme, logging, storage, connectivity, realtime, notifications, the `Result<T, Failure>` type.
- **`lib/shared/`** — cross-mode domain: models, repository interfaces + implementations, mocks, shared widgets.
- **`lib/auth/`** — shared login / register / verify / OTP flows.
- **`lib/customer/`** & **`lib/seller/`** — the two surfaces, each split into `features/<name>/{bloc,cubit,screens,widgets}`.

### 2.2 Key architectural patterns

| Pattern | Where | Purpose |
| --- | --- | --- |
| **`Result<T, Failure>`** | `lib/core/result/result.dart`, `lib/core/error/failure.dart` | Typed success/error returns instead of exceptions on repository boundaries. |
| **`RepositoryResolver`** | `lib/core/di/repository_resolver.dart` | Compile-time-friendly switch between `Mock*` and `Supabase*` repositories driven by `AppConfig.useMocks`; lets release builds tree-shake mock data out. |
| **Scoped DI** | `lib/core/di/` (`service_locator.dart` + `*_module.dart`) | `get_it` with a **root scope** (auth, theme, notifications, Hive boxes) and a **mode scope** (`customer` / `seller`) swapped on mode change. |
| **Runtime mode switch** | `AppModeCubit` + `flutter_phoenix` | `popScope()` → `initModeScope(mode)` → `Phoenix.rebirth()` rebuilds the whole tree under the other surface without re-install. |
| **Hand-rolled i18n** | `lib/core/i18n/` | Pure-Dart translation maps (uz / ru / en) — no `easy_localization`; a debug-only completeness guard (`_missing_keys_check.dart`) fails boot if a locale drifts. |

### 2.3 Routing

- **Customer mode** — `go_router` (declarative, `MaterialApp.router`).
- **Seller mode** — also `go_router` by default. `AppConfig.sellerUsesGoRouter` defaults **ON** (`buildSellerRouter()` / `StatefulShellRoute`); flipping it OFF falls back to the legacy imperative `sellerNavigatorKey` shell, kept only as a debugging escape hatch.

### 2.4 Backend

Supabase is the system of record: Postgres tables with **Row-Level Security on every table**, Realtime CDC for orders and notifications, and Storage for product / KYC images. `supabase/migrations/` holds 23 ordered migrations (RLS policies, FK indexes, function hardening, realtime enablement). One Edge Function — `send-news-broadcast` — fans out FCM topic pushes. Firebase is used **only** for FCM messaging.

---

## 3. Codebase Health

**Overall: strong.** This is a well-maintained, consistently-structured codebase — markedly healthier than its file count would suggest.

### 3.1 Green signals

- ✅ `dart analyze` reports **0 issues** across 360 files.
- ✅ **192 tests pass** — BLoC/Cubit unit tests for all 33+ blocs, widget tests, golden tests, repository contract tests, and one end-to-end integration test.
- ✅ **No `TODO` / `FIXME` / `HACK`** markers anywhere in `lib/`.
- ✅ **No stray `print()`** calls — all logging routed through `talker`.
- ✅ No screen exceeds 1000 lines; the six former "god-screens" were already split into `widgets/` sub-trees.
- ✅ Comments are dense and genuinely explanatory — non-obvious decisions (Phoenix rebirth, splash dwell, root-scoped cubits) are documented inline.
- ✅ Secrets have **no compiled-in defaults** — `AppConfig.assertConfigured()` fails the build loudly if env keys are missing.

### 3.2 Test coverage map

| Layer | Coverage |
| --- | --- |
| BLoC / Cubit | Comprehensive — every bloc/cubit has a test file |
| Repository contracts | `b1_repository_contract_test.dart` — parameterised over mock + live interfaces |
| Widgets | cart, checkout, login, register, product gallery |
| Golden | auth, cart, product gallery (baselines in `test/goldens/`) |
| Integration | `integration_test/app_test.dart` — launch → browse → cart → checkout happy path |

**Test directory layout.** `test/` is a **strict mirror of `lib/`** — each test file
sits at the directory that mirrors the path of its subject (e.g.
`test/customer/features/cart/bloc/cart_bloc_test.dart` covers
`lib/customer/features/cart/bloc/cart_bloc.dart`). `test/goldens/` is the sole
exception: baseline PNGs stay in one flat folder. No test files remain in the
`test/` root.

---

## 4. Technical Debt Register

None of the items below block V1. They are ranked by long-term cost. Actionable coding items are mirrored in [`ROADMAP.md`](../ROADMAP.md) Part 2.

| # | Item | Severity | Notes |
| --- | --- | --- | --- |
| TD-1 | **Seller fulfillment behind mocks** | 🟠 Medium | Orders / shop-settings / services / KYC are gated behind `SELLER_FULFILLMENT_ENABLED` (default OFF). Supabase repositories exist (`SupabaseSeller*Repository`); the flag stays off until they are E2E-verified. |
| TD-2 | **`CheckoutCubit` + `CheckoutBloc` coexist** | 🟡 Low | Two state holders for one domain (step state vs. payment events). Legitimate but confusing — merge or document ownership at the top of each file. |
| TD-3 | **Legacy seller navigation path** | 🟡 Low | The pre-`go_router` `sellerNavigatorKey` shell is still compiled behind `sellerUsesGoRouter`. Once go_router has soaked, delete the legacy branch and the flag. |
| TD-4 | **Raw string keys for Hive** | 🟡 Low | A few literals (`'app_mode'`, `'tutorial_seen'`) bypass the `HiveBoxes` typing. Wrap in a typed `SettingsBox` accessor. |
| TD-5 | **Documented-intentional silent catches** | 🔵 Info | 7 remaining `catch (_)` blocks (checkout best-effort cleanup, image-pick fallback, etc.) are all commented as non-fatal. Acceptable; listed for transparency. |
| TD-6 | **Stray repo-root files** | 🔵 Info | `a.md` (scratch notes) and `flutter_01.png` (144 KB screenshot) are tracked at the repo root. Cosmetic — move to `docs/` or untrack. |

---

## 5. Bug Sweep — Findings & Fixes

A full pass for minor bugs, dead code, and unhandled edge cases. **All code-level findings below were fixed in this pass.**

### Fixed

1. **Dead code — `main.dart` Sentry connectivity test block.**
   A `// TEMP` debug-only block sent a probe event to Sentry on every debug launch. Its own comment said "Run once… then delete this block." **Removed.**

2. **Silent failure — `ProfileCubit.load()`.**
   A bare `catch (_)` swallowed every non-`PostgrestException` error while emitting a blank fallback profile, so an RLS denial or transport failure was indistinguishable from a genuinely empty profile and invisible to production triage. **Now `catch (e, st)` with `talker.handle(...)`** — the fallback UX is unchanged, observability is restored.

3. **Silent failure — `ProfileOrdersCubit.load()`.**
   A bare `catch (_)` cleared the loading spinner but discarded the error, so an order-list fetch failure looked identical to "no orders." **Now `catch (e, st)` with `talker.handle(...)`.**

### Reviewed — no change needed

- The remaining 7 `catch (_)` blocks (see TD-5) are intentional, documented best-effort paths.
- No `RenderFlex` / unbounded-constraint risks surfaced in the analyzer or test run.
- `Equatable` `props` were spot-checked on the high-traffic states (`CartState`, `CheckoutState`) — correct.

**Post-fix verification:** `dart analyze` clean; `flutter test` — 192/192 green; affected suites (`profile_cubit_test`, `profile_orders_cubit_test`) re-run and passing.

---

## 6. ⚠️ Critical Security Finding — Maintainer Action Required

> This is **not a code defect** and is reported separately because remediation requires credential rotation only the project owner can perform.

**A Firebase Admin SDK service-account key is committed to the repository:**
`woody-b3c1a-firebase-adminsdk-fbsvc-bbab5cd45d.json` (tracked in git since 2026-05-12).

This file contains a **private key** that can mint OAuth2 tokens with full control over the Firebase project. The project's own `BUGS_AND_ISSUES.md` §1 states such a key "must *never* live in this repo." The `.gitignore` rule that would have caught it (`*-firebase-adminsdk-*.json`) is present but **commented out**.

**Remediation (two parts):**

1. *Repo hygiene* (can be done in-tree): `git rm --cached` the file and re-activate the `.gitignore` rule. This stops future leakage but does **not** scrub the key from existing git history.
2. *Rotation* (**owner-only, mandatory**): generate a new service-account key in the Firebase Console and revoke the old one. Until rotation, treat the leaked key as compromised.

> **Note on `env/prod.json`:** also tracked, but this is a *documented, deliberate* decision (`README.md` §6) — config syncs across the maintainer's machines via a private repo, and the Supabase anon key is RLS-guarded and low-risk by design. Left as-is intentionally.

---

## 7. Recommended Reading Order for New Developers

1. [`README.md`](../README.md) — what the app is, the stack, local setup.
2. This file — architecture and current health.
3. [`ARCHITECTURE.md`](../ARCHITECTURE.md) — deep system design.
4. [`ROADMAP.md`](../ROADMAP.md) — what is built and what remains.
5. `lib/main.dart` → `lib/core/di/service_locator.dart` — trace the boot sequence and DI scopes.

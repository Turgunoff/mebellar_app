# BUGS_AND_ISSUES.md — Bugs, Security & Performance

> Companion to [`ARCHITECTURE.md`](./ARCHITECTURE.md). This document lists every concrete issue identified in the current codebase, ordered by severity. Each item cites the exact file path and line numbers so you can jump straight to it.

Severity legend:

- 🔴 **CRITICAL** — must be fixed before production / store submission.
- 🟠 **HIGH** — fix during the next sprint; will hurt users or operations.
- 🟡 **MEDIUM** — meaningful tech debt; schedule into the medium-term roadmap.
- 🔵 **LOW** — cosmetic / hygiene; nice to have.

---

## 1. Security

### 🔴 1.1 Hardcoded Supabase credentials in source (`lib/config/app_config.dart`)

```dart
// lib/config/app_config.dart:10-19
static const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://oifdvxsfrciatzgivtgs.supabase.co',
);
static const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOi...3ptpS4WFsLW-EHt6EVr-gSLOjGRAew405HTZ2CwWj98',
);
```

**Why it matters.** `String.fromEnvironment` falls back to `defaultValue` whenever the dart-define is missing — meaning any developer (or CI job) who forgets `--dart-define-from-file` ships with the real production Supabase URL and a real anon JWT baked into the binary. That JWT does not expire until **2066-05-26** (~40 years from issue), so it cannot be rotated by waiting.

**Remediation.**

1. Remove the `defaultValue` entirely; fail closed when env vars are missing (throw in `main()`, before `initRootScope`).
2. Rotate the Supabase anon key in the Supabase dashboard.
3. Audit RLS on every table — the anon key is effectively public the moment the APK is decompiled, so RLS is the only line of defence.

### 🔴 1.2 Real credentials committed in `env/dev.json` and `env/prod.json`

```json
// env/prod.json
{
  "SUPABASE_URL": "https://oifdvxsfrciatzgivtgs.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "YANDEX_GEOCODER_API_KEY": "762e99e2-af16-41cf-bff5-25992af0e7ee"
}
```

**Problems:**

1. Both files are **tracked in git** — they are visible to anyone with repo access (and forever in the git history once pushed).
2. `dev.json` and `prod.json` contain **identical credentials**; the only difference is `USE_MOCKS` and `APP_ENV`. Dev should hit a separate Supabase project.
3. `env/.gitignore` only excludes `local.json` / `*.local.json`, not `dev.json` / `prod.json`.
4. The Yandex Geocoder API key is exposed in clear text.

**Remediation.**

1. Add `env/dev.json` and `env/prod.json` to `.gitignore` (project root, not the nested `env/.gitignore`).
2. Run `git rm --cached env/dev.json env/prod.json` and force-rotate every credential they contained.
3. Commit `env/example.json` instead — same shape, dummy values.
4. Spin up a separate Supabase project for dev; keep prod isolated.
5. Restrict the Yandex Geocoder key by HTTP referrer / package name in the Yandex Cloud console.

### 🟠 1.3 Firebase client config files committed without restriction

- `android/app/google-services.json` — tracked.
- `ios/Runner/GoogleService-Info.plist` — tracked.
- `lib/firebase_options.dart` — generated artefact, tracked.

These are technically public-by-design (FCM keys are client identifiers), but they should still be:

- **Locked down with App Check** so unsigned apps can't call FCM HTTP v1 from a stolen key.
- **Restricted in Google Cloud Console** by Android signing fingerprint / iOS bundle id.
- **Backed by Cloud Functions** when sending pushes server-side — never use the legacy server key inside the Flutter app.

### 🟠 1.4 `.gitignore` gaps

The current `.gitignore` (root) does *not* exclude:

- `env/dev.json`, `env/prod.json` (see 1.2)
- `firebase_options.dart` (debatable, but it is regenerable and contains keys)
- Any future `*.keystore` / `key.properties` for Android signing

Add explicit entries; do not rely on developers reading instructional comments (lines 47–51 of `.gitignore` show good intent but no enforcement).

### 🟡 1.5 Silent error swallowing hides auth/permission failures

Several `catch (_) { … }` blocks drop errors without surfacing them:

- `lib/auth/auth_flow.dart:33` — `// Profile lookup is best-effort here; the user is signed in either way.`
- `lib/auth/login_screen.dart` — login error path (form just shows a generic toast).
- `lib/auth/register_screen.dart` — signup error.
- `lib/auth/forgot_password_screen.dart` — reset error.
- `lib/core/storage/cache_store.dart` — read/write errors.
- `lib/core/connectivity/connectivity_service.dart` — `internet_connection_checker_plus` failures.

**Risk.** A user whose Supabase email is unverified can't tell whether the network failed or their account is locked. Also makes it impossible to triage production issues without crash reporting.

**Remediation.**

1. Replace `catch (_)` with `catch (e, st) { talker.handle(e, st, '<context>'); }` — keeps the silent-to-user UX but adds observability.
2. For auth screens specifically, map known failure types (`AuthException` with codes like `email_not_confirmed`, `invalid_credentials`) to localised messages.
3. Wire `talker` to a crash reporter (Sentry / Crashlytics) before launch.

### 🟡 1.6 No App-level transport hardening

- `dio` is built once in `core/network/api_client.dart` with no certificate pinning.
- Android `network_security_config` is the default — accepts any system-trusted CA.
- iOS `Info.plist` is not declaring ATS exceptions but also not pinning.

If the app is targeted with a phishing MITM via a malicious WiFi captive portal, the anon key + user JWT can be lifted. For a furniture marketplace this is probably acceptable, but it is worth documenting the decision.

---

## 2. Architectural Flaws / Broken Logic

### 🟠 2.1 Documentation drift — `README.md` (legacy) and `docs/` cite removed packages

Until this refactor:

- The legacy `README.md` (now overwritten) listed `easy_localization`, `onesignal_flutter`, and `sentry_flutter` — none are in `pubspec.yaml`. The actual stack uses a hand-rolled i18n system, `firebase_messaging`, and `talker_flutter`.
- Several files under `docs/` (e.g. `05-notifications-deep-linking.md`, `12-localization.md`, `13-security.md`) almost certainly describe the old setup.

**Risk.** New contributors and AI assistants build mental models from stale docs and produce wrong code. The current refactor mitigates this with new top-level docs, but `docs/` should be either (a) rewritten or (b) prefixed with a `LEGACY-` banner.

### 🟠 2.2 Project package name `woody_app` ≠ brand `mebellar`

`pubspec.yaml` line 1: `name: woody_app` but native bundle ids are `uz.mebellar.app` / `com.mebellar.app`. This works, but it costs every new contributor 5–15 minutes of cognitive friction (and risks accidental rename via `flutter create` regenerating files under the wrong name).

**Remediation.** Either rename the package to `mebellar_app` (rename string in `pubspec.yaml`, fix import prefixes via `dart fix`) **or** add a top-level `CONTRIBUTING.md` explaining the historical naming.

### 🟠 2.3 Inconsistent routing between modes (GoRouter vs Navigator)

Customer mode uses `go_router` declaratively; seller mode uses `Navigator` + `onGenerateRoute`. As a result:

- Deep-linking from a push works differently per mode (one uses `customerNavigatorKey.go`, the other uses `sellerNavigatorKey.pushNamed`).
- Tutorial-style global redirects work only on the customer side.
- Two route observers must be maintained.

**Risk.** As the seller feature set grows (analytics, reviews, multi-step settings), the cost compounds. New devs default to the customer pattern and forget to register a `Navigator` route on the seller side.

**Remediation.** Migrate seller mode to `go_router` (see `REFACTORING.md` §3.2).

### 🟠 2.4 Seller features still mock-only despite `USE_MOCKS=false` in prod

`service_locator.dart` registers `MockSellerOrderRepository`, `MockShopSettingsRepository`, `MockSellerServicesRepository`, `MockSellerVerificationRepository` **unconditionally** — they ignore `AppConfig.useMocks`. With `env/prod.json` (`USE_MOCKS: false`), customers see live Supabase data while sellers see canned data.

**Risk.** A seller "fulfilling" an order in the app does nothing on the backend, and the customer sees no status change. This is the highest-impact functional bug if a prod build escapes early.

**Remediation.** Either:

1. Hide the affected seller surfaces behind a feature flag (`AppConfig.sellerFulfillmentEnabled`), greyed-out with a "Coming soon" banner.
2. Or implement the missing Supabase repositories before shipping prod. See `ROADMAP.md` §B.

### 🟡 2.5 `getInitialMode()` re-read in `_ModeRouter.build`

```dart
// lib/main.dart:207-210
final app = switch (getInitialMode()) {
  AppMode.customer => const CustomerApp(),
  AppMode.seller   => const SellerApp(),
};
```

This relies on a side-effectful Hive read inside `build`. It works because Phoenix gives a new subtree key on every rebirth, but:

- Hot-reload in dev sometimes shows the wrong mode briefly if the Hive write hasn't flushed before the rebuild.
- A future contributor optimising rebuilds with `const` may break this implicit contract.

**Remediation.** Pass the `AppMode` as a constructor parameter to `_ModeRouter` from the `BlocBuilder<AppModeCubit, AppMode>` that already exists implicitly. Easy fix; eliminates the implicit read.

### 🟡 2.6 `NotificationsCubit` registered in **root** scope but lives in `customer/`

`lib/customer/features/notifications/cubit/notifications_cubit.dart` is referenced from `service_locator.dart` and from `main.dart` directly. The cubit is correctly root-scoped, but its physical location under `customer/` creates a misleading import surface — a seller-mode file pulling from `customer/features/notifications/...` looks like a layering violation even though it isn't.

**Remediation.** Move the file to `lib/shared/bloc/notifications_cubit.dart` (where its sibling `notifications_bloc.dart` already lives) and re-export from `customer/features/notifications/` if needed.

### 🟡 2.7 Hybrid repositories listen to `Supabase.auth.onAuthStateChange` without a `StreamSubscription` getter

`HybridCartRepository` / `HybridFavoritesRepository` attach listeners to `_supabase.auth.onAuthStateChange.listen(...)` inside their constructors but expose **no `dispose()`** to cancel them. They are root-scoped singletons, so leaks only matter at app teardown (Android does this anyway), but in a `flutter_phoenix` rebirth scenario the listeners survive — and the new copy of the singleton (after `popScope`) layers on a second listener.

**Risk.** Memory leak grows each time the user reinstalls the app from cold + each Phoenix rebirth. Practically minor (root singletons aren't disposed by `popScope`), but worth fixing.

**Remediation.** Implement `Future<void> dispose()` and call from the DI `dispose:` callback if you ever move these to mode scope; for now, add an explicit `// keep-forever — root scope` comment.

### 🟡 2.8 Tutorial gate read on every navigation

`buildCustomerRouter()` runs `isTutorialSeen()` (a Hive read) inside the global `redirect`. This fires on **every** route transition, even though the flag is monotonic (false → true, never reverts). Perf impact is negligible but it's an unnecessary I/O on the hot path.

**Remediation.** Cache the value in a `ValueNotifier<bool>` updated when the user dismisses the tutorial; have the redirect read the notifier.

---

## 3. Performance & Memory

### 🟠 3.1 Six screens over 1000 lines (rebuild churn)

| File | Lines |
| --- | --- |
| `lib/seller/features/products/screens/product_form_screen.dart` | **1879** |
| `lib/customer/features/profile/screens/profile_screen.dart` | **1612** |
| `lib/seller/features/settings/screens/shop_settings_screen.dart` | **1269** |
| `lib/seller/features/products/screens/seller_product_detail_screen.dart` | **1201** |
| `lib/seller/features/orders/screens/order_details_screen.dart` | **1086** |
| `lib/auth/auth_bottom_sheet.dart` | **1069** |

**Why this matters for performance:** these screens almost certainly have top-level `BlocBuilder`s wrapping the entire subtree. A single state change rebuilds 1000+ lines of widgets, much of which is structurally constant. With `flutter_staggered_grid_view` and `cached_network_image` in the mix, this can manifest as jank on mid-tier Android devices.

**Remediation.** Split into smaller widgets per logical section, push `BlocBuilder` deeper, and lift `const` constructors aggressively. See `REFACTORING.md` §2.

### 🟠 3.2 `MockData` initialised eagerly via `const`-ish singletons (`lib/shared/mock/mock_data.dart`, 634 lines)

Mock data structures are referenced unconditionally even when `USE_MOCKS=false`. The Dart tree-shaker keeps them in the binary because DI registration mentions both branches.

**Risk.** ~50 KB of canned strings in the prod APK + a small startup cost to materialise the mock model graph.

**Remediation.** Guard mock registrations behind `if (kDebugMode || AppConfig.useMocks)` and put the mock data files behind a deferred import.

### 🟡 3.3 No image-list virtualisation guard

`flutter_staggered_grid_view` is used on the home and product list screens. `cached_network_image` keeps decoded bitmaps in memory by default. On a long catalog scroll on a low-RAM Android device, the in-memory cache balloons.

**Remediation.** Cap `cached_network_image`'s `maxHeightDiskCache` / `maxWidthDiskCache`, and use `memCacheWidth` matched to the rendered pixel dimensions.

### 🟡 3.4 BLoC events that should be debounced/throttled

`SearchBloc` (and the catalog search) emits a new query event on every keystroke without `restartable()` / `debounce` event transformers. Each event fires a network call.

**Remediation.** Wrap the relevant event mapper with `bloc_concurrency`'s `restartable()` and a `Stream.debounce(300ms)`.

### 🟡 3.5 `OrderTrackingService` and `NewOrdersListener` may leak Realtime channels on mode flip

Both services hold Supabase `RealtimeChannel` instances. They're registered in mode scope, so `popScope` should dispose them — but the DI `dispose:` callback for these services isn't visible in `service_locator.dart`. Worth verifying that `.dispose()` cancels the channel via `supabase.removeChannel(...)`.

**Risk.** Leaked Realtime channels keep websockets open and burn Supabase quota.

**Remediation.** Audit each service's `dispose` and ensure `await supabase.removeChannel(_channel)` is called.

### 🟡 3.6 Heavy `print` of debug info via talker in release builds

`talker_flutter` defaults to in-memory + console logging in **all** build modes unless explicitly configured. In release this is wasted CPU + memory.

**Remediation.** Configure `Talker` with `enabled: kDebugMode` for console output, and route release errors to Sentry/Crashlytics instead.

---

## 4. Anti-Patterns

### 🟠 4.1 Hidden mutable state via `getInitialMode()` (impure read in widget)

See §2.5. A `build()` method that reads from disk is technically pure-ish (idempotent within a frame) but is a code-smell that future contributors will copy.

### 🟠 4.2 Catch-all `catch (e)` without rethrowing in repositories

Several Supabase repositories (e.g. `SupabaseCartRepository`, `SupabaseFavoritesRepository`) wrap RPC calls in `try { ... } catch (e) { return /* empty default */ ; }`. The empty-default approach silently degrades the UX to "looks like there's nothing here" when the real cause is an RLS denial.

**Remediation.** Throw a typed `Failure` (the `sealed` hierarchy in `core/error/failure.dart` is unused by these paths) and let the BLoC decide whether to fall back or surface the error.

### 🟠 4.3 Lack of cancellation tokens on long-running futures

When a user switches mode mid-network-call, the customer-side `HomeBloc.add(HomeRequested())` may still be awaiting the previous Dio request. After `popScope`, the BLoC is disposed but the `Future` keeps running until completion. With Phoenix.rebirth's faster perceived speed, this can produce stale UI on the next mode flip back.

**Remediation.** Pass `Dio`'s `CancelToken` through repository methods and cancel from `Bloc.close()`.

### 🟡 4.4 `Equatable` props sometimes omit important fields

Spot-check `CartState` (`customer/features/cart/bloc/cart_bloc.dart`): only `status`, `items`, `error` are in `props`, which is fine. Spot-check `HomeState`: missing `lastRefreshAt` in `props`, so identical lists at different times look equal. **TODO for the maintainer:** audit all `Equatable` overrides; any field consumed by the UI should be in `props`.

### 🟡 4.5 Mixing `Cubit` and `Bloc` for the same domain

`CheckoutCubit` (cubit) and `CheckoutBloc` (bloc) co-exist under `customer/features/checkout/`. The split exists for legitimate reasons (one handles step state, the other handles payment events), but it confuses ownership.

**Remediation.** Merge into a single `CheckoutBloc` with event-based step transitions, or document the split clearly at the top of the cubit file.

### 🟡 4.6 String keys for Hive boxes scattered in code

Several places use string literals like `'app_mode'`, `'tutorial_seen'` directly instead of going through `HiveBoxes` enum + a typed wrapper.

**Remediation.** Add a typed `SettingsBox` wrapper exposing `appMode`, `tutorialSeen`, `locale`, `themeBrightness` as strongly-typed getters/setters; ban raw string Hive keys via custom lint or grep-based CI check.

### 🔵 4.7 Magic numbers for splash dwell / crossfade

`_minSplashDuration = 1400ms`, `_crossfadeDuration = 360ms`, etc. are tucked inside `_ModeRouter`. Should live in `lib/core/theme/durations.dart` or a similar central constants file.

---

## 5. Testing Gaps

### 🟠 5.1 Five test files for 200+ production files

Coverage today (under `test/`):

- `addresses_bloc_test.dart`
- `cart_bloc_test.dart`
- `catalog_bloc_test.dart`
- `favorites_bloc_test.dart`
- `mode_switching_test.dart`

That is **zero** widget tests, **zero** integration tests, **zero** repository tests, **zero** golden tests. Every feature merged since these five was untested.

### 🟠 5.2 No CI to prevent regression

There is no `.github/workflows/` directory. Even the existing five tests are not enforced in PRs.

See `ROADMAP.md` §C.1 for the recommended CI setup.

### 🟡 5.3 Mock repositories not exercised against the same contract tests as live ones

Without contract tests that run against both `MockProductRepository` and `SupabaseProductRepository`, the mocks drift from production. Symptom: a feature that "works in dev" breaks when `USE_MOCKS` is flipped.

---

## 6. Build / Release Risk

### 🟠 6.1 No build flavors (dev/staging/prod)

Currently everything is one Gradle/Xcode flavor with env detection only via `--dart-define-from-file`. There is no separation of:

- Application id (`uz.mebellar.app.dev` vs `uz.mebellar.app`).
- App name / icon (so testers can install both side-by-side).
- Crash-reporting DSN / Supabase project.

**Risk.** A QA tester can't install dev + prod on the same device. Crash reports from beta builds pollute prod dashboards.

**Remediation.** Add Android product flavors and iOS schemes. See `ROADMAP.md` §C.2.

### 🟠 6.2 No code-signing automation

`android/key.properties` is not generated. iOS signing relies on the dev's local Keychain. There is no fastlane / EAS config.

### 🟡 6.3 `flutter_native_splash` config missing from `pubspec.yaml`

`flutter_native_splash: ^2.4.4` is in `dev_dependencies`, but the `flutter_native_splash:` configuration block is *not* present in `pubspec.yaml`. The package will refuse to generate splash assets without it (or use stale assets from a previous run).

**Remediation.** Add a `flutter_native_splash:` block with `color`, `image`, `android_12: {...}` definitions matching the launcher icon's cream brand.

### 🟡 6.4 Obfuscation is documented but not enforced

The README's build commands include `--obfuscate --split-debug-info=build/symbols/`. Without CI, a hand-built release can ship un-obfuscated. Also, symbols at `build/symbols/` aren't uploaded anywhere — so a future Crashlytics integration won't symbolicate properly.

### 🔵 6.5 Shorebird referenced but not integrated

Comments in `pubspec.yaml:51` and `pubspec.yaml:67-68` say "Shorebird code-push" but there is no `shorebird.yaml`, no `shorebird init`, no patches. Either integrate or remove the comments.

---

## 7. Quick-Fix Triage Table

| Item | Severity | Effort | Order |
| --- | --- | --- | --- |
| 1.1 / 1.2 — credential leak | 🔴 | 2h + key rotation | **1** |
| 1.4 — `.gitignore` | 🔴 | 15 min | **2** |
| 2.4 — seller mock-only repos in prod | 🟠 | 1 day to feature-flag, 1–2 weeks to implement | **3** |
| 1.5 — silent error swallowing in auth | 🟡 | 4h | **4** |
| 5.1 — no tests | 🟠 | ongoing | **5** |
| 2.1 — doc drift (now fixed by this refactor) | 🟠 | done | — |
| 3.1 — 1000+ line screens | 🟠 | 2–3 days per screen | **6** |
| 6.1 — no build flavors | 🟠 | 1 day | **7** |
| 6.3 — splash config missing | 🟡 | 30 min | **8** |
| 4.2 — silent repo defaults | 🟠 | 2h per repo | **9** |
| 2.3 — seller routing migration | 🟠 | 3–5 days | **10** |

Items not in the table are tracked in `ROADMAP.md`.

---

## 8. References

- Files with the worst silent error handling: `lib/auth/*.dart`
- Files with the largest LOC counts: see §3.1 table
- DI mock matrix: `lib/core/di/service_locator.dart:267-460`
- Env files: `env/dev.json`, `env/prod.json`, `env/.gitignore`
- Firebase artefacts: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`

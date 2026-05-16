# ROADMAP.md — Action Plan & Future Goals

> Companion to [`REFACTORING.md`](./REFACTORING.md) and [`BUGS_AND_ISSUES.md`](./BUGS_AND_ISSUES.md). This roadmap turns the issue lists into a phased execution plan with concrete acceptance criteria. Phases are sized assuming a solo developer ± occasional contractor help.

The three horizons:

- **Section A — Short-term** (this week → ~3 weeks). Critical fixes that block production. No new features.
- **Section B — Mid-term** (1 → 3 months). Complete missing features, build tests, finish seller side.
- **Section C — Long-term** (3 → 6 months). CI/CD, flavors, store release, post-launch ops.

---

## Section A — Short-Term (Weeks 1–3): Production Blockers

### A.1 — Credential rotation & secrets hygiene 🔴

**Goal.** Stop leaking secrets through committed files and hardcoded defaults.

**Tasks**

- [ ] Rotate Supabase anon key in dashboard.
- [ ] Regenerate Yandex Geocoder API key with package/referrer restrictions.
- [ ] `git rm --cached env/dev.json env/prod.json`.
- [ ] Append to root `.gitignore`:
  ```
  /env/dev.json
  /env/prod.json
  /env/*.json
  !env/example.json
  ```
- [ ] Commit `env/example.json` with placeholder shape.
- [x] Remove `defaultValue` strings from `lib/config/app_config.dart` — fail fast if env vars missing.
- [ ] Set up a private dev Supabase project; populate `env/dev.local.json` (gitignored) with separate keys.
- [x] Document the new flow in `README.md`.
- [ ] Spot-check decompiled APK to confirm the old keys are gone.

**Acceptance** — `flutter build apk` with **no** env file fails loudly. Decompiled release APK contains no readable Supabase/Yandex URL or key strings.

**Estimate.** 1 day + waiting time for key rotation propagation.

### A.2 — Feature-flag the mock-only seller surfaces 🔴

**Goal.** Prevent a prod build from showing fake order/settings data to real sellers (see `BUGS_AND_ISSUES.md` §2.4).

**Tasks**

- [x] Add `AppConfig.sellerFulfillmentEnabled` (default `false`).
- [x] In `service_locator.dart`, register the mock-backed seller repos only when the flag is on.
- [x] When the flag is off, swap the affected seller screens for a "Coming soon — beta" placeholder.
- [x] Same treatment for `shop_settings`, `seller_services`, `seller_verification` until their backends ship.

**Acceptance** — Running with `env/prod.json` does not surface mock data anywhere. Beta sellers see a clear "feature coming soon" instead of fake orders.

**Estimate.** 1 day.

### A.3 — Wire error logging to a real backend 🟠

**Goal.** Stop the auth + repository silent-catch black holes (see `BUGS_AND_ISSUES.md` §1.5, §4.2).

**Tasks**

- [x] Replace every `catch (_)` in `lib/auth/*.dart`, `lib/core/`, and `lib/shared/repositories/` with `catch (e, st) { talker.handle(e, st, '<ctx>'); }`.
- [x] Add Sentry (or Firebase Crashlytics — pick one):
  - `sentry_flutter` ^8.x with DSN injected via `--dart-define`.
  - Wire `talker_flutter` → Sentry adapter.
- [x] Surface user-facing errors via the existing `NetworkOverlayWrapper` / scaffold snackbars.
- [x] Map known Supabase `AuthException` codes (`email_not_confirmed`, `invalid_credentials`, `over_email_send_rate_limit`) to localised user messages.

**Acceptance** — A forced auth error appears both as a user toast in the app and as a structured event in Sentry within 10 seconds.

**Estimate.** 2–3 days.

### A.4 — Strip credential defaults from `app_config.dart` 🔴

Already covered by A.1 — kept here as a separate review checkpoint to ensure the change merges before any tagged release.

### A.5 — Update / archive legacy docs 🟡

**Tasks**

- [x] Move `docs/` → `docs/legacy/` with a top-of-folder note: *"These predate the firebase_messaging / hand-rolled-i18n stack and may be inaccurate."*
- [x] Update `docs/README.md` to point at the new root docs.
- [x] Cross-check `docs/13-security.md` against the new `BUGS_AND_ISSUES.md` and either delete or update.

**Acceptance** — A new contributor reading top-level docs encounters no contradictions.

**Estimate.** Half a day.

### A.6 — Tighten silent error UX on auth screens 🟠

Subset of A.3 worth highlighting:

- [x] `login_screen.dart` — distinguish "wrong password" vs "no internet" vs "email not verified".
- [x] `register_screen.dart` — surface "email already in use".
- [x] `forgot_password_screen.dart` — show success state even when Supabase rate-limits (per OWASP guidance, don't reveal whether the email exists).

**Acceptance** — A manual matrix test of 6 scenarios (good/bad credentials, no network, rate-limited, unverified, duplicate) produces a sensible message for each.

**Estimate.** 1 day.

---

## Section B — Mid-Term (Months 1–3): Completion & Quality

### B.1 — Complete seller-side Supabase repositories

Removes the mock blocks gated in A.2.

**Tasks**

- [x] `SupabaseSellerOrderRepository` — list + detail + status transitions (accept / reject / mark shipped / mark delivered) with Realtime updates for sellers.
- [x] `SupabaseShopSettingsRepository` — working hours, delivery zones, contact info.
- [x] `SupabaseSellerServicesRepository` — selectable delivery services tied to shop.
- [x] `SupabaseSellerVerificationRepository` — KYC submission + status polling.
- [x] `SupabaseTariffRepository` (write path) — P2P payment receipt upload + approval flow.
- [x] Backfill RLS policies for each new table; review with `mcp__supabase__get_advisors` before going live.

**Acceptance** — Flipping the feature flag from A.2 to `true` in `env/prod.json` does not break any seller flow. Manual end-to-end test: create product → receive order → fulfill → mark delivered, all on real Supabase data.

**Estimate.** 3–4 weeks.

### B.2 — Customer payment flow

Currently the customer checkout flow stops short of capturing a payment. For Uzbekistan MVP, this likely means:

**Tasks**

- [~] DEFERRED (Post-MVP) — Pick a payment partner (Payme, Click, Octo, or P2P-to-Card flow).
- [~] DEFERRED (Post-MVP) — Implement the SDK or webview integration in `customer/features/checkout/`.
- [~] DEFERRED (Post-MVP) — Add `payment_intents` Supabase table + Edge Function for confirmation callback.
- [~] DEFERRED (Post-MVP) — Order remains in `pending_payment` until callback flips to `paid`.

**Status.** DEFERRED (Post-MVP) — strategic scope call: V1 ships with offline
P2P / cash-on-delivery only; no third-party payment SDK. Revisit after launch.

**Acceptance** — A test card / sandbox payment moves an order through the full lifecycle including the seller's notification.

**Estimate.** 3–4 weeks (heavily dependent on partner approval timelines).

### B.3 — Migrate seller mode to `go_router`

See `REFACTORING.md` §3.2.

**Tasks**

- [x] Split the 1000+ line seller screens first (`REFACTORING.md` §1.3, §1.4, §1.5).
- [x] Define seller route tree.
- [x] Migrate one screen at a time behind a `sellerUsesGoRouter` flag.
- [x] Once parity is reached, delete the legacy `onGenerateRoute`.

**Acceptance** — Push tap on a seller-targeted notification deep-links into the right screen without using `sellerNavigatorKey`.

**Estimate.** 2–3 weeks.

### B.4 — Split the six 1000+ line screens

`REFACTORING.md` §1.1–1.6. Worth doing in parallel with B.3 because seller settings split (1.3) directly unblocks routing migration.

- [x] Split all six 1000+ line god-screens (product form, profile, shop
      settings, seller product detail, auth bottom sheet, order details) into
      `widgets/` sub-trees + extracted controllers.

**Status.** DONE — none of the six target screens exceed 1000 lines. A few
unrelated screens still sit in the 600–880 line range (home, tariff,
analytics, tutorial, reviews); trimming those is a nice-to-have, not a B.4
blocker.

**Estimate.** 2–3 weeks elapsed; can be done piecemeal.

### B.5 — Test coverage baseline

**Goal.** Ship V1 with at least 30 % coverage and ~95 % coverage on critical flows (auth, cart, checkout, mode switching).

**Tasks**

- [x] Add `bloc_concurrency` + `clock` packages.
- [x] Facade wrappers for `FirebaseMessaging`, `Geolocator`, `ImagePicker`, `Connectivity` (see `REFACTORING.md` §5.2–5.3). (Connectivity already had a `ConnectivityService` facade.)
- [x] Repository contract tests (§5.4) — suites for the 5 B.1 interfaces, parameterised over implementations.
- [x] BLoC tests for every cubit/bloc — all 33 BLoCs/Cubits covered.
- [x] Widget tests for the cart, checkout, product detail, login, register screens.
- [x] Golden tests via `matchesGoldenFile` — auth / cart / product gallery (baselines committed to `test/goldens/`).
- [x] One integration test (`integration_test` package) for the happy path: launch → browse → add to cart → checkout → see order in history.

**Acceptance** — `flutter test --coverage` reports ≥ 30 % overall coverage; CI fails if coverage drops.

**Estimate.** Ongoing, ~1 day/week throughout B.

### B.6 — Refactor backbone: `service_locator` modularisation, `Result<T, Failure>`, `RealtimeService`, `AppSettings`

`REFACTORING.md` §2.1, §3.3, §3.4, §3.5. These are mechanical-ish refactors but easier earlier than later.

**Estimate.** 1 week.

### B.7 — Performance pass

`BUGS_AND_ISSUES.md` §3 and `REFACTORING.md` §4.

**Tasks**

- [x] `bloc_concurrency` event transformers on `SearchBloc`, `HomeBloc`, `OrdersBloc`.
- [x] `memCacheWidth` on every `CachedNetworkImage`.
- [~] DEFERRED (Post-MVP) — Profile a long catalog scroll on a $150 Android device (Tecno / Infinix range) — needs physical hardware.
- [x] Defer-load mock data — superseded by compile-time mock tree-shaking (`AppConfig.useMocks`-gated `RepositoryResolver`), which removes mock data from release binaries entirely.
- [x] Audit Supabase Realtime channel disposal across services.

**Acceptance** — p99 frame time on the home screen under <16 ms on a Galaxy A15 reference device with 100 catalog items.

**Estimate.** 1 week.

### B.8 — Localization completeness

**Tasks**

- [x] Audit every `tr(...)` call site for missing keys in `ru` / `en` — 322 unique keys checked, 0 gaps.
- [~] USER ACTION — Run the app fully in each locale and screenshot every screen (manual visual pass; structural completeness already CI-guarded).
- [x] Add a `lib/core/i18n/translations/_missing_keys_check.dart` developer tool (assert in `kDebugMode` if any locale has fewer keys than `uz`).
- [~] DEFERRED (Post-MVP) — Wire Shorebird code-push (see C.4) — handled manually via the local CLI for now.

**Acceptance** — Switching to `ru` or `en` shows no untranslated `key.subkey` placeholders anywhere.

**Estimate.** 1 week.

---

## Section C — Long-Term (Months 3–6): Operations & Launch

### C.1 — CI/CD pipeline (GitHub Actions)

**Goal.** Every PR gets analysed, tested, and produces a debug-signed APK + iOS archive.

**Suggested workflows** (`.github/workflows/`):

```yaml
# .github/workflows/ci.yml
name: ci
on:
  push: { branches: [main] }
  pull_request:
jobs:
  analyze-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      - run: dart format --set-exit-if-changed lib/ test/
      - run: flutter analyze --fatal-infos
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v4
        with: { files: coverage/lcov.info }
```

```yaml
# .github/workflows/build-android.yml
name: build-android
on:
  push: { tags: ['v*.*.*'] }
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      - run: |
          echo "${{ secrets.ANDROID_KEYSTORE_B64 }}" | base64 -d > android/app/upload.keystore
          cat > android/key.properties <<EOF
          storeFile=upload.keystore
          storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
          keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
          EOF
      - run: |
          flutter build appbundle --release \
            --obfuscate --split-debug-info=build/symbols \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }} \
            --dart-define=YANDEX_GEOCODER_API_KEY=${{ secrets.YANDEX_GEOCODER_API_KEY }} \
            --dart-define=APP_ENV=prod --dart-define=USE_MOCKS=false
      - uses: actions/upload-artifact@v4
        with:
          name: app-release-bundle
          path: build/app/outputs/bundle/release/app-release.aab
```

```yaml
# .github/workflows/build-ios.yml
# Runs on macos-latest with fastlane match for signing.
```

**Acceptance** — A tagged commit produces a downloadable `.aab` and `.ipa`. PRs are blocked on `analyze-test`.

**Estimate.** 1 week.

### C.2 — Build flavors (dev / staging / prod)

**Android (`android/app/build.gradle`):**

```groovy
android {
    flavorDimensions "env"
    productFlavors {
        dev      { applicationIdSuffix ".dev"; versionNameSuffix "-dev"; resValue "string", "app_name", "Mebellar Dev" }
        staging  { applicationIdSuffix ".staging"; versionNameSuffix "-staging"; resValue "string", "app_name", "Mebellar Staging" }
        prod     { resValue "string", "app_name", "Mebellar" }
    }
}
```

**iOS** — three schemes (`Runner-dev`, `Runner-staging`, `Runner`) and three xcconfigs.

**Flutter side** — `flutter run --flavor dev --dart-define-from-file=env/dev.local.json`.

**Acceptance** — Tester can install Mebellar Dev + Mebellar Prod side-by-side on the same device.

**Estimate.** 2–3 days Android, 2–3 days iOS, 1 day for documentation.

### C.3 — Store-readiness checklist

**Google Play (`store/google_play_listing.md` already exists):**

- [ ] Privacy policy hosted at a stable URL (already drafted in `store/privacy_policy.md`).
- [ ] Data safety section: list collected data (email, FCM token, location for delivery, IDs for orders, images for products/KYC, payment status).
- [ ] In-app purchase declaration: tariffs are bought via P2P transfer (not Google billing), so declare as "Real money items" rather than "Digital purchases".
- [ ] Screenshots: 8 per locale (uz, ru, en), 2:1 phone + tablet.
- [ ] Feature graphic 1024×500.
- [ ] Closed testing track for at least 14 days with 12 unique testers (Play Store requirement for new personal/developer accounts since 2024).

**Apple App Store:**

- [ ] App Store Connect: bundle id `uz.mebellar.app` / `com.mebellar.app`.
- [ ] Privacy nutrition labels: same data inventory as Play Store.
- [ ] App icon flat (no transparency, already configured via `flutter_launcher_icons.remove_alpha_ios: true`).
- [ ] Demo account for review with both customer + seller modes accessible.
- [ ] Review note explaining the mode switch (otherwise reviewers may file it as a "missing functionality").
- [ ] TestFlight beta with at least 20 external testers for 1 week before submission.

**Acceptance** — A test internal release passes both stores' review checklists without rejection.

**Estimate.** 2 weeks elapsed (lots of waiting on store reviews).

### C.4 — Shorebird code-push integration

Already alluded to in `pubspec.yaml` comments but not implemented.

**Tasks**

- [ ] `shorebird init`.
- [ ] Add `shorebird release android` / `shorebird release ios` to the CD workflows.
- [ ] Test a patch cycle: ship a copy edit via `shorebird patch android` without rebuilding the APK.
- [ ] Decide on the upgrade strategy: silent? prompt? blocking after N days?

**Acceptance** — A typo fix in `lib/core/i18n/translations/common_translations.dart` reaches every installed device within 24 hours without a Play Store update.

**Estimate.** 1 week.

### C.5 — Observability + analytics

**Tasks**

- [ ] Sentry / Crashlytics — error tracking (already in A.3).
- [ ] Add a lightweight events SDK: PostHog or Amplitude.
- [ ] Wire route observers + key BLoC transitions to send analytics events.
- [ ] Build a Supabase view aggregating signups, mode switches, cart abandonment, completed orders.

**Acceptance** — A weekly dashboard answers: DAU, signup→first-order conversion, seller onboarding completion rate.

**Estimate.** 1 week.

### C.6 — Backend / DB scalability prep

**Tasks**

- [ ] Audit Supabase indexes — every query path in `SupabaseXRepository` should have a supporting index. Use `mcp__supabase__execute_sql` to `EXPLAIN ANALYZE` the hot queries.
- [ ] Move heavy reads (catalog list, product detail) behind a `pg_cache` extension or `cached_network_image`-style edge caching.
- [ ] Set up Supabase paid plan with proper backups, point-in-time recovery, and a staging branch.
- [ ] Decide on a CDN for product images (Supabase Storage + CloudFront / BunnyCDN).

**Acceptance** — Synthetic load test (1000 concurrent users, 5 min) produces no rate-limit errors and stays under 200ms p95 for catalog list.

**Estimate.** 1 week.

### C.7 — Post-launch ops

**Tasks**

- [ ] On-call rotation (even if solo: define an SLA for severity-1 incidents).
- [ ] Status page (statuspage.io or a simple static one).
- [ ] Customer support intake (Telegram bot, email, or in-app feedback form already drafted in profile).
- [ ] Translation feedback loop — let users report missing translations (track in Supabase `translation_feedback` table).
- [ ] Quarterly accessibility audit (TalkBack/VoiceOver, font scaling, contrast).

**Estimate.** Ongoing.

---

## Phase Summary Cheat Sheet

| Phase | Window | Top deliverable | Definition of done |
| --- | --- | --- | --- |
| **A.1–A.6** | Weeks 1–3 | Secrets rotated, error pipeline live, mocks gated | Decompiled APK reveals no secrets; Sentry receives test errors; prod-mode seller flows do not show mock data |
| **B.1** | Months 1–2 | Seller backend complete | End-to-end real order flow possible |
| **B.2** | Months 1–2 | Customer payment | Sandbox card buys an order |
| **B.3–B.4** | Months 1–2 | Seller migrates to GoRouter; 6 god-screens split | All screens <600 lines |
| **B.5–B.6** | Months 2–3 | 30 % test coverage; refactor backbone done | CI green on every PR |
| **B.7–B.8** | Month 3 | Performance + localization parity | p99 home frame <16 ms; no untranslated keys |
| **C.1–C.2** | Month 4 | CI/CD + flavors live | Tagged release auto-builds; testers install Dev + Prod side-by-side |
| **C.3** | Month 5 | Store submission | Both stores accept internal track |
| **C.4–C.5** | Month 5 | Shorebird + analytics | OTA copy patch demonstrably ships |
| **C.6–C.7** | Month 6 | Scale + ops | First real customers without panic |

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Payment partner integration takes >4 weeks | Medium | Delays launch | Start partner application in Week 1 of phase B |
| Yandex MapKit policy change | Low | Need to swap to Google Maps SDK | Map facade (REFACTORING.md §5.3) keeps swap localised |
| Play Store rejection due to mode switch confusion | Medium | 1–2 weeks delay | Include explicit review note + demo accounts |
| Solo developer burnout | High | Indefinite delay | Front-load the refactors (sections A, B.5, B.6) so future feature work is cheap |
| Supabase quota / cost spike at launch | Low | Service degradation | C.6 load test + Supabase paid plan before launch |

---

## What's *Not* in this Roadmap (Deliberate)

These appeared in older planning docs but are deferred until after V1 ships:

- Web admin dashboard.
- Multi-vendor / inventory management at scale.
- AB-testing framework (revisit after analytics are running in C.5).
- AI / ML recommendations (defer until there is real engagement data).
- Multi-currency / cross-border (Uzbekistan-focused MVP first).

Document them in `docs/legacy/` as parked items so they aren't forgotten — just not in the critical path.

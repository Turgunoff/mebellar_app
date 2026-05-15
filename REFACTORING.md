# REFACTORING.md — Areas of Improvement & Clean Code

> Companion to [`BUGS_AND_ISSUES.md`](./BUGS_AND_ISSUES.md). The bugs doc lists problems; this doc proposes concrete refactors keyed to **SOLID**, **DRY**, **KISS**, and **scalability** principles. Each section is structured so a maintainer can take it as-is into a sprint backlog.

---

## 1. Top Refactoring Targets (by File Size)

These are the six screens currently over 1000 lines. Each is a god-object — a mix of UI, state, validation, persistence calls, and side effects. Splitting them is the single highest-leverage refactor in the project.

### 1.1 `seller/features/products/screens/product_form_screen.dart` (1879 lines)

**Symptoms**

- Six wizard steps (basic info, images, dimensions, pricing, inventory, review) all inlined in one `StatefulWidget`.
- Image-picker / image-compress side effects mixed with form-validation logic.
- A single `BlocBuilder<ProductFormBloc, ProductFormState>` rebuilds the entire form on every keystroke.

**Refactor**

```
lib/seller/features/products/screens/product_form/
├── product_form_screen.dart           # shell: PageView, stepper, AppBar (~150 lines)
├── steps/
│   ├── basic_info_step.dart
│   ├── images_step.dart
│   ├── dimensions_step.dart
│   ├── pricing_step.dart
│   ├── inventory_step.dart
│   └── review_step.dart
├── widgets/
│   ├── product_form_stepper.dart      # the top progress indicator
│   ├── images_grid.dart
│   └── price_input_field.dart
└── controllers/
    └── product_form_image_controller.dart  # ImagePicker + FlutterImageCompress glue
```

- Push `BlocBuilder` **inside** each step so the unaffected steps don't rebuild.
- Move image-picker / compress code to a controller class — pure Dart, testable.

**SOLID alignment**

- **SRP** — each step owns one concern.
- **OCP** — adding a 7th step doesn't touch the shell or sibling steps.
- **ISP** — the controller exposes only `pickAndCompress(...)`, not the full `ImagePicker` surface.

### 1.2 `customer/features/profile/screens/profile_screen.dart` (1612 lines)

**Symptoms** — A tabbed profile with sections (account, addresses, language, mode switcher, support, sign-out) all hand-built in one widget.

**Refactor** — Extract per-section widgets into `profile/widgets/sections/*.dart`. The screen itself becomes a thin scrollable column listing section widgets.

### 1.3 `seller/features/settings/screens/shop_settings_screen.dart` (1269 lines)

**Symptoms** — Working hours, delivery services, shop info, payment methods all in one place.

**Refactor**

- Promote each settings section to its own screen (`/seller/settings/hours`, `/seller/settings/delivery`, …).
- Keep the parent screen as a navigation menu (40–60 lines).

This also unblocks the seller routing migration (see §3.2).

### 1.4 `seller/features/products/screens/seller_product_detail_screen.dart` (1201 lines)

**Symptoms** — Detail viewer + inline edit + delete confirmation + analytics block all in one.

**Refactor** — Split into read-only `SellerProductDetailScreen` (~300 lines) and modal `SellerProductEditSheet` reusing the form widgets from §1.1.

### 1.5 `seller/features/orders/screens/order_details_screen.dart` (1086 lines)

**Symptoms** — Status timeline, action buttons (accept / reject / mark shipped), customer info, item list, refund flow all together.

**Refactor**

- Extract `OrderTimelineWidget`, `OrderActionBar`, `OrderItemsList`, `RefundSheet`.
- Move action logic to `SellerOrderDetailBloc` events (already exists).

### 1.6 `auth/auth_bottom_sheet.dart` (1069 lines)

**Symptoms** — Login + register + reset + verify-email + mode-aware redirects in one sheet.

**Refactor**

- Each variant becomes its own widget under `lib/auth/sheets/`.
- A small `AuthSheetController` decides which variant to mount based on `AuthSheetMode`.

---

## 2. SOLID Violations Worth Addressing

### 2.1 Single Responsibility — `service_locator.dart` is doing too much

`lib/core/di/service_locator.dart` is ~556 lines and contains:

- Hive box opening.
- Supabase client init.
- Dio client construction.
- Repository selection logic (mock vs live, Supabase vs Dio).
- BLoC instantiation.
- Mode-scope orchestration.

**Refactor** — Split into:

```
lib/core/di/
├── service_locator.dart           # entry points: initRootScope, initModeScope
├── modules/
│   ├── infrastructure_module.dart # Hive, Supabase, Dio, SecureStorage
│   ├── auth_module.dart           # AuthCubit, AuthRepository
│   ├── notifications_module.dart  # PushService, NotificationHandler, NotificationsCubit
│   ├── catalog_module.dart        # Product, Category, Banner, Shop repos
│   ├── cart_module.dart           # Cart + Favorites (hybrid)
│   ├── orders_module.dart         # Orders, Addresses, Regions
│   └── seller_module.dart         # All seller-specific repos
└── repository_resolver.dart       # mock-vs-live decision tree (one place)
```

Each module exposes a `register()` function called from `initRootScope`. The mock-vs-live logic moves to `RepositoryResolver` so the rules live in one auditable place.

### 2.2 Open–Closed — Mock vs live selection scatters across `service_locator`

The `if (AppConfig.useMocks && supabase != null) … else if (supabase != null) … else MockX()` pattern repeats for ~12 repositories. A `RepositoryResolver` (above) with a `T resolve<T>({required T mock, required T? live})` method eliminates the duplication.

### 2.3 Liskov — `HybridCartRepository` quietly diverges from `CartRepository`

`HybridCartRepository` adds a side-effectful auth listener that the interface does not advertise. A caller depending on the interface cannot tell that the repository will mutate state in response to auth changes.

**Refactor** — Expose the auth-sync behaviour as a separate `CartSyncService` that the DI container wires explicitly. Keep the repository implementation interchangeable.

### 2.4 Interface Segregation — Wide repository interfaces

`ProductRepository` exposes `list()`, `getBySlug()`, `search()` together. The home screen only needs `list()`; the detail screen only needs `getBySlug()`. A mock that doesn't yet implement search has to throw `UnimplementedError`.

**Refactor** — Split into `ProductListSource`, `ProductDetailSource`, `ProductSearchSource`. Combine concrete classes can implement multiple.

### 2.5 Dependency Inversion — direct `Supabase.instance.client` calls in repositories

Some Supabase repositories grab `Supabase.instance.client` directly instead of accepting a `SupabaseClient` in the constructor. That makes them untestable without a real Supabase singleton.

**Refactor** — Always inject `SupabaseClient` through the constructor; `service_locator.dart` already has `sl<SupabaseClient>()`.

---

## 3. DRY & Scalability Improvements

### 3.1 Centralise `_minSplashDuration`, `_crossfadeDuration`, and other timing constants

Currently:

- `_ModeRouter` defines its own splash + crossfade timings.
- BLoC tests use `Duration(milliseconds: 400)` as a magic wait.
- Several `Future.delayed(Duration(seconds: 1))` calls live inside screens.

**Refactor** — Add `lib/core/theme/durations.dart`:

```dart
class AppDurations {
  const AppDurations._();
  static const splashMinimum = Duration(milliseconds: 1400);
  static const modeSwitchCrossfade = Duration(milliseconds: 360);
  static const networkRetry = Duration(milliseconds: 400);
  static const debounceSearch = Duration(milliseconds: 300);
}
```

Same idea for `lib/core/theme/sizing.dart` (paddings, radii, breakpoints) and `lib/core/theme/animations.dart` (curves).

### 3.2 Migrate seller mode to `go_router`

Once seller settings are split (§1.3), migrating to `go_router` becomes feasible:

```
/seller/
  ├── dashboard
  ├── products/
  │   ├── (list)
  │   ├── :id            (detail)
  │   ├── :id/edit
  │   └── new
  ├── orders/
  │   ├── (list)
  │   └── :id
  ├── settings/
  │   ├── hours
  │   ├── delivery
  │   ├── info
  │   └── payments
  ├── tariff
  ├── analytics
  ├── reviews
  ├── verification
  └── profile
```

**Wins** — Unified deep-linking, one router observer, easier auth-guards (replace ad-hoc `AppModeCubit` demotion with `redirect:`).

### 3.3 Adopt the `Result<T, Failure>` / sealed-class error pattern across repositories

`lib/core/error/failure.dart` already defines a sealed `Failure` hierarchy. Most repositories don't use it — they either throw raw exceptions or swallow them silently (see `BUGS_AND_ISSUES.md` §4.2).

**Refactor** — All repository methods return `Future<Result<T, Failure>>`:

```dart
sealed class Result<T, E> {}
class Ok<T, E> extends Result<T, E> { final T value; const Ok(this.value); }
class Err<T, E> extends Result<T, E> { final E error; const Err(this.error); }
```

BLoCs pattern-match:

```dart
switch (await repo.list()) {
  case Ok(:final value): emit(state.copyWith(items: value, status: Ready));
  case Err(:final error): emit(state.copyWith(failure: error, status: Failure));
}
```

This is mechanical refactor work, but it eliminates the silent-default-on-error anti-pattern.

### 3.4 Strongly-typed Hive settings access

Create `lib/core/storage/app_settings.dart`:

```dart
class AppSettings {
  AppSettings(this._box);
  final Box _box;

  AppMode get appMode => AppMode.fromName(_box.get('app_mode') as String?);
  set appMode(AppMode value) => _box.put('app_mode', value.name);

  bool get tutorialSeen => _box.get('tutorial_seen', defaultValue: false) as bool;
  set tutorialSeen(bool value) => _box.put('tutorial_seen', value);

  Locale get locale => Locale(_box.get('locale', defaultValue: 'uz') as String);
  set locale(Locale value) => _box.put('locale', value.languageCode);

  ThemeBrightness get brightness => ... ;
}
```

Register it as `sl<AppSettings>()`. Outlaw raw `_box.get('app_mode')` calls via a `forbid_settings_string_keys` custom lint or a grep CI step.

### 3.5 Extract a `RealtimeService` to standardise Supabase channel lifecycle

Today `OrderTrackingService`, `NewOrdersListener`, and `SupabaseNotificationsRepository` each duplicate Supabase channel boilerplate (`supabase.channel('orders:user_id=eq.x')`, `.on(...)`, `.subscribe()`, `removeChannel(...)`).

**Refactor** — A typed wrapper:

```dart
class RealtimeService {
  RealtimeService(this._supabase);
  final SupabaseClient _supabase;

  StreamSubscription<Map<String, dynamic>> subscribeTable({
    required String table,
    required Map<String, String> filter,
    required void Function(Map<String, dynamic>) onInsert,
    void Function(Map<String, dynamic>)? onUpdate,
    void Function(Map<String, dynamic>)? onDelete,
  }) { ... }
}
```

Services consume this wrapper. Easier to test (mock `RealtimeService`), easier to audit which tables are subscribed to (one grep), and the dispose contract is enforced.

### 3.6 Promote `lib/shared/widgets/` into a `core_ui` package (eventual)

Long term, `EmptyState`, `ShimmerPlaceholder`, `ProductCardSkeleton`, `QuantityStepper`, etc. can graduate into a sibling package (`packages/core_ui/`) so they could be reused by a future web admin or admin tool. Not urgent.

### 3.7 Replace `MaterialApp` with `MaterialApp.router` on seller side

Seller mode currently uses `MaterialApp` + `onGenerateRoute`. After 3.2, switch to `MaterialApp.router` so navigation state is testable and survives hot-reload more cleanly.

---

## 4. Performance Refactors

### 4.1 Lift `BlocBuilder` granularity

In the screens listed in §1, wrap only the smallest sub-tree that depends on the state with `BlocBuilder`. Wrap the rest with `BlocSelector` or move state-independent UI outside.

**Pattern**

```dart
BlocBuilder<CartBloc, CartState>(
  buildWhen: (prev, next) => prev.totalUnits != next.totalUnits,
  builder: (context, state) => Text('${state.totalUnits}'),
);
```

### 4.2 Adopt `bloc_concurrency` event transformers

Add `bloc_concurrency: ^0.3.0` to `dev_dependencies → dependencies` (it's a tiny runtime package).

```dart
on<SearchQueryChanged>(_onSearchQueryChanged,
    transformer: restartable());
on<HomeRequested>(_onHomeRequested,
    transformer: droppable());
```

This deduplicates rapid events and cancels stale fetches.

### 4.3 Defer mock data load with deferred imports

When `AppConfig.useMocks == false`, the mock graph is dead weight. Use Dart's deferred loading:

```dart
import 'package:woody_app/shared/mock/mock_data.dart' deferred as mocks;

if (AppConfig.useMocks) {
  await mocks.loadLibrary();
  // …register mock repositories…
}
```

### 4.4 Image cache sizing

In each `CachedNetworkImage` builder, set:

```dart
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: (mediaQuery.size.width * mediaQuery.devicePixelRatio).toInt(),
  fadeInDuration: AppDurations.modeSwitchCrossfade,
);
```

Capping `memCacheWidth` to the rendered width is the single biggest win for low-RAM Android.

---

## 5. Testability Refactors

These are prerequisites for the test plan in `ROADMAP.md` §B.5.

### 5.1 Inject `Clock` instead of using `DateTime.now()`

Several services compare timestamps (e.g. pending route staleness in `NotificationHandler`). Replace `DateTime.now()` with an injectable `Clock` (from package `clock` — official Dart team) so tests can fast-forward time.

### 5.2 Wrap `FirebaseMessaging.instance` behind `FcmFacade`

`PushService` calls `FirebaseMessaging.instance.subscribeToTopic(...)` directly. Introduce a `FcmFacade` interface with a mock implementation for unit tests; production binds to a `FirebaseFcmFacade` that wraps the real instance.

### 5.3 Same treatment for `Geolocator`, `ImagePicker`, `Connectivity`

All currently used directly. Wrap each behind a thin facade so:

- Tests don't need platform channels.
- Future native swaps (e.g. Yandex SDK → Google Maps Platform) are localised.

### 5.4 Contract tests for repositories

For each `*Repository` interface, write a contract test suite parameterised over the implementations:

```dart
void productRepositoryContract(ProductRepository Function() build) {
  group('ProductRepository contract', () {
    test('list returns at least one product', () async {
      final repo = build();
      final page = await repo.list();
      expect(page.items, isNotEmpty);
    });
    // …
  });
}

void main() {
  productRepositoryContract(() => MockProductRepository());
  productRepositoryContract(() => SupabaseProductRepository(_fakeClient));
}
```

This is how you prevent mock drift (see `BUGS_AND_ISSUES.md` §5.3).

---

## 6. Clean Code Hygiene Pass

Items that are individually small but add up to noticeable quality lift.

### 6.1 Adopt named constructors over positional `bool`s

Several BLoC events take positional `bool`s (`HomeRequested(true)` to force a refresh). Use named parameters with defaults:

```dart
class HomeRequested extends HomeEvent {
  const HomeRequested({this.forceRefresh = false});
  final bool forceRefresh;
}
```

### 6.2 Standardise `const` constructors

Run `dart fix --apply` after enabling `prefer_const_constructors` and `prefer_const_literals_to_create_immutables`. Watch the analyser quiet down by ~100 warnings.

### 6.3 Collapse copy-pasted Dio interceptors

`core/network/api_client.dart` constructs Dio with auth headers, error transformer, talker logging. If a second Dio (or a separate retrying Dio) is added later, factor out:

```dart
List<Interceptor> buildDefaultInterceptors({required SupabaseClient supabase});
```

### 6.4 Lints to enable now

Append to `analysis_options.yaml`:

```yaml
analyzer:
  errors:
    invalid_annotation_target: ignore
linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - avoid_redundant_argument_values
    - prefer_const_constructors
    - prefer_const_literals_to_create_immutables
    - prefer_final_locals
    - unawaited_futures
    - use_super_parameters
```

(Avoid enabling `public_member_api_docs` — it adds noise without value for an app codebase.)

### 6.5 Rename `auth_flow.dart` for clarity

`lib/auth/auth_flow.dart` is the orchestration glue between Supabase auth events and post-login navigation. The name "flow" is ambiguous. Rename to `auth_orchestrator.dart` or `auth_navigation_handler.dart`.

### 6.6 Replace the legacy `docs/` content

Either rewrite `docs/00-overview.md`, `docs/02-dual-entry-mode-switching.md`, `docs/05-notifications-deep-linking.md`, `docs/12-localization.md`, `docs/13-security.md` against the current code, or move the whole folder to `docs/legacy/` with a top-level note that it predates the current stack.

---

## 7. Scalability — Preparing for Growth

These changes make the architecture safer to evolve once V1 ships.

### 7.1 Feature flags via Supabase

Store flags in a `feature_flags` table (`key`, `value`, `audience`). Add a `FeatureFlags` root-scoped singleton that reads at boot + on Realtime updates. Lets you:

- Hide seller features that still use mocks (see §2.4 of bugs doc).
- Roll new features out to 10 % of users for AB tests.
- Kill-switch a broken screen without a hotfix release.

### 7.2 Modularisation milestone

Once the codebase hits 80–100k LOC, split into a multi-package monorepo:

```
mebellar_app/
├── apps/
│   └── mobile/              # current lib/main.dart
├── packages/
│   ├── core_infra/          # DI, network, storage, i18n, notifications
│   ├── core_ui/             # widgets, theme
│   ├── domain/              # models + repository interfaces
│   ├── data_supabase/       # Supabase implementations
│   ├── data_remote/         # Dio implementations
│   ├── customer/            # customer features
│   └── seller/              # seller features
└── pubspec.yaml             # melos workspace
```

Use `melos` (or `dart workspaces` in Dart 3.6+) to manage the workspace. Wins: parallel CI, clean dependency graph, optional code-push of feature packages.

### 7.3 Backend API contract via OpenAPI / `openapi_generator`

The Supabase Edge Functions called via Dio have no schema discipline. Once the count grows past ~5 endpoints, ship an OpenAPI spec and generate Dart client code (`openapi_generator`). Eliminates a whole class of "I added a field on the backend and the app silently drops it" bugs.

### 7.4 Strict null-safety + branded types

Domain ids are passed as `String` everywhere — easy to mix up `productId` and `userId`. Adopt branded types:

```dart
extension type ProductId(String value) {}
extension type UserId(String value) {}
extension type OrderId(String value) {}
```

(Dart 3+'s extension types compile to zero overhead.)

### 7.5 Adopt `bloc_concurrency` + `equatable` discipline as repo-wide policy

Codify these via:

- A `CONTRIBUTING.md` rule.
- A `dart_code_metrics` config flagging Blocs without event transformers and `Equatable` types missing fields from `props`.

---

## 8. Recommended Refactor Order

Order is chosen to minimise rework: foundations first, then size reductions, then ergonomics.

1. **Sec / hygiene** — `.gitignore`, env rotation, hardcoded defaults (1–2 days). *Already a CRITICAL in `BUGS_AND_ISSUES.md` §1.*
2. **`service_locator` modularisation + `RepositoryResolver`** (§2.1) — 2 days.
3. **`Result<T, Failure>` repository pattern** (§3.3) — 2 days base + 1 day per repo.
4. **`AppSettings` typed Hive wrapper** (§3.4) — half a day.
5. **`RealtimeService`** (§3.5) — 1 day.
6. **`AppDurations` + `AppSizing` constants** (§3.1) — half a day.
7. **Split top-6 screens** (§1.1–1.6) — 2–4 days each, prioritise `product_form_screen.dart`.
8. **Seller routing migration to `go_router`** (§3.2) — 3–5 days (after settings split).
9. **Image cache sizing + bloc_concurrency** (§4.1, 4.2, 4.4) — 1 day.
10. **Test plumbing** (§5.1–5.4) — ongoing, see `ROADMAP.md` §B.5.

This sequence ships value at every step — no "big rewrite" required.

# 02 — Dual Entry Point va Mode Switching

> Asl §5.2, §5.3, §19.2. Bu Flutter app'ning **eng kritik arxitektura qismi**. Bu yerdagi memory leak yechimini noto'g'ri tushunish — production'da silent crash'larga olib keladi.

## 1. Asosiy g'oya

**Bitta loyiha** ichida **ikkita MaterialApp**:

- `CustomerApp()` — xaridor uchun
- `SellerApp()` — sotuvchi uchun

`main()` foydalanuvchining tanlangan rejimini Hive'dan o'qib, mos `MaterialApp`'ni ochadi. Mode switch `flutter_phoenix` orqali widget tree'ni qayta tug'adi.

---

## 2. Memory leak muammosi va yechimi

> **Muhim arxitektura qarori:** `GetIt.I.reset()` ni to'g'ridan-to'g'ri chaqirish **memory leak**'ga olib keladi — Hive box'lar, Supabase realtime channellari, Dio HTTP client'lar, OneSignal listenerlar va boshqa singleton'larning ochiq resource'lari yopilmasdan qoladi.
>
> **Yechim:** **GetIt scope'lardan foydalanish** va **har singletonga `dispose` callback registration**.

### 2.1 Ikki qatlamli DI

| Scope | Mazmuni | Mode switch'da | Dispose |
|-------|---------|----------------|---------|
| **Root scope** (boot vaqtida) | `Hive` boxes, `SupabaseClient`, `Dio`, `AuthRepository`, `TokenManager`, `OneSignal`, `EasyLocalization` | **Saqlanadi** (qayta yaratilmaydi) | App butunlay yopilganda |
| **Mode scope** (`customer` yoki `seller`) | BLoC'lar, mode-specific repositories, realtime subscriptions, mode-specific cache | **Tashlanadi va qayta yaratiladi** | `popScope()` da dispose chaqiriladi |

---

## 3. `lib/main.dart` to'liq misoli

```dart
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';

enum AppMode { customer, seller }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ROOT scope — bir marta yaratiladi, app yopilguncha turadi
  await _initRootScope();
  await _checkInitialNotification();  // cold start uchun (05-notifications-deep-linking.md)

  final mode = _getInitialMode();
  await _initModeScope(mode);

  runApp(
    Phoenix(
      child: switch (mode) {
        AppMode.seller => const SellerApp(),
        AppMode.customer => const CustomerApp(),
      },
    ),
  );
}

Future<void> _initRootScope() async {
  await Hive.initFlutter();
  final settingsBox = await Hive.openBox('settings');
  final cacheBox = await Hive.openBox('cache');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Root scope registration — dispose callback bilan
  GetIt.I.registerSingleton<Box>(settingsBox, instanceName: 'settings');
  GetIt.I.registerSingleton<Box>(cacheBox, instanceName: 'cache');
  GetIt.I.registerSingleton<SupabaseClient>(Supabase.instance.client);

  GetIt.I.registerLazySingleton<Dio>(
    () => buildDioClient(),
    dispose: (dio) => dio.close(force: true), // HTTP connection pool yopiladi
  );

  GetIt.I.registerLazySingleton<AuthRepository>(
    () => AuthRepository(GetIt.I<SupabaseClient>(), GetIt.I<Dio>()),
    dispose: (repo) async => repo.dispose(),
  );

  // OneSignal, Sentry, Firebase — global, mode-agnostic
  await _initOneSignal();
}

Future<void> _initModeScope(AppMode mode) async {
  // Yangi scope ochiladi — popScope() chaqirilganda hammasi dispose bo'ladi
  GetIt.I.pushNewScope(scopeName: mode.name);

  switch (mode) {
    case AppMode.customer:
      _registerCustomerDependencies();
    case AppMode.seller:
      _registerSellerDependencies();
  }
}

void _registerCustomerDependencies() {
  // Customer BLoC'lar
  GetIt.I.registerFactory(() => HomeBloc(GetIt.I<ProductRepository>()));
  GetIt.I.registerFactory(() => CartBloc(GetIt.I<CartRepository>()));
  // ...

  // Customer-specific real-time subscriptions
  GetIt.I.registerLazySingleton<OrderTrackingService>(
    () => OrderTrackingService(GetIt.I<SupabaseClient>()),
    dispose: (svc) async => svc.dispose(), // RealtimeChannel yopiladi
  );
}

void _registerSellerDependencies() {
  GetIt.I.registerFactory(() => DashboardBloc(GetIt.I<ShopRepository>()));
  GetIt.I.registerFactory(() => SellerProductsBloc(GetIt.I<ProductRepository>()));
  // ...

  // Seller real-time order broadcaster
  GetIt.I.registerLazySingleton<NewOrdersListener>(
    () => NewOrdersListener(GetIt.I<SupabaseClient>()),
    dispose: (listener) async => listener.dispose(),
  );
}

AppMode _getInitialMode() {
  final box = GetIt.I<Box>(instanceName: 'settings');
  final saved = box.get('app_mode') as String?;
  return saved == 'seller' ? AppMode.seller : AppMode.customer;
}
```

---

## 4. `switchAppMode` — XAVFSIZ va leak-free

```dart
Future<void> switchAppMode(BuildContext context, AppMode newMode) async {
  // 1. Mode'ni saqla
  await GetIt.I<Box>(instanceName: 'settings').put('app_mode', newMode.name);

  // 2. Aktiv scope'ni dispose qilamiz — bu har registered singleton'ning
  //    dispose callback'ini avtomatik chaqiradi (RealtimeChannel.unsubscribe(),
  //    StreamSubscription.cancel(), va h.k.)
  await GetIt.I.popScope();

  // 3. Yangi mode scope'ini ochamiz
  await _initModeScope(newMode);

  // 4. Phoenix bilan widget tree'ni qayta tug'amiz
  //    DIQQAT: rebirth FAQAT widget tree'ni yangilaydi, GetIt'ga ta'sir qilmaydi.
  //    Shuning uchun popScope() oldindan chaqirilgani muhim.
  if (context.mounted) {
    Phoenix.rebirth(context);
  }
}
```

> **Eslatma — flutter_phoenix nuance:** `Phoenix.rebirth()` widget tree'ni qayta yaratadi, lekin `main()` qayta chaqirilmaydi. Shuning uchun GetIt scope manipulyatsiyasi `rebirth`'dan **oldin** qilinishi shart. Aks holda yangi widget tree eski mode dependencies bilan qoshiladi.

---

## 5. Dispose pattern misollari

```dart
// Realtime subscription — Supabase channel
class OrderTrackingService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  OrderTrackingService(this._client);

  void watchOrders(String userId) {
    _channel = _client
      .channel('orders:user:$userId')
      .onPostgresChanges(...)
      .subscribe();
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe(); // CRITICAL: WebSocket yopiladi
    _channel = null;
  }
}

// BLoC — close() metodini override qiling
class CartBloc extends Bloc<CartEvent, CartState> {
  StreamSubscription? _cartSubscription;

  @override
  Future<void> close() async {
    await _cartSubscription?.cancel();
    return super.close();
  }
}
```

**Hive box'lar:** Root scope'da turadi va **mode switch'da yopilmaydi**. Sababi: cache, favorites, cart, settings — bularning hammasi mode'dan mustaqil. Faqat user logout bo'lganda tozalanadi (alohida flow).

---

## 6. App widget'lari (CustomerApp, SellerApp)

```dart
// lib/customer/customer_app.dart
class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = customerRouter;

    // Boot bo'lgandan keyin frame'da pending route'ni consume qilamiz
    // Tafsilot: 05-notifications-deep-linking.md
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingRoute();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => GetIt.I<AuthBloc>()),
        BlocProvider(create: (_) => GetIt.I<HomeBloc>()),
        BlocProvider(create: (_) => GetIt.I<CartBloc>()),
        // ... customer-specific blocs
      ],
      child: MaterialApp.router(
        title: 'Mebellar',
        theme: customerLightTheme,
        darkTheme: customerDarkTheme,
        routerConfig: _router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}

// lib/seller/seller_app.dart — exactly the same structure but for seller
```

---

## 7. Mode switch UX

### 7.1 Customer mode'dan seller bo'lish

```
1. Profile screen → "Sotuvchi bo'lish" tugma
2. Onboarding bottom sheet:
   "Mebellar'da sotishni boshlang. 5 daqiqada ro'yxatdan o'ting."
   [Boshlash]
3. Multi-step form (still in customer app):
   - Yuridik holat (Jismoniy / YaTT / MChJ)
   - Do'kon nomi va tavsifi
   - Bog'lanish ma'lumotlari
   - Manzil
4. Verification choice:
   - "Passport rasmini yuborish" (manual, 1-3 kun)
   - "MyID orqali" (V2 da, hozir disabled)
5. Backend: POST /api/v1/seller/onboarding
   - seller_profile yaratiladi (status='pending')
   - shop yaratiladi (visibility='draft', tariff='free')
6. Success screen: "Tasdiqlash uchun yuborildi. 1-3 ish kuni ichida javob beramiz."
   [Sotuvchi rejimiga o'tish]
7. switchAppMode(context, AppMode.seller) → app restart
8. SellerApp ochiladi → Dashboard "Tasdiqlanmoqda" status bilan
```

### 7.2 Seller'dan customer'ga qaytish

```
Seller app → Profile → "Xaridor rejimi" tugma → switchAppMode → restart → Customer app
```

### 7.3 Birinchi marta login bo'lganda mode tanlash

Login screen common (`auth/login_screen.dart`). Login bo'lgandan keyin:

- Agar foydalanuvchining `seller_profile` yo'q → `app_mode = customer` (default)
- Agar bor va approved → ostidagi screen "Qaysi rejimga kirasiz?" deb so'raydi (faqat birinchi safar):
  - 🛍️ Xaridor sifatida
  - 🏪 Sotuvchi sifatida

```dart
// Login muvaffaqiyatli bo'lgandan keyin
final me = await authRepository.fetchMe();  // GET /api/v1/me
if (me.sellerProfile?.verificationStatus == 'approved') {
  // Mode chooser ko'rsatish
  final chosen = await Navigator.push(context, ModeChooserRoute());
  await GetIt.I<Box>(instanceName: 'settings').put('app_mode', chosen.name);
} else {
  // Default customer
  await GetIt.I<Box>(instanceName: 'settings').put('app_mode', 'customer');
}
Phoenix.rebirth(context);
```

---

## 8. Test pattern

```dart
// test/main_test.dart
testWidgets('switchAppMode disposes RealtimeChannel', (tester) async {
  // Setup root scope
  await _initRootScope();
  await _initModeScope(AppMode.customer);

  final orderTracking = GetIt.I<OrderTrackingService>();
  orderTracking.watchOrders('user-id');

  expect(orderTracking._channel, isNotNull);

  // Switch
  await GetIt.I.popScope();

  // Channel should be disposed
  expect(orderTracking._channel, isNull);
});
```

---

## 9. Keyingi qadam

→ [03-deferred-components.md](./03-deferred-components.md) — bundle size va deferred imports

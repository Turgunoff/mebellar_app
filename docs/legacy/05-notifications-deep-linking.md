# 05 — Notification handling va Cross-mode Deep Linking

> Asl §5.6, §19.6. **Eng nozik UX masalasi.** Bu pattern'ni 100% follow qilish va edge case'larni to'liq test qilish kerak.

## 1. Muammo

Push notification kelganda foydalanuvchi har xil holatda bo'lishi mumkin:

- App ochiq, fonda, yoki butunlay yopiq
- Va eng murakkabi: **notifikatsiya boshqa AppMode'ga tegishli bo'lishi mumkin**

Misol: foydalanuvchi seller rejimida ishlayapti, lekin xaridor sifatida bergan buyurtmasi yetkazib berildi — push kelyapti, lekin u customer mode'da ochilishi kerak.

---

## 2. Notification payload formati

OneSignal va Supabase tomonidan yuborilgan har push notification quyidagi `data` payload bilan keladi:

```json
{
  "type": "order_delivered",
  "target_mode": "customer",
  "deep_link": "/orders/abc-123",
  "entity_id": "abc-123",
  "title": "Buyurtma yetkazildi",
  "body": "Sizning #ORD-2026-00123 buyurtmangiz yetkazib berildi"
}
```

Eng kritik maydon — `target_mode` (`customer` | `seller`). Backend notification yaratishda **albatta** to'g'ri to'ldiradi. Tafsilot: `backend/docs/01-database-schema.md §2.8`.

---

## 3. Cross-mode deep linking pattern

> **Qoida:** agar push notification target_mode hozirgi AppMode bilan farq qilsa — to'g'ridan-to'g'ri navigate **MUMKIN EMAS**, chunki yangi mode'ning router'i hali yuklanmagan.
>
> **Yechim:** **pending route** Hive'ga saqlanadi, mode switch bo'ladi, yangi app boot bo'lganda pending route'ga avtomatik navigate qilinadi.

### 3.1 NotificationHandler

```dart
// lib/core/notifications/notification_handler.dart
class NotificationHandler {
  final Box _settingsBox = GetIt.I<Box>(instanceName: 'settings');

  /// Push notification tap qilinganda chaqiriladi
  Future<void> handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final targetModeStr = payload['target_mode'] as String? ?? 'customer';
    final deepLink = payload['deep_link'] as String?;

    if (deepLink == null) return;

    final targetMode = AppMode.values.byName(targetModeStr);
    final currentMode = AppMode.values.byName(
      _settingsBox.get('app_mode') as String? ?? 'customer',
    );

    if (targetMode == currentMode) {
      // Mode mos — to'g'ridan-to'g'ri navigate
      _navigateToRoute(context, deepLink);
    } else {
      // Mode farqli — pending route saqlash + app restart
      await _settingsBox.put('pending_route', deepLink);
      await _settingsBox.put('pending_route_created_at',
        DateTime.now().millisecondsSinceEpoch);

      await switchAppMode(context, targetMode);
      // switchAppMode ichida Phoenix.rebirth() chaqiriladi
      // Yangi mode boot bo'lganda pending route consume qilinadi
    }
  }

  void _navigateToRoute(BuildContext context, String route) {
    final router = GoRouter.of(context);
    router.push(route);
  }
}
```

### 3.2 Pending route consumption

Yangi mode'ning `App` widget'i `initState`'da pending route'ni tekshiradi:

```dart
// lib/customer/customer_app.dart (va seller_app.dart bir xil pattern)
class _CustomerAppState extends State<CustomerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = customerRouter;

    // Boot bo'lgandan keyin frame'da pending route'ni consume qilamiz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingRoute();
    });
  }

  void _consumePendingRoute() {
    final box = GetIt.I<Box>(instanceName: 'settings');
    final pendingRoute = box.get('pending_route') as String?;
    final createdAt = box.get('pending_route_created_at') as int?;

    if (pendingRoute == null || createdAt == null) return;

    // STALE check: 5 daqiqadan eski pending route'ni e'tiborga olmaymiz
    // (foydalanuvchi notification'ni tap qilib, keyin app'ni yopib qo'ygan bo'lishi mumkin)
    final age = DateTime.now().millisecondsSinceEpoch - createdAt;
    if (age > 5 * 60 * 1000) {
      box.delete('pending_route');
      box.delete('pending_route_created_at');
      return;
    }

    // Tozalash (idempotency: ikki marta consume qilinmasin)
    box.delete('pending_route');
    box.delete('pending_route_created_at');

    _router.push(pendingRoute);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [...],
      child: MaterialApp.router(
        routerConfig: _router,
        // ...
      ),
    );
  }
}
```

---

## 4. App holatlari va flow

| Holat | Notif tap qilinganda flow |
|-------|---------------------------|
| **App ochiq, mode mos** | OneSignal foreground handler → `handleNotificationTap` → router.push(deep_link) |
| **App ochiq, mode farqli** | pending_route saqlanadi → switchAppMode → Phoenix.rebirth → yangi App boot → consumePendingRoute → router.push |
| **App fonda, mode mos** | OS notif tap → app foreground'ga keladi → notification opened handler → router.push |
| **App fonda, mode farqli** | OS notif tap → app foreground → handler → pending_route → mode switch → consume |
| **App butunlay yopiq, mode mos** | OS notif tap → app cold start → main() chaqiriladi → OneSignal initial notification tekshiriladi → handler ishlaydi va to'g'ridan-to'g'ri navigate |
| **App butunlay yopiq, mode farqli** | OS notif tap → cold start → main() → OneSignal initial notification → pending_route saqlanadi → main() to'g'ri mode bilan boot qiladi → App boot'da consume |

---

## 5. Cold start handling

App butunlay yopiq holatda notification'dan ochilganda:

```dart
// lib/main.dart — _initRootScope ichida yoki keyin
Future<void> _checkInitialNotification() async {
  final OSNotificationOpenedResult? initial =
    await OneSignal.shared.getInitialNotification();

  if (initial == null) return;

  final payload = initial.notification.additionalData;
  if (payload == null) return;

  final targetMode = payload['target_mode'] as String? ?? 'customer';
  final deepLink = payload['deep_link'] as String?;

  if (deepLink == null) return;

  // Hive'ga pending_route saqlaymiz, asosiy mode bilan boot qilamiz
  final box = GetIt.I<Box>(instanceName: 'settings');
  await box.put('pending_route', deepLink);
  await box.put('pending_route_created_at',
    DateTime.now().millisecondsSinceEpoch);

  // Saqlangan mode'ni target_mode bilan almashtirib qo'yamiz
  // shunda main() to'g'ri AppMode bilan boot qiladi
  await box.put('app_mode', targetMode);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initRootScope();
  await _checkInitialNotification(); // ← cold start uchun

  final mode = _getInitialMode(); // endi to'g'ri mode'ni qaytaradi
  await _initModeScope(mode);

  runApp(Phoenix(child: switch (mode) {
    AppMode.seller => const SellerApp(),
    AppMode.customer => const CustomerApp(),
  }));
}
```

---

## 6. Edge case'lar

- **Mode farqli notification, lekin user logged out:** pending_route saqlanmaydi, login screen ko'rsatiladi. Login bo'lgandan keyin pending_route consume qilinmaydi (xavfsizlik — boshqa user pending route'ni "merosga" olishi mumkin).
- **Notification target_mode = seller, lekin user seller emas:** Backend tomonida bunday notification yuborilmasligi kerak. Defensive check: `consumePendingRoute`'da agar joriy mode `seller` bo'lsa, lekin `seller_profile` yo'q bo'lsa — pending'ni tashlab, customer'ga redirect.
- **Pending route 5 daqiqadan eski:** stale, e'tiborga olinmaydi.
- **Bir vaqtning o'zida bir nechta pending notification:** so'nggisi yutadi (oxirgi yozilgan pending_route saqlanadi). MVP uchun yetadi.

### Defensive check

```dart
void _consumePendingRoute() {
  final box = GetIt.I<Box>(instanceName: 'settings');
  final pendingRoute = box.get('pending_route') as String?;
  // ... (yuqorida ko'rsatilgan stale check)

  // Defensive: agar seller mode'da, lekin user seller emas — redirect customer'ga
  if (this is SellerApp && /* user.sellerProfile == null */) {
    box.delete('pending_route');
    box.delete('pending_route_created_at');
    switchAppMode(context, AppMode.customer);
    return;
  }

  _router.push(pendingRoute);
}
```

---

## 7. OneSignal SDK setup

```dart
// lib/core/notifications/onesignal_setup.dart
Future<void> _initOneSignal() async {
  OneSignal.initialize(AppConfig.oneSignalAppId);
  OneSignal.Notifications.requestPermission(true);

  // Foreground handler
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    // Show in-app banner OR pass to OS notification UI
    event.preventDefault();
    event.notification.display();
  });

  // Tap handler (foreground + background)
  OneSignal.Notifications.addClickListener((event) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final payload = event.notification.additionalData ?? {};
    NotificationHandler().handleNotificationTap(context, payload);
  });
}
```

---

## 8. Notification badge va in-app

`/api/v1/notifications` endpoint'idan unread count olish va bottom navigation'da badge ko'rsatish. Realtime channel `public:notifications:user_id=eq.<uuid>` bilan badge'ni live update qilish (V1.5 optional).

---

## 9. Test pattern

```dart
// test/notification_handler_test.dart
test('handles cross-mode notification with pending route', () async {
  // Setup: customer mode
  await box.put('app_mode', 'customer');

  final handler = NotificationHandler();
  await handler.handleNotificationTap(mockContext, {
    'target_mode': 'seller',
    'deep_link': '/dashboard',
  });

  // Verify pending route saved
  expect(box.get('pending_route'), '/dashboard');
  expect(box.get('app_mode'), 'seller');
});

test('stale pending route ignored', () async {
  // 6 daqiqa oldin yaratilgan pending route
  await box.put('pending_route', '/orders/abc');
  await box.put('pending_route_created_at',
    DateTime.now().subtract(const Duration(minutes: 6)).millisecondsSinceEpoch);

  // _consumePendingRoute chaqiriladi
  // Pending route deleted, navigate qilinmaydi
});
```

---

## 10. Keyingi qadam

→ [06-auth-flow.md](./06-auth-flow.md) — Supabase Auth signup/login flow

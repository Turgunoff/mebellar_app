# 04 — Realtime integratsiyasi (Supabase Postgres CDC)

> Asl §5.5.

## 1. Foydalanish hollari

| Channel | Mode | Maqsad |
|---------|------|--------|
| `public:orders:user_id=eq.<uuid>` | Customer | Foydalanuvchi orderlari status update'lari |
| `public:orders:shop_id=eq.<uuid>` | Seller | Yangi order INSERT + status update'lari |
| `public:notifications:user_id=eq.<uuid>` | Both | Notification badge update (V2 optional) |

Mobile to'g'ridan-to'g'ri Supabase'ga ulanadi (backend orqali emas) — Postgres CDC orqali eventlar.

## 2. Implementatsiya

### 2.1 Customer order tracking

```dart
// lib/customer/features/orders/data/order_tracking_service.dart
class OrderTrackingService {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  final _controller = StreamController<Order>.broadcast();

  OrderTrackingService(this._supabase);

  Stream<Order> watchUserOrders(String userId) {
    _channel = _supabase
      .channel('public:orders:user_id=eq.$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          final order = Order.fromJson(payload.newRecord);
          _controller.add(order);
        },
      )
      .subscribe();

    return _controller.stream;
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
    await _controller.close();
  }
}
```

### 2.2 Seller new orders

```dart
// lib/seller/features/orders/data/realtime_orders_source.dart
class RealtimeOrdersSource {
  final SupabaseClient _supabase;
  StreamSubscription? _subscription;
  final _newOrders = StreamController<Order>.broadcast();

  RealtimeOrdersSource(this._supabase);

  Stream<Order> watchNewOrders(String shopId) {
    _subscription = _supabase
      .channel('public:orders:shop_id=eq.$shopId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'shop_id',
          value: shopId,
        ),
        callback: (payload) {
          final order = Order.fromJson(payload.newRecord);
          _newOrders.add(order);
        },
      )
      .subscribe()
      .onError((err) {
        // Reconnect logic kerak bo'lsa shu yerga
      });

    return _newOrders.stream;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _newOrders.close();
  }
}
```

## 3. DI registratsiyasi (mode scope)

Realtime servislar **mode scope**'da registered (root emas) — mode switch'da dispose bo'ladi:

```dart
// _registerCustomerDependencies() ichida
GetIt.I.registerLazySingleton<OrderTrackingService>(
  () => OrderTrackingService(GetIt.I<SupabaseClient>()),
  dispose: (svc) async => svc.dispose(),
);

// _registerSellerDependencies() ichida
GetIt.I.registerLazySingleton<RealtimeOrdersSource>(
  () => RealtimeOrdersSource(GetIt.I<SupabaseClient>()),
  dispose: (src) async => src.dispose(),
);
```

> SupabaseClient — root scope'da. Realtime channel — mode scope'da. Mode switch'da channel yopiladi, client saqlanadi.

## 4. UI integratsiyasi (BLoC misoli)

```dart
// lib/seller/features/orders/bloc/orders_bloc.dart
class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final RealtimeOrdersSource _realtime;
  final OrderRepository _repo;
  StreamSubscription<Order>? _newOrderSub;

  OrdersBloc(this._realtime, this._repo) : super(OrdersInitial()) {
    on<OrdersStarted>(_onStarted);
    on<NewOrderReceived>(_onNewOrder);
  }

  Future<void> _onStarted(OrdersStarted e, Emitter<OrdersState> emit) async {
    // Initial fetch
    final orders = await _repo.fetchSellerOrders();
    emit(OrdersLoaded(orders));

    // Subscribe to new orders
    _newOrderSub = _realtime.watchNewOrders(e.shopId).listen(
      (order) => add(NewOrderReceived(order)),
    );
  }

  void _onNewOrder(NewOrderReceived e, Emitter<OrdersState> emit) {
    if (state is OrdersLoaded) {
      final current = (state as OrdersLoaded).orders;
      emit(OrdersLoaded([e.order, ...current]));

      // Vibration / sound notification
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Future<void> close() async {
    await _newOrderSub?.cancel();
    return super.close();
  }
}
```

## 5. RLS va xavfsizlik

Backend `orders` jadvalida RLS policy'lar:

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users see own orders"
  ON orders FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "sellers see own shop orders"
  ON orders FOR SELECT
  USING (
    shop_id IN (
      SELECT s.id FROM shops s
      JOIN seller_profiles sp ON sp.id = s.seller_profile_id
      WHERE sp.user_id = auth.uid()
    )
  );
```

Bu RLS Supabase Realtime'ga ham ta'sir qiladi — user faqat o'z eventlarini oladi. Filter URL'da qattiq belgilangan, lekin RLS defense-in-depth.

## 6. Reconnection va offline

Supabase SDK avtomatik reconnect qiladi (exponential backoff). Mobile o'z tomonidan qo'shimcha logic kerak emas, lekin UI'da connection status ko'rsatish foydali:

```dart
_supabase.realtime.onSystemEvents((event) {
  if (event.event == 'system' && event.payload['status'] == 'CHANNEL_ERROR') {
    // Show toast: "Realtime ulanish uzildi, qayta urinilmoqda..."
  }
});
```

V1 MVP'da offline indicator yo'q ham ishlaydi.

## 7. Performance eslatmalari

- **Filter har doim qo'ying** — global subscription og'ir
- **Bitta user uchun bir nechta channel** — har feature alohida channel qo'shadi (lekin barchasi bitta WebSocket ostida)
- **Channel limiti** Supabase planlarida bor (free 200/project, pro 500). User uchun 1-3 channel yetarli.

## 8. Keyingi qadam

→ [05-notifications-deep-linking.md](./05-notifications-deep-linking.md) — push notification va cross-mode deep linking

import '../models/app_notification.dart';

/// Initial notification feed shown when the user first opens the screen.
/// Mix of customer + seller items so the unread badge logic has something
/// to filter — and the in-app list isn't empty during demos.
class MockNotificationsData {
  const MockNotificationsData._();

  static List<AppNotification> seed() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'notif-1',
        kind: NotificationKind.orderUpdated,
        title: 'Buyurtma yo\'lda',
        body: 'M-2026-001 raqamli buyurtma kuriyer tomonidan olib ketildi',
        route: '/orders/ord-1001',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'notif-2',
        kind: NotificationKind.orderPlaced,
        title: 'Yangi buyurtma',
        body: 'Mebel House do\'koningizga yangi buyurtma keldi',
        route: '/orders/ord-1003',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      AppNotification(
        id: 'notif-3',
        kind: NotificationKind.tariffApproved,
        title: 'Tarif faollashtirildi',
        body: 'Pro tarifingiz endi amal qiladi — 30 kun davomida',
        route: '/seller/tariff',
        createdAt: now.subtract(const Duration(days: 1)),
        read: true,
      ),
      AppNotification(
        id: 'notif-4',
        kind: NotificationKind.promo,
        title: 'Yangi yil chegirmasi 30%',
        body: 'Divan va kreslolarga 30% chegirma — Mebel House',
        route: '/catalog?category=sofas',
        createdAt: now.subtract(const Duration(days: 2)),
        read: true,
      ),
      AppNotification(
        id: 'notif-5',
        kind: NotificationKind.verificationApproved,
        title: 'Sotuvchi tasdiqlandi',
        body: 'Hujjatlaringiz tasdiqlandi — endi mahsulot qo\'sha olasiz',
        route: '/seller/verification',
        createdAt: now.subtract(const Duration(days: 3)),
        read: true,
      ),
    ];
  }

  /// Templates the simulator picks from when injecting fresh notifications.
  static AppNotification newOrderTemplate() => AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        kind: NotificationKind.orderPlaced,
        title: 'Yangi buyurtma',
        body: 'Sizning do\'koningizga yangi buyurtma keldi',
        route: '/orders/ord-1001',
        createdAt: DateTime.now(),
      );

  static AppNotification orderDeliveredTemplate() => AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        kind: NotificationKind.orderUpdated,
        title: 'Buyurtma yetkazildi',
        body: 'M-2026-002 raqamli buyurtma manzilingizga yetkazib berildi',
        route: '/orders/ord-1002',
        createdAt: DateTime.now(),
      );

  static AppNotification productApprovedTemplate() => AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        kind: NotificationKind.productApproved,
        title: 'Mahsulot tasdiqlandi',
        body: 'Yangi mahsulotingiz katalogda paydo bo\'ldi',
        route: '/seller/products',
        createdAt: DateTime.now(),
      );

  static AppNotification promoTemplate() => AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        kind: NotificationKind.promo,
        title: 'Bolalar mebeli — eng yaxshi narxlar',
        body: '20% chegirma — bugun-erta',
        route: '/catalog?category=kids',
        createdAt: DateTime.now(),
      );
}

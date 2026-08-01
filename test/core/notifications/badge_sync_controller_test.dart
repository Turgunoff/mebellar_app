import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/config/app_mode.dart';
import 'package:woody_app/core/auth/app_mode_cubit.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/notifications/app_badge_service.dart';
import 'package:woody_app/core/notifications/badge_sync_controller.dart';
import 'package:woody_app/shared/models/chat.dart';
import 'package:woody_app/shared/repositories/chat_repository.dart';
import 'package:woody_app/shared/repositories/notifications_data_source.dart';

class _MockBadge extends Mock implements AppBadgeService {}

class _MockChatRepo extends Mock implements ChatRepository {}

class _MockNotifSource extends Mock implements NotificationDataSource {}

class _MockModeCubit extends Mock implements AppModeCubit {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

Chat _chat({int customerUnread = 0, int sellerUnread = 0}) => Chat(
  id: 'c$customerUnread$sellerUnread',
  orderId: 'o',
  customerId: 'cu',
  shopId: 'sh',
  customerUnreadCount: customerUnread,
  sellerUnreadCount: sellerUnread,
  createdAt: DateTime.utc(2026, 5, 22),
);

void main() {
  // BadgeSyncController.start() registers a WidgetsBindingObserver.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBadge badge;
  late _MockChatRepo chats;
  late _MockNotifSource notifs;
  late _MockModeCubit mode;
  late StreamController<List<Chat>> chatStream;
  late StreamController<AppMode> modeStream;
  late BadgeSyncController controller;

  setUp(() {
    badge = _MockBadge();
    chats = _MockChatRepo();
    notifs = _MockNotifSource();
    mode = _MockModeCubit();
    chatStream = StreamController<List<Chat>>.broadcast();
    modeStream = StreamController<AppMode>.broadcast();

    when(() => badge.setCount(any())).thenAnswer((_) async {});
    when(() => badge.clear()).thenAnswer((_) async {});
    when(() => notifs.unreadCount()).thenAnswer((_) async => 0);
    when(() => chats.myChatsStream()).thenAnswer((_) => chatStream.stream);
    when(() => mode.state).thenReturn(AppMode.customer);
    when(() => mode.stream).thenAnswer((_) => modeStream.stream);

    controller = BadgeSyncController(
      badge: badge,
      notifications: notifs,
      chats: chats,
      mode: mode,
    );
  });

  tearDown(() async {
    await controller.dispose();
    await chatStream.close();
    await modeStream.close();
  });

  // Stream listeners fire on a microtask — flush before asserting.
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('seeds the badge from the backend unread count on start', () async {
    when(() => notifs.unreadCount()).thenAnswer((_) async => 3);

    controller.start();
    await tick();

    verify(() => badge.setCount(3)).called(1);
  });

  test('adds chat unread (customer viewer) to the notification unread', () async {
    when(() => notifs.unreadCount()).thenAnswer((_) async => 1);
    controller.start();
    await tick();

    chatStream.add([
      _chat(customerUnread: 2, sellerUnread: 9),
      _chat(customerUnread: 3),
    ]);
    await tick();

    // 1 notif + (2 + 3) customer-side chat unread; the seller column is ignored.
    verify(() => badge.setCount(6)).called(1);
  });

  test('refreshNotificationUnread re-fetches from the backend', () async {
    when(() => notifs.unreadCount()).thenAnswer((_) async => 4);

    await controller.refreshNotificationUnread();

    verify(() => badge.setCount(4)).called(1);
  });

  test(
    'counts the seller column after a mode flip, reusing the chat rows',
    () async {
      when(() => notifs.unreadCount()).thenAnswer((_) async => 0);
      controller.start();
      await tick();

      chatStream.add([_chat(customerUnread: 2, sellerUnread: 9)]);
      await tick();
      verify(() => badge.setCount(2)).called(1); // customer viewer

      when(() => mode.state).thenReturn(AppMode.seller);
      modeStream.add(AppMode.seller);
      await tick();

      // Same chat row, no re-fetch — only the unreadFor() column changes.
      verify(() => badge.setCount(9)).called(1); // seller viewer
    },
  );

  test(
    'refreshNotificationUnread falls back to zero when the fetch fails',
    () async {
      when(() => notifs.unreadCount()).thenThrow(Exception('401'));

      await controller.refreshNotificationUnread();

      verify(() => badge.setCount(0)).called(1);
    },
  );

  test('refreshNotificationUnread skips the network when signed out', () async {
    when(() => notifs.unreadCount()).thenAnswer((_) async => 9);

    final storage = _MockSecureStorage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    final guestTokens = TokenStore(storage);
    await guestTokens.read();

    final guest = BadgeSyncController(
      badge: badge,
      notifications: notifs,
      chats: chats,
      mode: mode,
      tokens: guestTokens,
    );
    addTearDown(guest.dispose);

    await guest.refreshNotificationUnread();

    verifyNever(() => notifs.unreadCount());
    verify(() => badge.setCount(0)).called(1);
  });

  test('clearOnLogout clears the launcher badge and cached tallies', () async {
    when(() => notifs.unreadCount()).thenAnswer((_) async => 5);
    controller.start();
    await tick();

    await controller.clearOnLogout();

    verify(() => badge.clear()).called(1);
    chatStream.add([_chat(customerUnread: 3)]);
    await tick();
    verify(() => badge.setCount(3)).called(1);
  });

  test(
    'start is idempotent — a second call does not double-subscribe',
    () async {
      when(() => notifs.unreadCount()).thenAnswer((_) async => 2);

      controller.start();
      controller.start();
      await tick();

      verify(() => notifs.unreadCount()).called(1);
      verify(() => badge.setCount(2)).called(1);
    },
  );
}

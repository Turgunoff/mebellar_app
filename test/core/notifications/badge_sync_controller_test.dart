import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/config/app_mode.dart';
import 'package:woody_app/core/auth/app_mode_cubit.dart';
import 'package:woody_app/core/notifications/app_badge_service.dart';
import 'package:woody_app/core/notifications/badge_sync_controller.dart';
import 'package:woody_app/shared/models/chat.dart';
import 'package:woody_app/shared/repositories/chat_repository.dart';
import 'package:woody_app/shared/repositories/notifications_repository.dart';

class _MockBadge extends Mock implements AppBadgeService {}

class _MockChatRepo extends Mock implements ChatRepository {}

class _MockNotifRepo extends Mock implements NotificationsRepository {}

class _MockModeCubit extends Mock implements AppModeCubit {}

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
  late _MockNotifRepo notifs;
  late _MockModeCubit mode;
  late StreamController<List<Chat>> chatStream;
  late StreamController<int> notifStream;
  late StreamController<AppMode> modeStream;
  late BadgeSyncController controller;

  setUp(() {
    badge = _MockBadge();
    chats = _MockChatRepo();
    notifs = _MockNotifRepo();
    mode = _MockModeCubit();
    chatStream = StreamController<List<Chat>>.broadcast();
    notifStream = StreamController<int>.broadcast();
    modeStream = StreamController<AppMode>.broadcast();

    when(() => badge.setCount(any())).thenAnswer((_) async {});
    when(() => notifs.unreadCount()).thenReturn(0);
    when(() => notifs.watchUnread()).thenAnswer((_) => notifStream.stream);
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
    await notifStream.close();
    await modeStream.close();
  });

  // Stream listeners fire on a microtask — flush before asserting.
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('seeds the badge with the current notification unread on start',
      () async {
    when(() => notifs.unreadCount()).thenReturn(3);

    controller.start();

    verify(() => badge.setCount(3)).called(1);
  });

  test('adds chat unread (customer viewer) to the notification unread',
      () async {
    when(() => notifs.unreadCount()).thenReturn(1);
    controller.start();

    chatStream.add([
      _chat(customerUnread: 2, sellerUnread: 9),
      _chat(customerUnread: 3),
    ]);
    await tick();

    // 1 notif + (2 + 3) customer-side chat unread; the seller column is ignored.
    verify(() => badge.setCount(6)).called(1);
  });

  test('recomputes when the notification unread changes', () async {
    controller.start();

    notifStream.add(4);
    await tick();

    verify(() => badge.setCount(4)).called(1);
  });

  test('counts the seller column after a mode flip, reusing the chat rows',
      () async {
    controller.start();
    chatStream.add([_chat(customerUnread: 2, sellerUnread: 9)]);
    await tick();
    verify(() => badge.setCount(2)).called(1); // customer viewer

    when(() => mode.state).thenReturn(AppMode.seller);
    modeStream.add(AppMode.seller);
    await tick();

    // Same chat row, no re-fetch — only the unreadFor() column changes.
    verify(() => badge.setCount(9)).called(1); // seller viewer
  });

  test('start is idempotent — a second call does not double-subscribe',
      () async {
    when(() => notifs.unreadCount()).thenReturn(2);

    controller.start();
    controller.start();

    // Only the first start seeds + subscribes; the second is a no-op.
    verify(() => badge.setCount(2)).called(1);
    verify(() => notifs.watchUnread()).called(1);
  });
}

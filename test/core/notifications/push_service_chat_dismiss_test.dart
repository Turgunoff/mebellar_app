import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/notifications/notification_handler.dart';
import 'package:woody_app/core/notifications/push_service.dart';
import 'package:woody_app/core/platform/messaging_facade.dart';

class _MockMessaging extends Mock implements MessagingFacade {}

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chatNotificationId', () {
    test('is deterministic, non-negative, and within Android\'s id range', () {
      final id = PushService.chatNotificationId('chat-1');
      expect(id, PushService.chatNotificationId('chat-1'));
      expect(id, inInclusiveRange(0, 0x7FFFFFFF));
    });

    test('maps distinct chats to distinct ids', () {
      expect(
        PushService.chatNotificationId('chat-1'),
        isNot(PushService.chatNotificationId('chat-2')),
      );
    });
  });

  test('chatNotificationTag matches the backend android_tag contract', () {
    // Backend: ChatRepository._push_chat_message → android_tag=f"chat:{chat_id}".
    expect(PushService.chatNotificationTag('xyz'), 'chat:xyz');
  });

  group('dismissChatNotifications', () {
    late _MockLocalNotifications local;
    late PushService service;

    setUp(() {
      local = _MockLocalNotifications();
      when(
        () => local.cancel(any(), tag: any(named: 'tag')),
      ).thenAnswer((_) async {});
      when(
        () => local.getActiveNotifications(),
      ).thenAnswer((_) async => <ActiveNotification>[]);
      service = PushService(
        messaging: _MockMessaging(),
        localNotifications: local,
        notificationHandler: NotificationHandler(_MockBox()),
      );
    });

    test('cancels the chat\'s deterministic id under the per-chat tag', () async {
      const chatId = 'abc-123';
      await service.dismissChatNotifications(chatId);
      verify(
        () => local.cancel(
          PushService.chatNotificationId(chatId),
          tag: 'chat:$chatId',
        ),
      ).called(1);
    });

    test('no-ops on an empty chat id', () async {
      await service.dismissChatNotifications('');
      verifyNever(() => local.cancel(any(), tag: any(named: 'tag')));
    });
  });
}

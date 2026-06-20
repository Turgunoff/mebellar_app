import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/notifications/active_support_tracker.dart';
import 'package:woody_app/customer/features/support/bloc/support_unread_cubit.dart';
import 'package:woody_app/customer/features/support/models/support_message.dart';
import 'package:woody_app/customer/features/support/repository/support_chat_repository.dart';

SupportMessage _adminMsg(String id) => SupportMessage(
  id: id,
  chatId: 'mock-support-1',
  senderId: 'admin',
  senderType: SupportSenderType.admin,
  messageType: SupportMessageType.text,
  textContent: 'reply $id',
  createdAt: DateTime.utc(2026, 6, 20, 10, 0),
);

/// Flush pending microtasks/timers so the cubit's async seed + stream listeners
/// settle before we assert.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  // SupportUnreadCubit registers a WidgetsBindingObserver for resume re-seeds.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupportChatRepository repo;

  setUp(() {
    repo = MockSupportChatRepository();
    ActiveSupportTracker.instance.leave();
  });

  tearDown(() => ActiveSupportTracker.instance.leave());

  test('seeds the badge from the server unread count', () async {
    repo.unreadCount = 3;
    final cubit = SupportUnreadCubit(repo);
    await _settle();
    expect(cubit.state, 3);
    await cubit.close();
  });

  test('a WS admin reply increments the badge when not viewing', () async {
    final cubit = SupportUnreadCubit(repo);
    await _settle();
    repo.emitAdminMessage(_adminMsg('a'));
    await _settle();
    expect(cubit.state, 1);
    repo.emitAdminMessage(_adminMsg('b'));
    await _settle();
    expect(cubit.state, 2);
    await cubit.close();
  });

  test('a WS admin reply does NOT increment while viewing the thread', () async {
    ActiveSupportTracker.instance.enter();
    final cubit = SupportUnreadCubit(repo);
    await _settle();
    repo.emitAdminMessage(_adminMsg('a'));
    await _settle();
    expect(cubit.state, 0);
    await cubit.close();
  });

  test('the read signal resets the badge to zero', () async {
    final cubit = SupportUnreadCubit(repo);
    await _settle();
    repo.emitAdminMessage(_adminMsg('a'));
    await _settle();
    expect(cubit.state, 1);
    await repo.markRead(); // nudges localReadStream
    await _settle();
    expect(cubit.state, 0);
    await cubit.close();
  });

  test('refresh re-pulls the authoritative count (e.g. after a push)', () async {
    final cubit = SupportUnreadCubit(repo);
    await _settle();
    expect(cubit.state, 0);
    // Replies that arrived as a push while backgrounded — only a re-seed sees them.
    repo.unreadCount = 5;
    await cubit.refresh();
    expect(cubit.state, 5);
    await cubit.close();
  });
}

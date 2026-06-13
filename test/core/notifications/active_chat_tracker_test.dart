import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/notifications/active_chat_tracker.dart';

void main() {
  final tracker = ActiveChatTracker.instance;

  tearDown(() {
    // Reset shared singleton state between tests.
    final active = tracker.activeChatId;
    if (active != null) tracker.leave(active);
  });

  test('isViewing tracks enter/leave', () {
    expect(tracker.isViewing('chat-1'), isFalse);
    tracker.enter('chat-1');
    expect(tracker.isViewing('chat-1'), isTrue);
    expect(tracker.isViewing('chat-2'), isFalse);
    tracker.leave('chat-1');
    expect(tracker.isViewing('chat-1'), isFalse);
  });

  test('leave only clears when the id still matches (A→B ordering safe)', () {
    tracker.enter('chat-A');
    tracker.enter('chat-B'); // navigated forward before A disposed
    tracker.leave('chat-A'); // late dispose of A must not wipe B
    expect(tracker.isViewing('chat-B'), isTrue);
  });

  test('isViewing is false for null / empty', () {
    tracker.enter('chat-1');
    expect(tracker.isViewing(null), isFalse);
    expect(tracker.isViewing(''), isFalse);
  });
}

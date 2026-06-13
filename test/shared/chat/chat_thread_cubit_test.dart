import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/shared/chat/bloc/chat_thread_cubit.dart';
import 'package:woody_app/shared/models/chat.dart';
import 'package:woody_app/shared/models/chat_message.dart';
import 'package:woody_app/shared/repositories/chat_repository.dart';

class _MockRepo extends Mock implements ChatRepository {}

Chat _chat(String id, {String orderId = 'order-1'}) => Chat(
  id: id,
  orderId: orderId,
  customerId: 'cust-1',
  shopId: 'shop-1',
  createdAt: DateTime.utc(2026, 5, 22),
);

ChatMessage _msg(String id, {ChatSenderRole role = ChatSenderRole.customer}) =>
    ChatMessage(
      id: id,
      chatId: 'chat-1',
      senderId: 'sender',
      senderRole: role,
      body: 'hello $id',
      createdAt: DateTime.utc(2026, 5, 22, 10, 0),
    );

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(ChatSenderRole.customer);
  });

  setUp(() => repo = _MockRepo());

  /// Default stubs for a clean `load()` — overridable per test.
  void stubLoad({
    Stream<ChatMessage>? messages,
    Stream<void>? orders,
    Chat? chat,
    List<ChatMessage> initial = const [],
  }) {
    when(
      () => repo.getChat(any()),
    ).thenAnswer((_) async => chat ?? _chat('chat-1'));
    when(() => repo.listMessages(any())).thenAnswer((_) async => initial);
    when(
      () => repo.messagesStream(any()),
    ).thenAnswer((_) => messages ?? const Stream.empty());
    when(
      () => repo.orderEventsStream(any()),
    ).thenAnswer((_) => orders ?? const Stream.empty());
    when(() => repo.markAsRead(any())).thenAnswer((_) async {});
  }

  ChatThreadCubit build() => ChatThreadCubit(
    repo: repo,
    chatId: 'chat-1',
    viewer: ChatSenderRole.customer,
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'load emits [loading, ready] and subscribes to realtime',
    build: () {
      stubLoad(initial: [_msg('a')]);
      return build();
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<ChatThreadState>().having(
        (s) => s.status,
        'status',
        ChatThreadStatus.loading,
      ),
      isA<ChatThreadState>()
          .having((s) => s.status, 'status', ChatThreadStatus.ready)
          .having((s) => s.messages.length, 'messages', 1)
          .having((s) => s.chat?.id, 'chat.id', 'chat-1'),
    ],
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'sendText inserts an optimistic "sending" bubble, then reconciles to sent',
    build: () {
      stubLoad();
      when(
        () => repo.sendText(
          chatId: any(named: 'chatId'),
          body: any(named: 'body'),
          as: any(named: 'as'),
        ),
      ).thenAnswer((_) async => _msg('server-1'));
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.sendText('hi');
    },
    skip: 2, // skip the initial load loading/ready emissions
    expect: () => [
      // Optimistic insert — instant bubble, sending status, clock glyph.
      isA<ChatThreadState>()
          .having((s) => s.sending, 'sending', true)
          .having((s) => s.messages.length, 'messages', 1)
          .having(
            (s) => s.messages.single.status,
            'status',
            ChatMessageStatus.sending,
          ),
      // Reconciled — placeholder swapped for the server row, status sent.
      isA<ChatThreadState>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.messages.length, 'messages', 1)
          .having((s) => s.messages.single.id, 'id', 'server-1')
          .having(
            (s) => s.messages.single.status,
            'status',
            ChatMessageStatus.sent,
          ),
    ],
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'sendText flips the optimistic bubble to failed when the send throws',
    build: () {
      stubLoad();
      when(
        () => repo.sendText(
          chatId: any(named: 'chatId'),
          body: any(named: 'body'),
          as: any(named: 'as'),
        ),
      ).thenThrow(Exception('boom'));
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.sendText('hi');
    },
    skip: 3, // load loading/ready + optimistic insert
    expect: () => [
      isA<ChatThreadState>()
          .having((s) => s.sending, 'sending', false)
          .having(
            (s) => s.messages.single.status,
            'status',
            ChatMessageStatus.failed,
          )
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'realtime insert from the other side appends and triggers markAsRead',
    build: () {
      final ctrl = StreamController<ChatMessage>();
      stubLoad(messages: ctrl.stream);
      Future.delayed(
        const Duration(milliseconds: 10),
        () => ctrl.add(_msg('seller-1', role: ChatSenderRole.seller)),
      );
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    verify: (cubit) {
      expect(cubit.state.messages.length, 1);
      expect(cubit.state.messages.first.senderRole, ChatSenderRole.seller);
      verify(() => repo.markAsRead('chat-1')).called(greaterThanOrEqualTo(1));
    },
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'a realtime echo with an existing id does NOT duplicate',
    build: () {
      final ctrl = StreamController<ChatMessage>();
      stubLoad(messages: ctrl.stream, initial: [_msg('dup')]);
      Future.delayed(
        const Duration(milliseconds: 10),
        () => ctrl.add(_msg('dup')), // same id already present
      );
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    verify: (cubit) => expect(cubit.state.messages.length, 1),
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'an order realtime event re-fetches the chat so the banner can refresh',
    build: () {
      final orders = StreamController<void>();
      stubLoad(orders: orders.stream, chat: _chat('chat-1'));
      // After load, the seller moves the order forward → notification fires.
      Future.delayed(const Duration(milliseconds: 10), () => orders.add(null));
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    verify: (_) {
      // getChat: once in load + once on the order event.
      verify(() => repo.getChat('chat-1')).called(greaterThanOrEqualTo(2));
    },
  );
}

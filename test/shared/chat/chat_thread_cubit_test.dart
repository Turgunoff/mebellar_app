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

Chat _chat(String id) => Chat(
      id: id,
      orderId: 'order-1',
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

  ChatThreadCubit build() => ChatThreadCubit(
        repo: repo,
        chatId: 'chat-1',
        viewer: ChatSenderRole.customer,
      );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'load emits [loading, ready] and subscribes to realtime',
    build: () {
      when(() => repo.getChat(any())).thenAnswer((_) async => _chat('chat-1'));
      when(() => repo.listMessages(any())).thenAnswer((_) async => [_msg('a')]);
      when(() => repo.messagesStream(any()))
          .thenAnswer((_) => const Stream.empty());
      when(() => repo.markAsRead(any())).thenAnswer((_) async {});
      return build();
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<ChatThreadState>()
          .having((s) => s.status, 'status', ChatThreadStatus.loading),
      isA<ChatThreadState>()
          .having((s) => s.status, 'status', ChatThreadStatus.ready)
          .having((s) => s.messages.length, 'messages', 1)
          .having((s) => s.chat?.id, 'chat.id', 'chat-1'),
    ],
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'sendText appends an optimistic-like message and flips sending off',
    build: () {
      when(() => repo.getChat(any())).thenAnswer((_) async => _chat('chat-1'));
      when(() => repo.listMessages(any())).thenAnswer((_) async => const []);
      when(() => repo.messagesStream(any()))
          .thenAnswer((_) => const Stream.empty());
      when(() => repo.markAsRead(any())).thenAnswer((_) async {});
      when(() => repo.sendText(
            chatId: any(named: 'chatId'),
            body: any(named: 'body'),
            as: any(named: 'as'),
          )).thenAnswer((_) async => _msg('new'));
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.sendText('hi');
    },
    skip: 2, // skip the initial load loading/ready emissions
    expect: () => [
      isA<ChatThreadState>().having((s) => s.sending, 'sending', true),
      isA<ChatThreadState>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.messages.length, 'messages', 1),
    ],
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'realtime insert from the other side appends and triggers markAsRead',
    build: () {
      final ctrl = StreamController<ChatMessage>();
      when(() => repo.getChat(any())).thenAnswer((_) async => _chat('chat-1'));
      when(() => repo.listMessages(any())).thenAnswer((_) async => const []);
      when(() => repo.messagesStream(any())).thenAnswer((_) => ctrl.stream);
      when(() => repo.markAsRead(any())).thenAnswer((_) async {});

      // Push a seller message after load completes.
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
}

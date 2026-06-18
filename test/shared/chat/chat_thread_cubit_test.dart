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

  // CHAT-01: the bootstrap FutureBuilder already resolved the chat row, so
  // passing it into load() must skip the (list-scanning) getChat refetch.
  blocTest<ChatThreadCubit, ChatThreadState>(
    'load(initialChat) reuses the passed row and skips the getChat refetch',
    build: () {
      stubLoad(initial: [_msg('a')]);
      return build();
    },
    act: (cubit) => cubit.load(_chat('chat-1')),
    expect: () => [
      isA<ChatThreadState>().having(
        (s) => s.status,
        'status',
        ChatThreadStatus.loading,
      ),
      isA<ChatThreadState>()
          .having((s) => s.status, 'status', ChatThreadStatus.ready)
          .having((s) => s.chat?.id, 'chat.id', 'chat-1')
          .having((s) => s.messages.length, 'messages', 1),
    ],
    verify: (_) {
      verifyNever(() => repo.getChat(any()));
      verify(() => repo.listMessages('chat-1')).called(1);
    },
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

  // Regression: the WS echo of a message we just sent carries a fresh server
  // id (not our optimistic local id). If it lands before the POST resolves it
  // must REPLACE the optimistic bubble, not append a twin.
  late StreamController<ChatMessage> echoCtrl;
  late Completer<ChatMessage> sendCompleter;
  blocTest<ChatThreadCubit, ChatThreadState>(
    'realtime echo of my own send replaces the optimistic bubble, no duplicate',
    build: () {
      echoCtrl = StreamController<ChatMessage>();
      sendCompleter = Completer<ChatMessage>();
      stubLoad(messages: echoCtrl.stream);
      when(
        () => repo.sendText(
          chatId: any(named: 'chatId'),
          body: any(named: 'body'),
          as: any(named: 'as'),
        ),
      ).thenAnswer((_) => sendCompleter.future);
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      final sending = cubit.sendText('hi'); // optimistic placeholder inserted
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Sanity: exactly the optimistic "sending" bubble is on screen.
      expect(cubit.state.messages.length, 1);
      expect(cubit.state.messages.single.status, ChatMessageStatus.sending);

      final serverRow = ChatMessage(
        id: 'server-echo',
        chatId: 'chat-1',
        senderId: 'me',
        senderRole: ChatSenderRole.customer,
        body: 'hi',
        createdAt: DateTime.utc(2026, 5, 22, 10, 5),
      );
      echoCtrl.add(serverRow); // echo lands BEFORE the POST resolves
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // The assertion that actually guards fix #4: in the transient window
      // after the echo but before the POST resolves there must still be
      // exactly ONE message (the placeholder was replaced in place). A naive
      // append would hold TWO here — the duplicate the user reported — even
      // though _reconcile would later collapse it back to one.
      expect(cubit.state.messages.length, 1);
      expect(cubit.state.messages.single.id, 'server-echo');
      expect(cubit.state.messages.single.status, ChatMessageStatus.sent);

      sendCompleter.complete(serverRow); // POST returns the same row
      await sending;
    },
    verify: (cubit) {
      expect(cubit.state.messages.length, 1);
      expect(cubit.state.messages.single.id, 'server-echo');
      expect(cubit.state.messages.single.status, ChatMessageStatus.sent);
      expect(cubit.state.sending, isFalse);
    },
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

  // Resume-from-background path: a message the WS missed (delivered only as a
  // push) is surfaced by the refetch, and markAsRead re-zeroes the server
  // unread to match the tray notification the screen just cleared.
  blocTest<ChatThreadCubit, ChatThreadState>(
    'refresh swaps in the server messages and re-asserts markAsRead',
    build: () {
      stubLoad(initial: [_msg('a')]);
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      when(
        () => repo.listMessages(any()),
      ).thenAnswer((_) async => [_msg('a'), _msg('b')]);
      await cubit.refresh();
    },
    skip: 2, // load loading/ready
    expect: () => [
      isA<ChatThreadState>()
          .having((s) => s.messages.length, 'messages', 2)
          .having((s) => s.messages.last.id, 'last', 'b'),
    ],
    verify: (_) {
      // load() fired markAsRead once, refresh() once more.
      verify(() => repo.markAsRead('chat-1')).called(greaterThanOrEqualTo(2));
    },
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'refresh is a no-op before the thread is ready',
    build: () {
      stubLoad();
      return build();
    },
    act: (cubit) => cubit.refresh(), // never loaded → status initial
    expect: () => const <ChatThreadState>[],
    verify: (_) {
      verifyNever(() => repo.listMessages(any()));
      verifyNever(() => repo.markAsRead(any()));
    },
  );

  blocTest<ChatThreadCubit, ChatThreadState>(
    'refresh preserves a still-pending optimistic bubble',
    build: () {
      stubLoad();
      when(
        () => repo.sendText(
          chatId: any(named: 'chatId'),
          body: any(named: 'body'),
          as: any(named: 'as'),
        ),
      ).thenAnswer((_) => Completer<ChatMessage>().future); // never resolves
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      unawaited(cubit.sendText('pending')); // optimistic bubble, stays sending
      await Future<void>.delayed(const Duration(milliseconds: 10));
      when(
        () => repo.listMessages(any()),
      ).thenAnswer((_) async => [_msg('server-a')]);
      await cubit.refresh();
    },
    verify: (cubit) {
      expect(cubit.state.messages.map((m) => m.id), contains('server-a'));
      expect(
        cubit.state.messages.any(
          (m) => m.localId != null && m.status == ChatMessageStatus.sending,
        ),
        isTrue,
      );
    },
  );
}

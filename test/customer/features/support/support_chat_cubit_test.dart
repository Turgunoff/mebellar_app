import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/support/bloc/support_chat_cubit.dart';
import 'package:woody_app/customer/features/support/models/support_message.dart';
import 'package:woody_app/customer/features/support/repository/support_chat_repository.dart';

class _MockRepo extends Mock implements SupportChatRepository {}

SupportMessage _msg(
  String id, {
  SupportSenderType sender = SupportSenderType.user,
  SupportMessageType type = SupportMessageType.text,
}) => SupportMessage(
  id: id,
  chatId: 'support-1',
  senderId: 'sender',
  senderType: sender,
  messageType: type,
  textContent: 'hello $id',
  createdAt: DateTime.utc(2026, 6, 20, 10, 0),
);

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() => repo = _MockRepo());

  void stubLoad({
    Stream<SupportMessage>? messages,
    Stream<void>? reads,
    String chatId = 'support-1',
    List<SupportMessage> initial = const [],
  }) {
    when(() => repo.fetchChat()).thenAnswer(
      (_) async => (chatId: chatId, messages: initial),
    );
    when(
      () => repo.messagesStream(),
    ).thenAnswer((_) => messages ?? const Stream.empty());
    when(
      () => repo.readStream(),
    ).thenAnswer((_) => reads ?? const Stream.empty());
    when(() => repo.markRead()).thenAnswer((_) async {});
  }

  SupportChatCubit build() => SupportChatCubit(repo: repo);

  blocTest<SupportChatCubit, SupportChatState>(
    'load emits [loading, ready], resolves the chat id, and subscribes',
    build: () {
      stubLoad(initial: [_msg('a')]);
      return build();
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<SupportChatState>().having(
        (s) => s.status,
        'status',
        SupportChatStatus.loading,
      ),
      isA<SupportChatState>()
          .having((s) => s.status, 'status', SupportChatStatus.ready)
          .having((s) => s.chatId, 'chatId', 'support-1')
          .having((s) => s.messages.length, 'messages', 1),
    ],
    verify: (_) => verify(() => repo.markRead()).called(greaterThanOrEqualTo(1)),
  );

  blocTest<SupportChatCubit, SupportChatState>(
    'sendText inserts an optimistic "sending" bubble, then reconciles to sent',
    build: () {
      stubLoad();
      when(() => repo.sendText(any())).thenAnswer((_) async => _msg('server-1'));
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.sendText('hi');
    },
    skip: 2,
    expect: () => [
      isA<SupportChatState>()
          .having((s) => s.sending, 'sending', true)
          .having((s) => s.messages.length, 'messages', 1)
          .having(
            (s) => s.messages.single.status,
            'status',
            SupportMessageStatus.sending,
          ),
      isA<SupportChatState>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.messages.length, 'messages', 1)
          .having((s) => s.messages.single.id, 'id', 'server-1')
          .having(
            (s) => s.messages.single.status,
            'status',
            SupportMessageStatus.sent,
          ),
    ],
  );

  blocTest<SupportChatCubit, SupportChatState>(
    'sendText flips the optimistic bubble to failed when the send throws',
    build: () {
      stubLoad();
      when(() => repo.sendText(any())).thenThrow(Exception('boom'));
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.sendText('hi');
    },
    skip: 3,
    expect: () => [
      isA<SupportChatState>()
          .having((s) => s.sending, 'sending', false)
          .having(
            (s) => s.messages.single.status,
            'status',
            SupportMessageStatus.failed,
          )
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<SupportChatCubit, SupportChatState>(
    'sendImage appends the server row and clears sending',
    build: () {
      stubLoad();
      when(
        () => repo.sendImage(
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        ),
      ).thenAnswer(
        (_) async => _msg('img-1', type: SupportMessageType.image),
      );
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.sendImage(bytes: Uint8List(3), mimeType: 'image/jpeg');
    },
    verify: (cubit) {
      expect(cubit.state.messages.map((m) => m.id), contains('img-1'));
      expect(cubit.state.sending, isFalse);
    },
  );

  blocTest<SupportChatCubit, SupportChatState>(
    'sendAudio appends the server row and clears sending',
    build: () {
      stubLoad();
      when(
        () => repo.sendAudio(
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
          durationMs: any(named: 'durationMs'),
        ),
      ).thenAnswer(
        (_) async => _msg('aud-1', type: SupportMessageType.audio),
      );
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.sendAudio(
        bytes: Uint8List(3),
        contentType: 'audio/mp4',
        durationMs: 1500,
      );
    },
    verify: (cubit) {
      expect(cubit.state.messages.map((m) => m.id), contains('aud-1'));
      expect(cubit.state.sending, isFalse);
    },
  );

  blocTest<SupportChatCubit, SupportChatState>(
    'a realtime admin reply appends and triggers markRead',
    build: () {
      final ctrl = StreamController<SupportMessage>();
      stubLoad(messages: ctrl.stream);
      Future.delayed(
        const Duration(milliseconds: 10),
        () => ctrl.add(_msg('admin-1', sender: SupportSenderType.admin)),
      );
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    verify: (cubit) {
      expect(cubit.state.messages.length, 1);
      expect(cubit.state.messages.first.senderType, SupportSenderType.admin);
      verify(() => repo.markRead()).called(greaterThanOrEqualTo(1));
    },
  );

  blocTest<SupportChatCubit, SupportChatState>(
    'a realtime echo with an existing id does NOT duplicate',
    build: () {
      final ctrl = StreamController<SupportMessage>();
      stubLoad(messages: ctrl.stream, initial: [_msg('dup')]);
      Future.delayed(
        const Duration(milliseconds: 10),
        () => ctrl.add(_msg('dup')),
      );
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    verify: (cubit) => expect(cubit.state.messages.length, 1),
  );

  blocTest<SupportChatCubit, SupportChatState>(
    'a support_read frame flips my sent bubbles to read (✓✓)',
    build: () {
      final reads = StreamController<void>();
      stubLoad(
        reads: reads.stream,
        initial: [_msg('mine', sender: SupportSenderType.user)],
      );
      Future.delayed(const Duration(milliseconds: 10), () => reads.add(null));
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    verify: (cubit) {
      expect(cubit.state.messages.single.isRead, isTrue);
    },
  );

  blocTest<SupportChatCubit, SupportChatState>(
    'refresh swaps in server messages and preserves a pending optimistic bubble',
    build: () {
      stubLoad(initial: [_msg('a')]);
      when(
        () => repo.sendText(any()),
      ).thenAnswer((_) => Completer<SupportMessage>().future);
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      unawaited(cubit.sendText('pending'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      when(() => repo.fetchChat()).thenAnswer(
        (_) async => (chatId: 'support-1', messages: [_msg('a'), _msg('b')]),
      );
      await cubit.refresh();
    },
    verify: (cubit) {
      expect(cubit.state.messages.map((m) => m.id), contains('b'));
      expect(
        cubit.state.messages.any(
          (m) => m.localId != null && m.status == SupportMessageStatus.sending,
        ),
        isTrue,
      );
    },
  );

  blocTest<SupportChatCubit, SupportChatState>(
    'refresh is a no-op before the thread is ready',
    build: () {
      stubLoad();
      return build();
    },
    act: (cubit) => cubit.refresh(),
    expect: () => const <SupportChatState>[],
    verify: (_) => verifyNever(() => repo.fetchChat()),
  );

  test('MockSupportChatRepository drives the cubit end-to-end', () async {
    final mock = MockSupportChatRepository();
    final cubit = SupportChatCubit(repo: mock);
    await cubit.load();
    expect(cubit.state.status, SupportChatStatus.ready);
    await cubit.sendText('salom');
    expect(cubit.state.messages.last.textContent, 'salom');
    mock.emitAdminMessage(
      SupportMessage(
        id: 'admin-x',
        chatId: 'mock-support-1',
        senderId: 'admin',
        senderType: SupportSenderType.admin,
        messageType: SupportMessageType.text,
        textContent: 'qanday yordam beray?',
        createdAt: DateTime.now(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      cubit.state.messages.any((m) => m.id == 'admin-x'),
      isTrue,
    );
    await cubit.close();
  });
}

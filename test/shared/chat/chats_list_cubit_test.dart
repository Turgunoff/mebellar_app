import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/api_error.dart';
import 'package:woody_app/shared/chat/bloc/chats_list_cubit.dart';
import 'package:woody_app/shared/models/chat.dart';
import 'package:woody_app/shared/repositories/chat_repository.dart';

class _MockRepo extends Mock implements ChatRepository {}

Chat _chat(String id) => Chat(
      id: id,
      orderId: 'order-1',
      customerId: 'cust-1',
      shopId: 'shop-1',
      createdAt: DateTime.utc(2026, 5, 22),
    );

void main() {
  late _MockRepo repo;
  late StreamController<List<Chat>> stream;

  setUp(() {
    repo = _MockRepo();
    stream = StreamController<List<Chat>>();
    when(
      () => repo.myChatsStream(as: any(named: 'as')),
    ).thenAnswer((_) => stream.stream);
  });

  tearDown(() => stream.close());

  blocTest<ChatsListCubit, ChatsListState>(
    'a snapshot from the stream flips the cubit to ready',
    build: () => ChatsListCubit(repo, ChatSenderRole.customer),
    act: (_) => stream.add([_chat('c1')]),
    verify: (cubit) {
      expect(cubit.state.status, ChatsListStatus.ready);
      expect(cubit.state.chats, hasLength(1));
      expect(cubit.state.error, isNull);
    },
  );

  blocTest<ChatsListCubit, ChatsListState>(
    'scopes the stream to the seller viewer so buyer chats stay out',
    build: () => ChatsListCubit(repo, ChatSenderRole.seller),
    act: (_) => stream.add([_chat('c1')]),
    verify: (_) {
      verify(() => repo.myChatsStream(as: ChatSenderRole.seller)).called(1);
      verifyNever(() => repo.myChatsStream(as: ChatSenderRole.customer));
    },
  );

  blocTest<ChatsListCubit, ChatsListState>(
    'a stream error surfaces a localized failure message, not a raw exception',
    build: () => ChatsListCubit(repo, ChatSenderRole.customer),
    act: (_) async {
      stream.addError(ApiError(status: 0, code: 'network_error'));
      await Future<void>.delayed(Duration.zero);
    },
    verify: (cubit) {
      expect(cubit.state.status, ChatsListStatus.failure);
      // apiErrorMessage maps network_error → the uz `error.network` string
      // (uz is the default bundle in tests). Never `ApiError(...)`.toString().
      expect(cubit.state.error, 'Tarmoq xatosi. Internet aloqasini tekshiring');
    },
  );
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/shared/chat/bloc/total_unread_chats_cubit.dart';
import 'package:woody_app/shared/models/chat.dart';
import 'package:woody_app/shared/repositories/chat_repository.dart';

class _MockRepo extends Mock implements ChatRepository {}

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

  blocTest<TotalUnreadChatsCubit, int>(
    'sums the customer-side unread counts across chats',
    build: () => TotalUnreadChatsCubit(repo, ChatSenderRole.customer),
    act: (_) => stream.add([
      _chat(customerUnread: 2, sellerUnread: 9),
      _chat(customerUnread: 3, sellerUnread: 1),
    ]),
    expect: () => [5], // 2 + 3 (seller column ignored for a customer viewer)
  );

  blocTest<TotalUnreadChatsCubit, int>(
    'sums the seller-side unread counts for a seller viewer',
    build: () => TotalUnreadChatsCubit(repo, ChatSenderRole.seller),
    act: (_) => stream.add([
      _chat(customerUnread: 2, sellerUnread: 9),
      _chat(customerUnread: 3, sellerUnread: 1),
    ]),
    expect: () => [10], // 9 + 1
  );

  blocTest<TotalUnreadChatsCubit, int>(
    'keeps the last good count on a stream error (no throw, no reset)',
    build: () => TotalUnreadChatsCubit(repo, ChatSenderRole.customer),
    act: (_) async {
      stream.add([_chat(customerUnread: 4)]);
      await Future<void>.delayed(Duration.zero);
      stream.addError(StateError('blip'));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [4], // the error emits nothing further
  );
}

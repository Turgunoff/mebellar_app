import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/ai_designer/cubit/ai_designer_cubit.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_chat_store.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_designer_repository.dart';
import 'package:woody_app/customer/features/ai_designer/models/ai_chat_message.dart';

class _MockRepo extends Mock implements AiDesignerRepository {}

class _MockStore extends Mock implements AiChatStore {}

void main() {
  setUpAll(() {
    registerFallbackValue(<AiChatMessage>[]);
    registerFallbackValue(
      AiChatMessage(id: 'x', text: '', isUser: true, timestamp: DateTime(2020)),
    );
  });

  late _MockRepo repo;
  late _MockStore store;

  setUp(() {
    repo = _MockRepo();
    store = _MockStore();
    when(() => store.load()).thenReturn(const <AiChatMessage>[]);
    when(() => store.append(any())).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});
    when(
      () => repo.chat(
        message: any(named: 'message'),
        imageBytes: any(named: 'imageBytes'),
        imageMime: any(named: 'imageMime'),
        history: any(named: 'history'),
      ),
    ).thenAnswer(
      (_) async =>
          const AiDesignerReply(available: true, reply: 'ok', products: []),
    );
  });

  AiDesignerCubit build() => AiDesignerCubit(repository: repo, store: store);

  test('appends the user turn then the AI reply', () async {
    final cubit = build();
    await cubit.sendMessage(text: 'salom');

    expect(cubit.state.messages.length, 2);
    expect(cubit.state.messages.first.isUser, isTrue);
    expect(cubit.state.messages.first.text, 'salom');
    expect(cubit.state.messages.last.isUser, isFalse);
    expect(cubit.state.messages.last.text, 'ok');
    expect(cubit.state.sending, isFalse);
  });

  test('does not duplicate the in-flight turn into history', () async {
    final cubit = build();
    await cubit.sendMessage(text: 'birinchi');
    await cubit.sendMessage(text: 'ikkinchi');

    // captured == [msg1, history1, msg2, history2] in invocation order.
    final captured = verify(
      () => repo.chat(
        message: captureAny(named: 'message'),
        imageBytes: any(named: 'imageBytes'),
        imageMime: any(named: 'imageMime'),
        history: captureAny(named: 'history'),
      ),
    ).captured;

    final firstHistory = captured[1] as List<AiChatMessage>;
    final secondMessage = captured[2] as String;
    final secondHistory = captured[3] as List<AiChatMessage>;

    expect(firstHistory, isEmpty); // no prior turns on the first send
    expect(secondMessage, 'ikkinchi');
    expect(secondHistory.length, 2); // user('birinchi') + ai('ok')
    expect(
      secondHistory.any((m) => m.text == 'ikkinchi'),
      isFalse,
      reason: 'the question being sent must not also appear in history',
    );
  });

  test('keeps the picked photo in memory, keyed by the user message', () async {
    final cubit = build();
    await cubit.sendMessage(
      text: 'mana xonam',
      imageBytes: Uint8List.fromList([1, 2, 3]),
      imageMime: 'image/jpeg',
    );

    final userMsg = cubit.state.messages.first;
    expect(cubit.state.localImages[userMsg.id], Uint8List.fromList([1, 2, 3]));
  });

  test('degrades to an unavailable reply without throwing', () async {
    when(
      () => repo.chat(
        message: any(named: 'message'),
        imageBytes: any(named: 'imageBytes'),
        imageMime: any(named: 'imageMime'),
        history: any(named: 'history'),
      ),
    ).thenAnswer(
      (_) async => const AiDesignerReply(
        available: false,
        reply: 'fallback',
        products: [],
      ),
    );

    final cubit = build();
    await cubit.sendMessage(text: 'salom');

    expect(cubit.state.messages.last.text, 'fallback');
    expect(cubit.state.sending, isFalse);
  });
}

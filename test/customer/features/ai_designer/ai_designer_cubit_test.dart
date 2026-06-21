import 'dart:async';
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

  test('allows consecutive sends; pending counts in-flight requests', () async {
    final gate1 = Completer<AiDesignerReply>();
    final gate2 = Completer<AiDesignerReply>();
    final gates = <Completer<AiDesignerReply>>[gate1, gate2];
    var call = 0;
    when(
      () => repo.chat(
        message: any(named: 'message'),
        imageBytes: any(named: 'imageBytes'),
        imageMime: any(named: 'imageMime'),
        history: any(named: 'history'),
      ),
    ).thenAnswer((_) => gates[call++].future);

    final cubit = build();
    // Fire two sends WITHOUT awaiting — the old code blocked the 2nd via the
    // `sending` guard; now both go through (non-blocking UX).
    final f1 = cubit.sendMessage(text: 'birinchi');
    final f2 = cubit.sendMessage(text: 'ikkinchi');
    await Future<void>.delayed(Duration.zero); // let the sync prefixes run

    expect(cubit.state.messages.where((m) => m.isUser).length, 2);
    expect(cubit.state.pending, 2);
    expect(cubit.state.sending, isTrue);

    gate1.complete(
      const AiDesignerReply(available: true, reply: 'r1', products: []),
    );
    gate2.complete(
      const AiDesignerReply(available: true, reply: 'r2', products: []),
    );
    await Future.wait([f1, f2]);

    expect(cubit.state.pending, 0);
    expect(cubit.state.sending, isFalse);
    expect(cubit.state.messages.length, 4); // 2 user + 2 ai
  });

  test('persists an in-flight reply even after the cubit is closed (pop)', () async {
    final gate = Completer<AiDesignerReply>();
    when(
      () => repo.chat(
        message: any(named: 'message'),
        imageBytes: any(named: 'imageBytes'),
        imageMime: any(named: 'imageMime'),
        history: any(named: 'history'),
      ),
    ).thenAnswer((_) => gate.future);

    final cubit = build();
    final f = cubit.sendMessage(text: 'salom');
    await Future<void>.delayed(Duration.zero);

    // Simulate the user popping the chat screen while the request is in flight.
    // Closing here proves the worst case: the request is NOT cancelled and the
    // reply is still written to the store (so reopening reloads it from Hive).
    await cubit.close();
    gate.complete(
      const AiDesignerReply(available: true, reply: 'late reply', products: []),
    );
    await f;

    final appended = verify(
      () => store.append(captureAny()),
    ).captured.cast<AiChatMessage>();
    expect(
      appended.any((m) => !m.isUser && m.text == 'late reply'),
      isTrue,
      reason: 'the AI reply must persist even when the cubit closed mid-flight',
    );
  });
}

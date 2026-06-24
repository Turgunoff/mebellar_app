import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/auth/auth_cubit.dart';
import 'package:woody_app/core/storage/r2_upload_client.dart';
import 'package:woody_app/customer/features/ai_designer/cubit/ai_designer_cubit.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_chat_store.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_designer_repository.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_image_quota.dart';
import 'package:woody_app/customer/features/ai_designer/models/ai_chat_message.dart';

class _MockRepo extends Mock implements AiDesignerRepository {}

class _MockStore extends Mock implements AiChatStore {}

class _MockAuthCubit extends MockCubit<AppAuthState> implements AuthCubit {}

class _MockUploads extends Mock implements R2UploadClient {}

/// Hand fake (not mocktail) so the daily cap is deterministic without a Hive box.
class _FakeQuota implements AiImageQuota {
  _FakeQuota({this.allow = true});
  bool allow;
  int increments = 0;
  @override
  int get dailyLimit => 10;
  @override
  int get usedToday => allow ? 0 : dailyLimit;
  @override
  bool get canUpload => allow;
  @override
  Future<void> increment() async => increments++;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<AiChatMessage>[]);
    registerFallbackValue(
      AiChatMessage(id: 'x', text: '', isUser: true, timestamp: DateTime(2020)),
    );
    registerFallbackValue(R2Bucket.aiChatImages);
    registerFallbackValue(Uint8List(0));
  });

  late _MockRepo repo;
  late _MockStore store;
  late _MockAuthCubit auth;

  setUp(() {
    repo = _MockRepo();
    store = _MockStore();
    auth = _MockAuthCubit();
    // Signed-out auth: the cubit starts from a clean greeting and never fires a
    // history restore, keeping these tests focused on send/rate behaviour.
    whenListen(
      auth,
      const Stream<AppAuthState>.empty(),
      initialState: const AppAuthUnauthenticated(),
    );
    when(() => store.load()).thenReturn(const <AiChatMessage>[]);
    when(() => store.append(any())).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});
    when(() => store.replaceAll(any())).thenAnswer((_) async {});
    when(() => repo.fetchHistory()).thenAnswer((_) async => <AiChatMessage>[]);
    when(
      () => repo.chat(
        message: any(named: 'message'),
        imageUrl: any(named: 'imageUrl'),
        imagePath: any(named: 'imagePath'),
        history: any(named: 'history'),
      ),
    ).thenAnswer(
      (_) async =>
          const AiDesignerReply(available: true, reply: 'ok', products: []),
    );
    when(() => repo.rateMessage(any(), any())).thenAnswer((_) async => true);
  });

  AiDesignerCubit build() =>
      AiDesignerCubit(repository: repo, authCubit: auth, store: store);

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
        imageUrl: any(named: 'imageUrl'),
        imagePath: any(named: 'imagePath'),
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
        imageUrl: any(named: 'imageUrl'),
        imagePath: any(named: 'imagePath'),
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
        imageUrl: any(named: 'imageUrl'),
        imagePath: any(named: 'imagePath'),
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

  test(
    'rateAiMessage sets userRating on the matching reply and calls the repo',
    () async {
      when(
        () => repo.chat(
          message: any(named: 'message'),
          imageUrl: any(named: 'imageUrl'),
          imagePath: any(named: 'imagePath'),
          history: any(named: 'history'),
        ),
      ).thenAnswer(
        (_) async => const AiDesignerReply(
          available: true,
          reply: 'ok',
          products: [],
          logId: 'log-42',
        ),
      );

      final cubit = build();
      await cubit.sendMessage(text: 'salom');

      // The AI reply carries the backend log id.
      final aiMsg = cubit.state.messages.last;
      expect(aiMsg.isUser, isFalse);
      expect(aiMsg.logId, 'log-42');
      expect(aiMsg.userRating, isNull);

      await cubit.rateAiMessage('log-42', 'liked');

      final rated = cubit.state.messages.firstWhere((m) => m.logId == 'log-42');
      expect(rated.userRating, 'liked');
      verify(() => repo.rateMessage('log-42', 'liked')).called(1);
    },
  );

  test('rateAiMessage no-ops when no message matches the log id', () async {
    final cubit = build();
    await cubit.sendMessage(text: 'salom'); // reply has no logId (mock default)

    await cubit.rateAiMessage('missing', 'disliked');

    expect(cubit.state.messages.every((m) => m.userRating == null), isTrue);
    verifyNever(() => repo.rateMessage(any(), any()));
  });

  group('per-user history (auth-reactive)', () {
    test('restores history from the backend on login', () async {
      final history = [
        AiChatMessage(
          id: 'log1-u',
          text: 'eski savol',
          isUser: true,
          timestamp: DateTime(2026, 1, 1),
        ),
        AiChatMessage(
          id: 'log1-a',
          text: 'eski javob',
          isUser: false,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0, 1),
          logId: 'log1',
        ),
      ];
      when(() => repo.fetchHistory()).thenAnswer((_) async => history);
      // Authenticated at construction → the cubit restores immediately.
      whenListen(
        auth,
        const Stream<AppAuthState>.empty(),
        initialState: const AppAuthAuthenticated('u-1'),
      );

      final cubit = AiDesignerCubit(
        repository: repo,
        authCubit: auth,
        store: store,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.messages.map((m) => m.text), [
        'eski savol',
        'eski javob',
      ]);
      verify(() => repo.fetchHistory()).called(1);
      verify(() => store.replaceAll(any())).called(1);
    });

    test('clears the thread + local cache on logout', () async {
      final controller = StreamController<AppAuthState>();
      addTearDown(controller.close);
      whenListen(
        auth,
        controller.stream,
        initialState: const AppAuthAuthenticated('u-1'),
      );

      final cubit = AiDesignerCubit(
        repository: repo,
        authCubit: auth,
        store: store,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      await cubit.sendMessage(text: 'salom');
      expect(cubit.state.messages, isNotEmpty);

      controller.add(const AppAuthUnauthenticated());
      await pumpEventQueue();

      expect(cubit.state.messages, isEmpty);
      verify(() => store.clear()).called(1); // the logout wipe
    });

    test(
      'a guest (signed out) starts from an empty thread, no fetch',
      () async {
        // The default setUp auth is Unauthenticated.
        final cubit = build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.messages, isEmpty);
        verifyNever(() => repo.fetchHistory());
      },
    );

    test(
      'falls back to the local cache when the fetch fails, no clobber',
      () async {
        final cached = [
          AiChatMessage(
            id: 'c1-u',
            text: 'kesh savol',
            isUser: true,
            timestamp: DateTime(2026),
          ),
        ];
        when(() => store.load()).thenReturn(cached);
        when(() => repo.fetchHistory()).thenThrow(Exception('offline'));
        whenListen(
          auth,
          const Stream<AppAuthState>.empty(),
          initialState: const AppAuthAuthenticated('u-1'),
        );

        final cubit = AiDesignerCubit(
          repository: repo,
          authCubit: auth,
          store: store,
        );
        addTearDown(cubit.close);
        await pumpEventQueue();

        // The offline thread shows the cached copy…
        expect(cubit.state.messages.map((m) => m.text), ['kesh savol']);
        // …and a failed fetch must NOT wipe the cache.
        verifyNever(() => store.replaceAll(any()));
      },
    );
  });

  test(
    'persists an in-flight reply even after the cubit is closed (pop)',
    () async {
      final gate = Completer<AiDesignerReply>();
      when(
        () => repo.chat(
          message: any(named: 'message'),
          imageUrl: any(named: 'imageUrl'),
          imagePath: any(named: 'imagePath'),
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
        const AiDesignerReply(
          available: true,
          reply: 'late reply',
          products: [],
        ),
      );
      await f;

      final appended = verify(
        () => store.append(captureAny()),
      ).captured.cast<AiChatMessage>();
      expect(
        appended.any((m) => !m.isUser && m.text == 'late reply'),
        isTrue,
        reason:
            'the AI reply must persist even when the cubit closed mid-flight',
      );
    },
  );

  group('image upload + daily limit', () {
    setUp(() {
      // Authenticated → the cubit has a user id for the R2 key + restore.
      whenListen(
        auth,
        const Stream<AppAuthState>.empty(),
        initialState: const AppAuthAuthenticated('u-1'),
      );
    });

    test(
      'uploads the photo, sets imageUrl on the turn, sends image_url',
      () async {
        final uploads = _MockUploads();
        final quota = _FakeQuota(allow: true);
        when(
          () => uploads.upload(
            bucket: any(named: 'bucket'),
            path: any(named: 'path'),
            bytes: any(named: 'bytes'),
            contentType: any(named: 'contentType'),
          ),
        ).thenAnswer(
          (_) async => const R2UploadResult(
            bucket: R2Bucket.aiChatImages,
            path: 'u-1/abc.webp',
            publicUrl: 'https://cdn.woody.uz/ai-chat-images/u-1/abc.webp',
          ),
        );

        final cubit = AiDesignerCubit(
          repository: repo,
          authCubit: auth,
          store: store,
          uploads: uploads,
          imageQuota: quota,
        );
        addTearDown(cubit.close);
        await pumpEventQueue();

        await cubit.sendMessage(
          text: 'mana xonam',
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageMime: 'image/webp',
        );

        // The user turn carries the durable URL (so it restores after relaunch).
        final userMsg = cubit.state.messages.firstWhere((m) => m.isUser);
        expect(
          userMsg.imageUrl,
          'https://cdn.woody.uz/ai-chat-images/u-1/abc.webp',
        );
        expect(userMsg.hasImage, isTrue);
        expect(quota.increments, 1);

        // …and the repo got the URL + key, never raw bytes.
        final captured = verify(
          () => repo.chat(
            message: any(named: 'message'),
            imageUrl: captureAny(named: 'imageUrl'),
            imagePath: captureAny(named: 'imagePath'),
            history: any(named: 'history'),
          ),
        ).captured;
        expect(captured[0], 'https://cdn.woody.uz/ai-chat-images/u-1/abc.webp');
        expect(captured[1], 'u-1/abc.webp');
      },
    );

    test(
      'over the daily limit: no upload, text-only turn, limit error',
      () async {
        final uploads = _MockUploads();
        final quota = _FakeQuota(allow: false);

        final cubit = AiDesignerCubit(
          repository: repo,
          authCubit: auth,
          store: store,
          uploads: uploads,
          imageQuota: quota,
        );
        addTearDown(cubit.close);
        await pumpEventQueue();

        await cubit.sendMessage(
          text: 'mana xonam',
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageMime: 'image/webp',
        );

        verifyNever(
          () => uploads.upload(
            bucket: any(named: 'bucket'),
            path: any(named: 'path'),
            bytes: any(named: 'bytes'),
            contentType: any(named: 'contentType'),
          ),
        );
        expect(cubit.state.error, AiDesignerCubit.imageLimitError);
        // The turn still sent — text-only (no image_url).
        final captured = verify(
          () => repo.chat(
            message: any(named: 'message'),
            imageUrl: captureAny(named: 'imageUrl'),
            imagePath: any(named: 'imagePath'),
            history: any(named: 'history'),
          ),
        ).captured;
        expect(captured.single, isNull);
      },
    );
  });
}

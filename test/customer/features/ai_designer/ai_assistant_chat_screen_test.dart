import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/auth/auth_cubit.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/customer/features/ai_designer/cubit/ai_designer_cubit.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_chat_store.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_designer_repository.dart';
import 'package:woody_app/customer/features/ai_designer/models/ai_chat_message.dart';
import 'package:woody_app/customer/features/ai_designer/screens/ai_assistant_chat_screen.dart';

class _MockRepo extends Mock implements AiDesignerRepository {}

class _MockStore extends Mock implements AiChatStore {}

class _MockAuthCubit extends MockCubit<AppAuthState> implements AuthCubit {}

class _Harness extends StatelessWidget {
  const _Harness(this.cubit);

  final AiDesignerCubit cubit;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<AiDesignerCubit>.value(
        value: cubit,
        child: const AiAssistantChatScreen(),
      ),
    );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      AiChatMessage(id: 'x', text: '', isUser: true, timestamp: DateTime(2020)),
    );
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
  });

  late _MockRepo repo;
  late _MockStore store;
  late _MockAuthCubit auth;

  setUp(() {
    repo = _MockRepo();
    store = _MockStore();
    auth = _MockAuthCubit();
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
  });

  testWidgets(
    'typing bubble shows + input stays live while a reply is in flight',
    (tester) async {
      // The request hangs (gate never completes) so the screen stays in the
      // "typing" state for the assertions.
      final gate = Completer<AiDesignerReply>();
      when(
        () => repo.chat(
          message: any(named: 'message'),
          imageUrl: any(named: 'imageUrl'),
          imagePath: any(named: 'imagePath'),
          history: any(named: 'history'),
        ),
      ).thenAnswer((_) => gate.future);

      final cubit = AiDesignerCubit(
        repository: repo,
        authCubit: auth,
        store: store,
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(_Harness(cubit));
      await tester.pump();

      // No blocking spinner in the composer at rest.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Fire a message; the reply hangs → we enter the typing state.
      cubit.sendMessage(text: 'salom');
      await tester.pump();

      // The inline typing bubble appears with the localized copy.
      expect(find.text('AI Dizayner javob yozmoqda...'), findsOneWidget);
      // Still NO blocking spinner — the busy cue is the bubble, not a spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // The input is NOT disabled — the user can fire consecutive messages.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isNot(false));

      // Unmount to dispose the typing animation's ticker before the test ends.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('restores backend history on login, pinned to the newest', (
    tester,
  ) async {
    // A long history (restored from the backend after login) that overflows the
    // viewport. `reverse: true` must open the thread at the bottom, so the
    // NEWEST message is visible and the oldest is scrolled off the top (the lazy
    // ListView never even builds it).
    final history = List.generate(
      40,
      (i) => AiChatMessage(
        id: 'm$i',
        text: 'xabar-$i',
        isUser: i.isEven,
        timestamp: DateTime(2026, 1, 1).add(Duration(minutes: i)),
      ),
    );
    // Signed in → the cubit fetches THIS user's history from the backend.
    whenListen(
      auth,
      const Stream<AppAuthState>.empty(),
      initialState: const AppAuthAuthenticated('u-1'),
    );
    when(() => repo.fetchHistory()).thenAnswer((_) async => history);

    final cubit = AiDesignerCubit(
      repository: repo,
      authCubit: auth,
      store: store,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_Harness(cubit));
    await tester.pump(); // resolve the async restore (fetchHistory) + emit
    await tester.pump(); // settle the reverse-list layout

    expect(find.text('xabar-39'), findsOneWidget); // newest, at the bottom
    expect(find.text('xabar-0'), findsNothing); // oldest, off-screen at the top

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

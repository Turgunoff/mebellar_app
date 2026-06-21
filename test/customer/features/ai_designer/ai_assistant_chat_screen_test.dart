import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/customer/features/ai_designer/cubit/ai_designer_cubit.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_chat_store.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_designer_repository.dart';
import 'package:woody_app/customer/features/ai_designer/models/ai_chat_message.dart';
import 'package:woody_app/customer/features/ai_designer/screens/ai_assistant_chat_screen.dart';

class _MockRepo extends Mock implements AiDesignerRepository {}

class _MockStore extends Mock implements AiChatStore {}

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

  setUp(() {
    repo = _MockRepo();
    store = _MockStore();
    when(() => store.load()).thenReturn(const <AiChatMessage>[]);
    when(() => store.append(any())).thenAnswer((_) async {});
  });

  testWidgets('typing bubble shows + input stays live while a reply is in flight', (
    tester,
  ) async {
    // The request hangs (gate never completes) so the screen stays in the
    // "typing" state for the assertions.
    final gate = Completer<AiDesignerReply>();
    when(
      () => repo.chat(
        message: any(named: 'message'),
        imageBytes: any(named: 'imageBytes'),
        imageMime: any(named: 'imageMime'),
        history: any(named: 'history'),
      ),
    ).thenAnswer((_) => gate.future);

    final cubit = AiDesignerCubit(repository: repo, store: store);
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
  });
}

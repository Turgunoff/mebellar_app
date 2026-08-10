import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/customer/features/support/models/support_message.dart';
import 'package:woody_app/customer/features/support/repository/support_chat_repository.dart';
import 'package:woody_app/customer/features/support/screens/support_chat_screen.dart';
import 'package:woody_app/shared/widgets/error_state.dart';

/// Bug repro: `SupportChatCubit.load()`'s catch block sets BOTH
/// `status: failure` AND `error` in the same emit. The screen's
/// `BlocListener` used to key its `listenWhen` off `error` alone, so that
/// single emit fired the toast SnackBar *and* the full-screen `ErrorState`
/// at once — the same translated message shown twice. In-place send
/// failures (`sendText`/`sendImage`/`sendAudio`) are the legitimate case
/// that must keep toasting: they set `error` but leave `status` at `ready`
/// (the thread with existing messages stays on screen), so only the toast
/// should fire there.
class _MockRepo extends Mock implements SupportChatRepository {}

class _Harness extends StatelessWidget {
  const _Harness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const SupportChatScreen(),
    );
  }
}

void main() {
  setUpAll(() {
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
  });

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    sl.registerSingleton<SupportChatRepository>(repo);
  });

  tearDown(() => sl.reset());

  testWidgets(
    'an initial-load failure renders the full-screen ErrorState and does NOT '
    'also toast a duplicate SnackBar',
    (tester) async {
      // A genuine `async` throw (NOT `thenThrow`) so the error is delivered
      // via the Future's microtask, same as a real network round trip —
      // this is what lets `BlocListener` actually mount and subscribe
      // *before* the failure state is emitted (matching production timing).
      // `thenThrow` throws synchronously during the mock call itself, which
      // would race the widget's `initState`/mount and give a false pass.
      when(() => repo.fetchChat()).thenAnswer((_) async {
        throw Exception('boom');
      });

      await tester.pumpWidget(const _Harness());
      // Deliberately NOT pumpAndSettle(): the SnackBar auto-dismisses after
      // ~4s, and pumpAndSettle elapses fake time until idle, which would
      // sail past the auto-dismiss and hide the very bug under test. A few
      // bounded pumps flush the one microtask hop (await fetchChat()) plus
      // the resulting rebuild, without burning through the dismiss timer.
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'an in-place send failure (status stays ready) still shows the toast, '
    'with no full-screen takeover',
    (tester) async {
      when(() => repo.fetchChat()).thenAnswer(
        (_) async => (chatId: 'support-1', messages: const <SupportMessage>[]),
      );
      when(
        () => repo.messagesStream(),
      ).thenAnswer((_) => const Stream.empty());
      when(() => repo.readStream()).thenAnswer((_) => const Stream.empty());
      when(() => repo.markRead()).thenAnswer((_) async {});
      when(() => repo.sendText(any())).thenAnswer((_) async {
        throw Exception('send-boom');
      });

      await tester.pumpWidget(const _Harness());
      await tester.pump();
      await tester.pump();

      // Thread loaded fine — no full-screen error yet.
      expect(find.byType(ErrorState), findsNothing);

      await tester.enterText(find.byType(TextField), 'salom');
      await tester.pump();
      await tester.tap(find.byIcon(Iconsax.send_2));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
    },
  );
}

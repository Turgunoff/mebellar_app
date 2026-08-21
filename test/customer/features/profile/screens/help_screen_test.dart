import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/config/remote_config.dart';
import 'package:woody_app/core/auth/auth_cubit.dart';
import 'package:woody_app/customer/features/profile/screens/help_screen.dart';

/// AuthCubit is swapped for a MockCubit so each auth state (guest / signed-in)
/// is pinned without a TokenStore. The contact row reads it via BlocBuilder to
/// decide whether the 4th (in-app chat) icon appears.
class _MockAuthCubit extends MockCubit<AppAuthState> implements AuthCubit {}

void main() {
  late _MockAuthCubit auth;

  setUp(() => auth = _MockAuthCubit());

  Widget harness() => MaterialApp(
    home: BlocProvider<AuthCubit>.value(value: auth, child: const HelpScreen()),
  );

  void pinState(AppAuthState state) =>
      whenListen(auth, const Stream<AppAuthState>.empty(), initialState: state);

  testWidgets('guest sees the three public contact tiles with values', (
    tester,
  ) async {
    pinState(const AppAuthUnauthenticated());

    await tester.pumpWidget(harness());
    await tester.pump();

    // Call + Telegram + Email, no in-app chat.
    expect(find.byIcon(Iconsax.call), findsOneWidget);
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.byType(FaIcon), findsOneWidget); // telegram
    expect(find.byIcon(Icons.support_agent), findsNothing);
    // Live contact values are shown as tile subtitles.
    expect(find.text(RemoteConfig.instance.supportPhone), findsOneWidget);
    expect(find.text(RemoteConfig.instance.supportEmail), findsOneWidget);
    expect(
      find.text(RemoteConfig.instance.telegramHandleLabel),
      findsOneWidget,
    );
  });

  testWidgets('signed-in user also sees the in-app chat tile', (tester) async {
    pinState(const AppAuthAuthenticated('user-1'));

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byIcon(Iconsax.call), findsOneWidget);
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.byType(FaIcon), findsOneWidget);
    expect(find.byIcon(Icons.support_agent), findsOneWidget);
    expect(find.text('Onlayn chat'), findsOneWidget);
  });

  testWidgets('staffed-hours strip shows the window and a status line', (
    tester,
  ) async {
    pinState(const AppAuthUnauthenticated());
    RemoteConfig.instance
      ..supportHoursFrom = 9
      ..supportHoursTo = 21;

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('09:00 – 21:00'), findsOneWidget);
    // The open/closed copy depends on the wall clock, so assert that exactly
    // one of the two states rendered rather than pinning the current hour.
    final open = find.text("Qo'llab-quvvatlash xizmati ochiq");
    final closed = find.text('Hozir yopiq');
    expect(
      open.evaluate().length + closed.evaluate().length,
      1,
      reason: 'exactly one status line must render',
    );
  });

  testWidgets('renders the three FAQ category sections', (tester) async {
    pinState(const AppAuthUnauthenticated());

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Umumiy savollar'), findsOneWidget);

    // The buyers/sellers sections sit below the fold in the test viewport.
    await tester.scrollUntilVisible(find.text('Xaridorlar uchun'), 200);
    expect(find.text('Xaridorlar uchun'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Sotuvchilar uchun'), 200);
    expect(find.text('Sotuvchilar uchun'), findsOneWidget);
    // A seller-specific question is present.
    expect(find.text("Qanday qilib sotuvchi bo'lish mumkin?"), findsOneWidget);
  });
}

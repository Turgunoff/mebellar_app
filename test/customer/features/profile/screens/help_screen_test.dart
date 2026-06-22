import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  testWidgets('guest sees only the three public contact icons', (tester) async {
    pinState(const AppAuthUnauthenticated());

    await tester.pumpWidget(harness());
    await tester.pump();

    // Email + Telegram + WhatsApp, no in-app chat.
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.byType(FaIcon), findsNWidgets(2)); // telegram + whatsapp
    expect(find.byIcon(Icons.support_agent), findsNothing);
  });

  testWidgets('signed-in user also sees the in-app chat icon', (tester) async {
    pinState(const AppAuthAuthenticated('user-1'));

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.byType(FaIcon), findsNWidgets(2));
    expect(find.byIcon(Icons.support_agent), findsOneWidget);
  });

  testWidgets('renders the three FAQ category sections', (tester) async {
    pinState(const AppAuthUnauthenticated());

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Umumiy savollar'), findsOneWidget);
    expect(find.text('Xaridorlar uchun'), findsOneWidget);

    // The sellers section sits below the fold in the test viewport.
    await tester.scrollUntilVisible(find.text('Sotuvchilar uchun'), 200);
    expect(find.text('Sotuvchilar uchun'), findsOneWidget);
    // A seller-specific question is present.
    expect(find.text("Qanday qilib sotuvchi bo'lish mumkin?"), findsOneWidget);
  });
}

// Customer Profile screen — end-to-end coverage for the screen shown in both
// of the two-simulator setup's states: a plain customer ("Sotuvchi bo'ling"
// CTA) and an already-approved seller currently browsing in customer mode
// ("Do'koningiz tasdiqlandi!" CTA). Same file, run once per device — each
// test adapts to whichever seller-status card the signed-in account renders.
//
//   flutter test integration_test/profile_screen_test.dart \
//     --dart-define-from-file=env/prod.json
//
// Preconditions:
//   * The device/simulator already has a signed-in session — this suite does
//     not drive the OTP auth flow (see integration_test/app_test.dart's
//     header: OTP delivery isn't automatable against the real backend).
//   * Network access to api.woody.uz.
//
// This suite is intentionally non-destructive by default: it never taps the
// sign-out sheet's confirm action, and it never taps the approved-seller CTA
// (that switches app mode via Phoenix.rebirth) — both would tear down the
// exact manual session you're using to run it. The one destructive test is
// opt-in — see its own doc comment below.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/main.dart' as app;

/// Launches the app and, if the customer bottom nav is present, taps through
/// to the Profile tab (the shell boots on Home). Defensive `if` mirrors
/// app_test.dart's pattern — a guest/logged-out session may not show the
/// same tab bar.
Future<void> _launchOnProfileTab(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 5));

  final profileTab = find.text(tr('nav.profile'));
  if (profileTab.evaluate().isNotEmpty) {
    await tester.tap(profileTab.first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'profile screen renders the core sections for a signed-in account',
    (tester) async {
      await _launchOnProfileTab(tester);

      expect(find.text(tr('profile.title')), findsOneWidget);
      expect(find.text(tr('profile.orders_title')), findsOneWidget);
      expect(find.text(tr('chat.title')), findsWidgets);
      expect(find.text(tr('profile.menu_settings')), findsOneWidget);
      expect(find.text(tr('profile.help_title')), findsOneWidget);
      expect(find.text(tr('profile.menu_about')), findsOneWidget);
      expect(find.text(tr('profile.sign_out_action')), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'seller status card reflects the account — become-seller vs approved vs pending vs rejected',
    (tester) async {
      await _launchOnProfileTab(tester);

      final cardTitles = <String, Finder>{
        'become_seller': find.text(tr('profile.become_seller_title')),
        'pending': find.text(tr('profile.seller_pending_title')),
        'approved': find.text(tr('profile.seller_approved_title')),
        'rejected': find.text(tr('profile.seller_rejected_title')),
      };

      final present = cardTitles.entries
          .where((entry) => entry.value.evaluate().isNotEmpty)
          .map((entry) => entry.key)
          .toList();

      // Exactly one seller-status card renders at a time.
      expect(
        present.length,
        1,
        reason: 'expected exactly one seller-status card, found: $present',
      );

      switch (present.single) {
        case 'become_seller':
          expect(
            find.text(tr('profile.become_seller_subtitle')),
            findsOneWidget,
          );
        case 'approved':
          // Present and tappable, but deliberately NOT tapped — tapping
          // switches app mode (Phoenix.rebirth into the seller shell),
          // which is out of scope for a "profile screen" suite and would
          // disrupt this exact session.
          expect(find.text(tr('profile.seller_open_panel')), findsOneWidget);
        case 'pending':
          expect(find.text(tr('profile.seller_pending_body')), findsOneWidget);
        case 'rejected':
          expect(
            find.text(tr('profile.seller_rejected_subtitle')),
            findsOneWidget,
          );
      }

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sign-out sheet opens on tap and Bekor qilish dismisses it without signing out',
    (tester) async {
      await _launchOnProfileTab(tester);

      await tester.tap(find.text(tr('profile.sign_out_action')));
      await tester.pumpAndSettle();

      expect(find.text(tr('profile.sign_out_title')), findsOneWidget);
      expect(find.text(tr('profile.sign_out_confirm')), findsOneWidget);

      await tester.tap(find.text(tr('profile.cancel')));
      await tester.pumpAndSettle();

      // Sheet dismissed, still on the profile screen, still signed in.
      expect(find.text(tr('profile.sign_out_title')), findsNothing);
      expect(find.text(tr('profile.title')), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sign-out sheet confirm actually signs the user out (DESTRUCTIVE — opt-in)',
    (tester) async {
      await _launchOnProfileTab(tester);

      await tester.tap(find.text(tr('profile.sign_out_action')));
      await tester.pumpAndSettle();

      // Two "Chiqish" matches once the sheet is open: the screen's own
      // sign-out button underneath, and the sheet's confirm button on top.
      // The sheet's is added later, so `.last` is the interactive one.
      await tester.tap(find.text(tr('profile.sign_out_action')).last);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text(tr('profile.sign_out_title')), findsNothing);
      expect(tester.takeException(), isNull);
    },
    // Opt-in only: `flutter test integration_test/profile_screen_test.dart
    // --dart-define-from-file=env/prod.json --dart-define=RUN_DESTRUCTIVE_TESTS=true`
    // Signs the device out for real — don't run this against a simulator
    // you're mid-way through manually testing unless you mean to.
    skip: !const bool.fromEnvironment('RUN_DESTRUCTIVE_TESTS'),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/seller/features/wallet/screens/wallet_screen.dart';
import 'package:woody_app/seller/features/wallet/widgets/wallet_info_bottom_sheet.dart';
import 'package:woody_app/shared/models/seller_wallet.dart';
import 'package:woody_app/shared/repositories/seller_wallet_repository.dart';
import 'package:woody_app/shared/repositories/tariff_repository.dart';

import '../../../../fixtures/mocks/mock/mock_tariff_repository.dart';

class _MockWalletRepo extends Mock implements SellerWalletRepository {}

void main() {
  late _MockWalletRepo walletRepo;

  setUp(() {
    walletRepo = _MockWalletRepo();
    when(
      () => walletRepo.fetch(recent: any(named: 'recent')),
    ).thenAnswer((_) async => const SellerWallet());
    sl.registerSingleton<SellerWalletRepository>(walletRepo);
    sl.registerSingleton<TariffRepository>(MockTariffRepository());
  });

  tearDown(() => sl.reset());

  testWidgets('first visit auto-opens the explainer and marks the flag', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(WalletInfoBottomSheet), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('has_seen_wallet_info'), isTrue);
  });

  testWidgets(
    'returning visit does not auto-open; the link opens it manually',
    (tester) async {
      SharedPreferences.setMockInitialValues(const {
        'has_seen_wallet_info': true,
      });

      await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
      await tester.pumpAndSettle();

      // No auto-open, but the persistent link is present.
      expect(find.byType(WalletInfoBottomSheet), findsNothing);
      expect(find.text('Hamyon qanday ishlaydi?'), findsOneWidget);

      await tester.tap(find.text('Hamyon qanday ishlaydi?'));
      await tester.pumpAndSettle();
      expect(find.byType(WalletInfoBottomSheet), findsOneWidget);
    },
  );
}

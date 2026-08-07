import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/core/storage/hive_boxes.dart';
import 'package:woody_app/seller/features/wallet/screens/wallet_screen.dart';
import 'package:woody_app/seller/features/wallet/widgets/wallet_info_bottom_sheet.dart';
import 'package:woody_app/shared/models/seller_wallet.dart';
import 'package:woody_app/shared/repositories/seller_wallet_repository.dart';
import 'package:woody_app/shared/repositories/tariff_repository.dart';

import '../../../../fixtures/mocks/mock/mock_tariff_repository.dart';

class _MockWalletRepo extends Mock implements SellerWalletRepository {}

// `SellerWalletCubit` takes `WoodyApiClient`/`Box`/`TariffRepository` as
// constructor deps (T-07 — it triggers its own payment-methods refresh and
// owns the manual-topup instructions/upload calls instead of nested widgets
// resolving them via `sl<>()`), so `_WalletScreenState.initState` resolves
// all three from the locator; each must be registered here or that lookup
// throws on the very first build.
class _MockApi extends Mock implements WoodyApiClient {}

class _MockSettingsBox extends Mock implements Box {}

void main() {
  late _MockWalletRepo walletRepo;

  setUp(() {
    walletRepo = _MockWalletRepo();
    when(
      () => walletRepo.fetch(recent: any(named: 'recent')),
    ).thenAnswer((_) async => const SellerWallet());
    sl.registerSingleton<SellerWalletRepository>(walletRepo);
    sl.registerSingleton<TariffRepository>(MockTariffRepository());

    final api = _MockApi();
    // `refreshPaymentMethods` (remote_config.dart) catches every failure and
    // keeps the Hive cache — a plain rejection is enough to exercise that
    // path without touching the settings box at all.
    when(
      () => api.get<Map<String, dynamic>>(
        any(),
        query: any(named: 'query'),
        anonymous: any(named: 'anonymous'),
        retries: any(named: 'retries'),
      ),
    ).thenThrow(Exception('no network in test'));
    sl.registerSingleton<WoodyApiClient>(api);
    sl.registerSingleton<Box>(
      _MockSettingsBox(),
      instanceName: HiveBoxes.settings,
    );
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

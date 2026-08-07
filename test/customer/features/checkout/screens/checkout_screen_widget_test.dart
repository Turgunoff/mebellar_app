import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/analytics/analytics_service.dart';
import 'package:woody_app/core/analytics/noop_analytics_service.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/core/storage/hive_boxes.dart';
import 'package:woody_app/customer/features/checkout/screens/checkout_screen.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';
import 'package:woody_app/shared/repositories/checkout_repository.dart';
import 'package:woody_app/shared/repositories/payment_repository.dart';

/// ROADMAP B.5 — widget test for the checkout screen. The screen builds its own
/// `CheckoutCubit` from `sl<CheckoutRepository>()` + `sl<CartRepository>()` +
/// `sl<PaymentRepository>()`, so test doubles are registered into the locator;
/// the cubit's constructor touches none of them, so the editing-state render is
/// fully deterministic.
class _MockCheckoutRepo extends Mock implements CheckoutRepository {}

class _MockCartRepo extends Mock implements CartRepository {}

class _MockPaymentRepo extends Mock implements PaymentRepository {}

// `CheckoutCubit` takes `WoodyApiClient`/`Box` as constructor deps (T-07 —
// it triggers its own payment-methods refresh instead of a nested widget
// resolving them via `sl<>()` in initState), so `CheckoutScreen`'s
// `BlocProvider.create` resolves both from the locator; both must be
// registered here or that lookup throws on the very first build.
class _MockApi extends Mock implements WoodyApiClient {}

class _MockSettingsBox extends Mock implements Box {}

void main() {
  setUpAll(() => registerFallbackValue(const <CheckoutOrderLine>[]));

  setUp(() {
    final checkout = _MockCheckoutRepo();
    // The construction-time quote refresh returns an Err (repo is Result-side
    // now); `_quoteGroup` maps it to null so the screen keeps its local estimate.
    when(
      () => checkout.quote(
        lines: any(named: 'lines'),
        deliveryAddress: any(named: 'deliveryAddress'),
        wantInstallation: any(named: 'wantInstallation'),
      ),
    ).thenAnswer(
      (_) async =>
          const Err<CheckoutQuote>(ServerFailure(message: 'no quote in test')),
    );
    sl.registerSingleton<CheckoutRepository>(checkout);
    sl.registerSingleton<CartRepository>(_MockCartRepo());
    sl.registerSingleton<PaymentRepository>(_MockPaymentRepo());
    sl.registerSingleton<AnalyticsService>(const NoopAnalyticsService());

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

  testWidgets('builds the checkout screen in its initial editing state', (
    tester,
  ) async {
    const item = CartItemModel(
      id: 'c1',
      productId: 'p1',
      productName: 'Premium Divan',
      productImage: '',
      productPrice: 4500000,
      quantity: 1,
    );
    await tester.pumpWidget(
      const MaterialApp(home: CheckoutScreen(items: [item])),
    );
    await tester.pump();

    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.byType(AppBar), findsOneWidget);
  });
}

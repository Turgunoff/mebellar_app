import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/analytics/analytics_service.dart';
import 'package:woody_app/core/analytics/noop_analytics_service.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/core/result/result.dart';
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

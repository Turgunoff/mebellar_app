import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:woody_app/core/analytics/analytics_service.dart';
import 'package:woody_app/core/analytics/noop_analytics_service.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/customer/features/checkout/screens/checkout_screen.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';

/// ROADMAP B.5 — widget test for the checkout screen. The screen builds its
/// own `CheckoutCubit` from `sl<SupabaseClient>()` + `sl<CartRepository>()`,
/// so test doubles are registered into the locator; the cubit's constructor
/// touches neither, so the editing-state render is fully deterministic.
class _MockSupabase extends Mock implements SupabaseClient {}

class _MockCartRepo extends Mock implements CartRepository {}

void main() {
  setUp(() {
    sl.registerSingleton<SupabaseClient>(_MockSupabase());
    sl.registerSingleton<CartRepository>(_MockCartRepo());
    sl.registerSingleton<AnalyticsService>(const NoopAnalyticsService());
  });

  tearDown(() => sl.reset());

  testWidgets('builds the checkout screen in its initial editing state',
      (tester) async {
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:woody_app/customer/navigation/product_escape_hatch.dart';

/// Drives [escapeProductRabbitHole] against a REAL GoRouter so the synchronous
/// pop loop is exercised at runtime — the one thing the pure-function unit test
/// can't cover. Route paths mirror the customer router's patterns exactly.
GoRouter _router({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Marker('home')),
      GoRoute(path: '/product-list', builder: (_, _) => const _Marker('list')),
      GoRoute(path: '/shop/:id', builder: (_, _) => const _Marker('shop')),
      GoRoute(
        path: '/product-detail/:id',
        builder: (_, s) => _Detail(id: s.pathParameters['id']!),
      ),
    ],
  );
}

class _Marker extends StatelessWidget {
  const _Marker(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('screen-$label')));
}

class _Detail extends StatelessWidget {
  const _Detail({required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('escape'),
            icon: const Icon(Icons.close),
            onPressed: () => escapeProductRabbitHole(context),
          ),
        ],
      ),
      body: Center(child: Text('detail-$id')),
    );
  }
}

void main() {
  Future<void> tapEscape(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('escape')));
    await tester.pumpAndSettle();
  }

  testWidgets('collapses a 3-deep rabbit hole back to the origin list', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/product-list');
    await tester.pumpAndSettle();
    router.push('/product-detail/A');
    await tester.pumpAndSettle();
    router.push('/product-detail/B');
    await tester.pumpAndSettle();
    router.push('/product-detail/C');
    await tester.pumpAndSettle();
    expect(find.text('detail-C'), findsOneWidget);

    await tapEscape(tester);

    expect(find.text('screen-list'), findsOneWidget);
    expect(find.textContaining('detail-'), findsNothing);
  });

  testWidgets('lands on the nearest non-product origin (shop mid-chain)', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/product-list');
    await tester.pumpAndSettle();
    router.push('/product-detail/A');
    await tester.pumpAndSettle();
    router.push('/shop/42');
    await tester.pumpAndSettle();
    router.push('/product-detail/B');
    await tester.pumpAndSettle();
    router.push('/product-detail/C');
    await tester.pumpAndSettle();

    await tapEscape(tester);

    // Only the contiguous top run (C, B) is popped → the shop is revealed,
    // NOT the list further down.
    expect(find.text('screen-shop'), findsOneWidget);
    expect(find.textContaining('detail-'), findsNothing);
  });

  testWidgets('deep-link-only chain falls back to Home', (tester) async {
    final router = _router(initialLocation: '/product-detail/X');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/product-detail/Y');
    await tester.pumpAndSettle();
    expect(find.text('detail-Y'), findsOneWidget);

    await tapEscape(tester);

    expect(find.text('screen-home'), findsOneWidget);
    expect(find.textContaining('detail-'), findsNothing);
  });

  testWidgets('never pops past the origin (single detail over a list)', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/product-list');
    await tester.pumpAndSettle();
    router.push('/product-detail/A');
    await tester.pumpAndSettle();

    await tapEscape(tester);

    expect(find.text('screen-list'), findsOneWidget);
    expect(find.textContaining('detail-'), findsNothing);
  });
}

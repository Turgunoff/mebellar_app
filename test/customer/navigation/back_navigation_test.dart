import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:woody_app/customer/navigation/product_escape_hatch.dart';

/// Regression guard for the reported bug: "Back from AI chat / a category lands
/// on the Cart tab (index 2) instead of the previous screen."
///
/// It mirrors the customer router topology and the shell's tab-index logic
/// (see [buildCustomerRouter] + [CustomerHomeShell] in lib/customer):
///   * the bottom tabs live inside ONE `/` route as an IndexedStack; the active
///     tab is shell-local `setState`, NOT a navigation — so the location stays
///     `/` even on the Cart tab;
///   * `/ai-designer-chat` and `/product-list` are real pushed GoRoutes;
///   * `/` reads its initial tab from `?tab=` exactly like the real builder, and
///     re-applies a *non-null* `initialTab` in didUpdateWidget.
///
/// The back-button code is copied verbatim from the screens:
///   * AI chat → `canPop() ? pop() : go('/')`;
///   * product-list → `canPop() ? pop() : go('/?tab=categories')`;
///   * support → `canPop() ? pop() : go('/')`
///     (support_chat_screen.dart's `_handleBack`);
///   * product detail → `Navigator.of(context).maybePop()` — the back button
///     baked into [PreviewAppBar] (shared with seller mode), a plain Material
///     pop, NOT a `context.go`. The detail and support cases pin the two
///     screens the bug report named, which the AI-chat / product-list cases
///     above did not exercise.
const _cartTab = 2;

int? _tabFromQuery(String? tab) => switch (tab) {
  'categories' => 1,
  'cart' => 2,
  'favorites' => 3,
  'profile' => 4,
  _ => null,
};

GoRouter _router({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => _ShellReplica(
          initialTab: _tabFromQuery(state.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(
        path: '/ai-designer-chat',
        builder: (_, _) => const _AiChatReplica(),
      ),
      GoRoute(
        path: '/product-list',
        builder: (_, _) => const _ProductListReplica(),
      ),
      GoRoute(
        path: '/product-detail/:id',
        builder: (_, _) => const _ProductDetailReplica(),
      ),
      GoRoute(path: '/support', builder: (_, _) => const _SupportReplica()),
    ],
  );
}

/// Mirrors `_CustomerHomeShellState`'s index handling exactly.
class _ShellReplica extends StatefulWidget {
  const _ShellReplica({this.initialTab});
  final int? initialTab;
  @override
  State<_ShellReplica> createState() => _ShellReplicaState();
}

class _ShellReplicaState extends State<_ShellReplica> {
  late int _index = widget.initialTab ?? 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) _consumeTabQuery();
  }

  void _goToTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  void didUpdateWidget(_ShellReplica oldWidget) {
    super.didUpdateWidget(oldWidget);
    final requested = widget.initialTab;
    if (requested == null) return;
    if (requested != _index) _goToTab(requested);
    _consumeTabQuery();
  }

  /// Mirrors `_CustomerHomeShellState._consumeTabQuery`: `/?tab=` is a one-shot
  /// command, dropped once applied so a later rebuild of `/` (a route pushed on
  /// top of the shell) can't re-read a stale query and stomp the current tab.
  void _consumeTabQuery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('shell-tab-$_index')),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _goToTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'cat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'cart',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'fav'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'me'),
        ],
      ),
    );
  }
}

/// `canPop() ? pop() : go('/')` — verbatim with ai_assistant_chat_screen.dart.
class _AiChatReplica extends StatelessWidget {
  const _AiChatReplica();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const Key('ai-back'),
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
      ),
      title: const Text('ai'),
    ),
    body: const Center(child: Text('ai-chat')),
  );
}

/// `canPop() ? pop() : go('/?tab=categories')` — verbatim with product_list_screen.
class _ProductListReplica extends StatelessWidget {
  const _ProductListReplica();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const Key('list-back'),
        icon: const Icon(Icons.arrow_back),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/?tab=categories'),
      ),
      title: const Text('list'),
    ),
    body: const Center(child: Text('product-list')),
  );
}

/// Mirrors [PreviewAppBar]'s customer back — [navigateProductDetailBack].
class _ProductDetailReplica extends StatelessWidget {
  const _ProductDetailReplica();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const Key('detail-back'),
        icon: const Icon(Icons.arrow_back),
        onPressed: () => navigateProductDetailBack(context),
      ),
      title: const Text('detail'),
    ),
    body: const Center(child: Text('product-detail')),
  );
}

/// `canPop() ? pop() : go('/')` — verbatim with support_chat_screen.dart's
/// `_handleBack`.
class _SupportReplica extends StatelessWidget {
  const _SupportReplica();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const Key('support-back'),
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
      ),
      title: const Text('support'),
    ),
    body: const Center(child: Text('support-screen')),
  );
}

void main() {
  testWidgets('AI chat back from Home returns to Home, NOT the Cart tab', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('shell-tab-0'), findsOneWidget);

    router.push('/ai-designer-chat');
    await tester.pumpAndSettle();
    expect(find.text('ai-chat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-back')));
    await tester.pumpAndSettle();

    expect(find.text('shell-tab-0'), findsOneWidget);
    expect(find.text('shell-tab-$_cartTab'), findsNothing);
  });

  testWidgets('Category back from Home returns to Home, NOT the Cart tab', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/product-list');
    await tester.pumpAndSettle();
    expect(find.text('product-list'), findsOneWidget);

    await tester.tap(find.byKey(const Key('list-back')));
    await tester.pumpAndSettle();

    expect(find.text('shell-tab-0'), findsOneWidget);
    expect(find.text('shell-tab-$_cartTab'), findsNothing);
  });

  testWidgets('Category back from the Categories tab returns to Categories', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Land on the Categories tab the way a deep-link would, then browse a
    // category and come back.
    router.go('/?tab=categories');
    await tester.pumpAndSettle();
    expect(find.text('shell-tab-1'), findsOneWidget);

    router.push('/product-list');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('list-back')));
    await tester.pumpAndSettle();

    expect(find.text('shell-tab-1'), findsOneWidget);
    expect(find.text('shell-tab-$_cartTab'), findsNothing);
  });

  testWidgets('AI chat cold deep-link back falls through to Home', (
    tester,
  ) async {
    // No `/` underneath (history-less entry): the standardized fallback must
    // land on Home rather than dead-ending — never on the Cart tab.
    final router = _router(initialLocation: '/ai-designer-chat');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('ai-chat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-back')));
    await tester.pumpAndSettle();

    expect(find.text('shell-tab-0'), findsOneWidget);
    expect(find.text('shell-tab-$_cartTab'), findsNothing);
  });

  // The bug report named these two screens specifically. They pop back to the
  // home shell (a sibling of `/`), so the shell's State — and `_index` — stays
  // mounted; the rebuilt `/` carries no `?tab=`, so the null-guard in
  // didUpdateWidget leaves the tab alone. These pin the deployment steps.
  testWidgets(
    'Product detail back from Home returns to Home, NOT the Cart tab',
    (tester) async {
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('shell-tab-0'), findsOneWidget);

      router.push('/product-detail/p1');
      await tester.pumpAndSettle();
      expect(find.text('product-detail'), findsOneWidget);

      await tester.tap(find.byKey(const Key('detail-back')));
      await tester.pumpAndSettle();

      expect(find.text('shell-tab-0'), findsOneWidget);
      expect(find.text('shell-tab-$_cartTab'), findsNothing);
    },
  );

  testWidgets(
    'Support back from the Profile tab returns to Profile, NOT the Cart tab',
    (tester) async {
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Land on Profile (tab 4) the way a deep-link / push tap would.
      router.go('/?tab=profile');
      await tester.pumpAndSettle();
      expect(find.text('shell-tab-4'), findsOneWidget);

      router.push('/support');
      await tester.pumpAndSettle();
      expect(find.text('support-screen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('support-back')));
      await tester.pumpAndSettle();

      expect(find.text('shell-tab-4'), findsOneWidget);
      expect(find.text('shell-tab-$_cartTab'), findsNothing);
    },
  );

  // The bug the StatefulShellBranch theory got wrong: `/support` is already a
  // top-level route, not nested in a tab branch. The real stomp needs a STALE
  // `?tab=` — the user reaches a tab via a deep-link/action (URL `?tab=cart`),
  // then MANUALLY taps a different tab (shell-local setState; the URL stays
  // `?tab=cart`), then opens support. Pushing `/support` re-runs the `/`
  // builder, which re-reads the stale `?tab=cart` and — without the one-shot
  // consume — switches the shell to Cart. Back then strands the user on Cart.
  testWidgets(
    'Support back after a manual tab switch returns to the manual tab, NOT a '
    'stale ?tab= tab',
    (tester) async {
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Arrive on Cart via a deep-link/action (e.g. "View cart" after an
      // add-to-cart). The location is now `/?tab=cart`.
      router.go('/?tab=cart');
      await tester.pumpAndSettle();
      expect(find.text('shell-tab-$_cartTab'), findsOneWidget);

      // User manually taps the Profile tab — shell-local setState, the URL is
      // left as the now-stale `/?tab=cart`.
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      expect(find.text('shell-tab-4'), findsOneWidget);

      // Open support, then come back.
      router.push('/support');
      await tester.pumpAndSettle();
      expect(find.text('support-screen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('support-back')));
      await tester.pumpAndSettle();

      // Must land on Profile (the manual tab), never the stale Cart tab.
      expect(find.text('shell-tab-4'), findsOneWidget);
      expect(find.text('shell-tab-$_cartTab'), findsNothing);
    },
  );

  testWidgets('Support cold deep-link back falls through to Home', (
    tester,
  ) async {
    // Push-tap into support with no `/` underneath: the fallback lands on Home,
    // never the Cart tab.
    final router = _router(initialLocation: '/support');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('support-screen'), findsOneWidget);

    await tester.tap(find.byKey(const Key('support-back')));
    await tester.pumpAndSettle();

    expect(find.text('shell-tab-0'), findsOneWidget);
    expect(find.text('shell-tab-$_cartTab'), findsNothing);
  });

  testWidgets('Product share cold deep-link back falls through to Home', (
    tester,
  ) async {
    final router = _router(initialLocation: '/product-detail/p1');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('product-detail'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-back')));
    await tester.pumpAndSettle();

    expect(find.text('shell-tab-0'), findsOneWidget);
    expect(find.text('product-detail'), findsNothing);
  });
}

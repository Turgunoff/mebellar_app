import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
/// The back-button code is copied verbatim from the screens — both use the
/// standardized `canPop() ? pop() : go(...)` pattern:
///   * AI chat → `canPop() ? pop() : go('/')`;
///   * product-list → `canPop() ? pop() : go('/?tab=categories')`.
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

  void _goToTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  void didUpdateWidget(_ShellReplica oldWidget) {
    super.didUpdateWidget(oldWidget);
    final requested = widget.initialTab;
    if (requested != null && requested != _index) _goToTab(requested);
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
}

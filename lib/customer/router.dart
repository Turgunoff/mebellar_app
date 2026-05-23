import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../config/app_mode.dart';
import '../core/di/service_locator.dart';
import '../shared/models/supabase_product_model.dart';
import '../shared/chat/screens/chat_thread_screen.dart';
import '../shared/chat/screens/chats_list_screen.dart';
import '../shared/models/chat.dart';
import '../shared/repositories/supabase_category_repository.dart';
import '../shared/repositories/supabase_product_data_source.dart';
import '../core/logging/console_nav_observer.dart';
import '../core/logging/talker.dart';
import '../shared/models/cart_item_model.dart';
import '../shared/widgets/brand_refresh_indicator.dart';
import '../shared/widgets/notification_simulator_screen.dart';
import '../shared/widgets/notifications_screen.dart';
import 'customer_app.dart';
import 'features/broadcasts/screens/broadcast_placeholder_screen.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/catalog/screens/catalog_screen.dart';
import 'features/categories/screens/categories_screen.dart';
import 'features/product_list/cubit/product_list_cubit.dart';
import 'features/product_list/screens/product_list_screen.dart';
import 'features/product_list/screens/supabase_product_detail_screen.dart';
import 'features/checkout/screens/checkout_screen.dart';
import 'features/favorites/screens/favorites_screen.dart';
import 'features/orders/screens/order_detail_screen.dart';
import 'features/orders/screens/orders_history_screen.dart';
import 'features/product_detail/screens/product_detail_screen.dart';
import 'features/profile/addresses/screens/addresses_screen.dart';
import 'features/notifications/screens/notifications_screen.dart' as customer_notifications;
import 'features/search/screens/search_screen.dart';
import 'features/tutorial/tutorial_screen.dart';
import '../seller/features/onboarding/screens/onboarding_screen.dart';

/// Customer-side navigation. The shell hosts the bottom tabs; the rest are
/// pushed on top via `context.push(...)`. Filters propagate via query params
/// so deep links like `/catalog?category=sofas` reproduce the same state.
GoRouter buildCustomerRouter() {
  return GoRouter(
    initialLocation: '/',
    navigatorKey: customerNavigatorKey,
    observers: [TalkerRouteObserver(talker), ConsoleNavObserver()],
    // First-launch onboarding gate. Runs on every navigation: if the user
    // hasn't completed the tutorial, route them to `/tutorial` regardless of
    // the intended destination. This replaces an earlier imperative push that
    // raced with the Navigator's mount order under `_ModeRouter`'s crossfade
    // and silently no-op'd when `navigatorKey.currentState` was momentarily
    // null.
    redirect: (context, state) {
      final atTutorial = state.matchedLocation == '/tutorial';
      if (!isTutorialSeen() && !atTutorial) return '/tutorial';
      if (isTutorialSeen() && atTutorial) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const CustomerHomeShell(),
      ),
      GoRoute(
        path: '/tutorial',
        builder: (context, state) => CustomerTutorialScreen(
          onDone: () => context.go('/'),
        ),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/catalog',
        builder: (context, state) => CatalogScreen(
          categorySlug: state.uri.queryParameters['category'],
          search: state.uri.queryParameters['search'],
        ),
      ),
      GoRoute(
        path: '/product-list',
        builder: (context, state) {
          final categoryId = state.uri.queryParameters['categoryId'] ?? '';
          final subcategoryId = state.uri.queryParameters['subcategoryId'];
          final categoryName =
              state.uri.queryParameters['categoryName'] ?? 'Products';
          return BlocProvider(
            create: (_) => ProductListCubit(
              sl<SupabaseProductDataSource>(),
              sl<CategoryDataSource>(),
            )..load(categoryId: categoryId, subcategoryId: subcategoryId),
            child: ProductListScreen(
              categoryId: categoryId,
              subcategoryId: subcategoryId,
              categoryName: categoryName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/product-detail/:id',
        builder: (context, state) {
          final product = state.extra as SupabaseProductModel?;
          if (product != null) return SupabaseProductDetailScreen(product: product);
          return _ProductDetailLoader(id: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => ChatsListScreen(
          viewer: ChatSenderRole.customer,
          threadRouteBuilder: (c) => '/chats/${c.id}',
        ),
      ),
      // Open by chat id — used from the chat list.
      GoRoute(
        path: '/chats/:chatId',
        builder: (context, state) => ChatThreadScreen(
          viewer: ChatSenderRole.customer,
          chatId: state.pathParameters['chatId']!,
          onOpenOrder: (orderId) =>
              context.push('/orders/$orderId'),
        ),
      ),
      // Open by order id — lazily creates the chat row if needed. Used
      // from the order detail screen so the customer can DM the seller
      // without first hopping through the chat list.
      GoRoute(
        path: '/orders/:orderId/chat',
        builder: (context, state) => ChatThreadScreen(
          viewer: ChatSenderRole.customer,
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: '/products/:slug',
        builder: (context, state) =>
            ProductDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final items = state.extra as List<CartItemModel>?;
          if (items == null || items.isEmpty) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Text('Savatch bo\'sh — orqaga qayting'),
              ),
            );
          }
          return CheckoutScreen(items: items);
        },
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersHistoryScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile/addresses',
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: '/seller/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) =>
            const NotificationsScreen(mode: AppMode.customer),
      ),
      // ---- Broadcast deep-link placeholders -------------------------------
      // Promo / news / system-alert notifications resolve to these routes
      // via `determineRouteFor` in notifications_screen.dart. Until the
      // dedicated screens land, all three share `BroadcastPlaceholderScreen`
      // — see its dartdoc for the rationale. Two GoRoutes per kind (with
      // and without id) so the routing helper's payload-id fallback still
      // resolves cleanly.
      GoRoute(
        path: '/promo',
        builder: (context, state) =>
            const BroadcastPlaceholderScreen(kind: BroadcastKind.promo),
      ),
      GoRoute(
        path: '/promo/:id',
        builder: (context, state) => BroadcastPlaceholderScreen(
          kind: BroadcastKind.promo,
          referenceId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/news',
        builder: (context, state) =>
            const BroadcastPlaceholderScreen(kind: BroadcastKind.news),
      ),
      GoRoute(
        path: '/news/:id',
        builder: (context, state) => BroadcastPlaceholderScreen(
          kind: BroadcastKind.news,
          referenceId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/system-alert',
        builder: (context, state) => const BroadcastPlaceholderScreen(
          kind: BroadcastKind.systemAlert,
        ),
      ),
      GoRoute(
        path: '/customer/notifications',
        builder: (context, state) =>
            const customer_notifications.NotificationsScreen(),
      ),
      GoRoute(
        path: '/debug/notifications',
        builder: (context, state) =>
            const NotificationSimulatorScreen(currentMode: AppMode.customer),
      ),
    ],
  );
}

class _ProductDetailLoader extends StatelessWidget {
  const _ProductDetailLoader({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SupabaseProductModel>(
      future: sl<SupabaseProductDataSource>().getById(id),
      builder: (context, snap) {
        if (snap.hasData) {
          return SupabaseProductDetailScreen(product: snap.data!);
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(snap.error.toString())),
          );
        }
        return const Scaffold(
          body: Center(child: BrandLoadingIndicator()),
        );
      },
    );
  }
}


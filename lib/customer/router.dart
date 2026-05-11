import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../config/app_mode.dart';
import '../core/di/service_locator.dart';
import '../shared/models/supabase_product_model.dart';
import '../shared/repositories/supabase_product_data_source.dart';
import '../core/logging/console_nav_observer.dart';
import '../core/logging/talker.dart';
import '../shared/models/cart.dart';
import '../shared/widgets/notification_simulator_screen.dart';
import '../shared/widgets/notifications_screen.dart';
import 'customer_app.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/catalog/screens/catalog_screen.dart';
import 'features/categories/screens/categories_screen.dart';
import 'features/product_list/cubit/product_list_cubit.dart';
import 'features/product_list/screens/product_list_screen.dart';
import 'features/product_list/screens/supabase_product_detail_screen.dart';
import 'features/checkout/screens/checkout_screen.dart';
import 'features/favorites/screens/favorites_screen.dart';
import 'features/orders/screens/order_detail_screen.dart';
import 'features/orders/screens/orders_screen.dart';
import 'features/product_detail/screens/product_detail_screen.dart';
import 'features/profile/addresses/screens/addresses_screen.dart';
import 'features/notifications/screens/notifications_screen.dart' as customer_notifications;
import 'features/search/screens/search_screen.dart';
import '../seller/features/onboarding/screens/onboarding_screen.dart';

/// Customer-side navigation. The shell hosts the bottom tabs; the rest are
/// pushed on top via `context.push(...)`. Filters propagate via query params
/// so deep links like `/catalog?category=sofas` reproduce the same state.
GoRouter buildCustomerRouter() {
  return GoRouter(
    initialLocation: '/',
    navigatorKey: customerNavigatorKey,
    observers: [TalkerRouteObserver(talker), ConsoleNavObserver()],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const CustomerHomeShell(),
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
            create: (_) => ProductListCubit(sl<SupabaseProductDataSource>())
              ..load(categoryId: categoryId, subcategoryId: subcategoryId),
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
          final cart = state.extra as Cart?;
          if (cart == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Text('Cart kerak — savatchadan ochiling'),
              ),
            );
          }
          return CheckoutScreen(cart: cart);
        },
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
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
      GoRoute(
        path: '/shops/:slug',
        builder: (context, state) => _PlaceholderRoute(
          title: 'Shop: ${state.pathParameters['slug']}',
          subtitle: 'Sprint 6+: shop detail screen',
        ),
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
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _PlaceholderRoute extends StatelessWidget {
  const _PlaceholderRoute({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

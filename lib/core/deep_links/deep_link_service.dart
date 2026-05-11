import 'dart:async';

import '../../config/app_mode.dart';

/// Parsed deep-link target — repackaged so the customer/seller shell can
/// route on it without re-parsing URIs in the widget layer.
class DeepLinkTarget {
  const DeepLinkTarget({required this.mode, required this.route});
  final AppMode mode;
  final String route;
}

/// Sprint 11 polish: parses universal/app links into a `(mode, route)` pair
/// the shell can act on. The mock variant exposes a `simulate(uri)` hook
/// for the dev panel; production wiring (`uni_links` or
/// `app_links` package) lands in Sprint 12 alongside the
/// `apple-app-site-association` / `assetlinks.json` deploy.
abstract class DeepLinkService {
  Stream<DeepLinkTarget> watch();

  /// Inspects an incoming URI string and emits a target on the watch stream
  /// when it matches one of the known patterns.
  void handleUri(String uri);

  Future<void> dispose();
}

class MockDeepLinkService implements DeepLinkService {
  MockDeepLinkService();

  final _controller = StreamController<DeepLinkTarget>.broadcast();

  @override
  Stream<DeepLinkTarget> watch() => _controller.stream;

  @override
  void handleUri(String input) {
    final target = parse(input);
    if (target != null && !_controller.isClosed) {
      _controller.add(target);
    }
  }

  /// Pure helper — exposed `static` so widget tests can assert routing rules
  /// without spinning up the service.
  static DeepLinkTarget? parse(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null) return null;

    // Accepted forms:
    //   mebellar://orders/abc-123
    //   https://mebellar-olami.uz/orders/abc-123
    //   https://mebellar-olami.uz/seller/products/sp-7
    final isAppScheme = uri.scheme == 'mebellar';
    final isWebHost = uri.scheme == 'https' && uri.host == 'mebellar-olami.uz';
    if (!isAppScheme && !isWebHost) return null;

    // For app-scheme URIs the host carries the first segment (e.g.
    // `mebellar://orders/abc` parses with host=orders, path=/abc).
    final segments = isAppScheme
        ? <String>[uri.host, ...uri.pathSegments]
        : uri.pathSegments;
    if (segments.isEmpty) return null;

    final first = segments.first;

    // Seller routes carry an explicit `seller` prefix.
    if (first == 'seller') {
      final rest = segments.skip(1).join('/');
      return DeepLinkTarget(
        mode: AppMode.seller,
        route: '/seller/${rest.isEmpty ? '' : rest}',
      );
    }

    // Customer routes — orders, products, catalog, search, cart, favorites,
    // shops. Default fallback: anything we don't recognise lands on the
    // customer home so the user isn't dropped on a dead end.
    final knownCustomer = const {
      'orders',
      'products',
      'catalog',
      'search',
      'cart',
      'favorites',
      'shops',
      'profile',
      'notifications',
    };
    if (knownCustomer.contains(first)) {
      return DeepLinkTarget(
        mode: AppMode.customer,
        route: '/${segments.join('/')}'
            '${uri.query.isEmpty ? '' : '?${uri.query}'}',
      );
    }

    return const DeepLinkTarget(mode: AppMode.customer, route: '/');
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

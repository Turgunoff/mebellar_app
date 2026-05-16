import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

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
///
/// In addition to URI parsing, the service holds a single "pending route"
/// slot used to bridge a `Phoenix.rebirth` mode switch — when the user taps
/// an inbox notification that targets the *other* app mode, the routing
/// interceptor stashes the destination here and switches mode; the freshly
/// rebuilt app picks the route back up in its root `initState`.
abstract class DeepLinkService {
  Stream<DeepLinkTarget> watch();

  /// Inspects an incoming URI string and emits a target on the watch stream
  /// when it matches one of the known patterns.
  void handleUri(String uri);

  /// Stashes [path] so it survives the `Phoenix.rebirth` that follows a
  /// cross-mode notification tap. Overwrites any previously-stashed route
  /// — only one pending destination is supported at a time.
  void setPendingRoute(String path);

  /// Reads and clears the stashed route. Returns `null` when no pending
  /// route exists. Always clears, even on `null`, so a stale value from a
  /// previous session can't leak forward.
  String? consumePendingRoute();

  Future<void> dispose();
}

class MockDeepLinkService implements DeepLinkService {
  /// [pendingRouteBox] persists the stashed route across `Phoenix.rebirth`
  /// (and across cold starts triggered by a tray push). Pass `null` in
  /// tests to fall back to an in-process slot.
  MockDeepLinkService({Box? pendingRouteBox})
      : _pendingRouteBox = pendingRouteBox;

  final _controller = StreamController<DeepLinkTarget>.broadcast();
  final Box? _pendingRouteBox;

  /// Hive key used for the stashed route. Namespaced with a `dl_` prefix so
  /// it can't collide with the keys [NotificationHandler] writes into the
  /// same `pending_route` box (`pending_route` / `pending_mode` / ...).
  static const String _pendingRouteKey = 'dl_pending_path';

  /// Web hosts whose universal links this app claims. Every entry must also
  /// be listed in the Apple `apple-app-site-association` and Android
  /// `assetlinks.json` deploys. Both the bare apex and the `www.` host are
  /// accepted; the legacy `mebellar-olami.uz` is kept alongside the canonical
  /// `mebellar.uz` so links minted by older builds keep resolving.
  static const Set<String> _webHosts = {
    'mebellar.uz',
    'www.mebellar.uz',
    'mebellar-olami.uz',
    'www.mebellar-olami.uz',
  };

  /// Memory fallback used when no Hive box is wired (unit tests).
  String? _pendingRouteMem;

  @override
  Stream<DeepLinkTarget> watch() => _controller.stream;

  @override
  void handleUri(String input) {
    final target = parse(input);
    if (target != null && !_controller.isClosed) {
      _controller.add(target);
    }
  }

  @override
  void setPendingRoute(String path) {
    final box = _pendingRouteBox;
    if (box != null) {
      box.put(_pendingRouteKey, path);
    } else {
      _pendingRouteMem = path;
    }
  }

  @override
  String? consumePendingRoute() {
    final box = _pendingRouteBox;
    if (box != null) {
      final stored = box.get(_pendingRouteKey) as String?;
      box.delete(_pendingRouteKey);
      return stored;
    }
    final stored = _pendingRouteMem;
    _pendingRouteMem = null;
    return stored;
  }

  /// Pure helper — exposed `static` so widget tests can assert routing rules
  /// without spinning up the service.
  static DeepLinkTarget? parse(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null) return null;

    // Accepted forms:
    //   mebellar://orders/abc-123
    //   https://mebellar.uz/orders/abc-123
    //   https://mebellar.uz/seller/products/sp-7
    final isAppScheme = uri.scheme == 'mebellar';
    final isWebHost = uri.scheme == 'https' && _webHosts.contains(uri.host);
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

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Route pattern (not a resolved location) for the customer product detail
/// screen — see [buildCustomerRouter]'s `/product-detail/:id` GoRoute. go_router
/// stamps this exact pattern onto every pushed detail page's match, so it is the
/// stable key used to recognise a "rabbit hole" of stacked product details.
const String customerProductDetailPath = '/product-detail/:id';

/// Below this many stacked product details the system Back arrow already lands
/// on the origin in a single tap, so the escape hatch would be redundant. It
/// earns its place once the user is ≥2 products deep. Flip to 1 to always show.
const int _minRabbitHoleDepth = 2;

/// The "Context-Aware Escape Hatch" decision for the detail screen currently on
/// top of the stack.
///
/// The rabbit hole is the contiguous run of `/product-detail/:id` pages at the
/// top of the navigation stack (the user tapping recommendation after
/// recommendation). [popCount] is how many of them to pop to surface the first
/// *non-product* screen they came from ([originPath]) — the Category list
/// (`/product-list`), a Shop (`/shop/:id`), Search (`/search`), or the home shell
/// (`/`, which hosts the Home/Categories/Cart/Favorites/Profile tabs).
///
/// When the entire stack is product details (a cold deep-link straight into a
/// shared product, then a recommendation chain) there is no browsing origin to
/// return to, so [isHomeFallback] is set and the hatch routes to Home instead.
@immutable
class ProductEscapePlan {
  const ProductEscapePlan._({
    required this.popCount,
    required this.originPath,
    required this.isHomeFallback,
    required this.showHatch,
  });

  /// Number of `pop()`s to reach [originPath]. Zero when [isHomeFallback] (we
  /// `go('/')` instead) or when not on a product detail at all.
  final int popCount;

  /// Route *pattern* of the screen the hatch lands on (e.g. `/product-list`,
  /// `/shop/:id`, `/`). Null when [isHomeFallback].
  final String? originPath;

  /// True when the whole stack is product details and the hatch must fall back
  /// to Home rather than to a browsing origin.
  final bool isHomeFallback;

  /// Whether the detail screen should render the hatch button at all.
  final bool showHatch;
}

/// Pure core of the escape hatch — no `BuildContext`, no go_router instance, so
/// it is trivially unit-testable against a list of route patterns ordered
/// bottom → top (index 0 is the first/root screen, last is the screen on top).
ProductEscapePlan resolveProductEscapePlan(List<String> stackPaths) {
  var depth = 0;
  for (
    var i = stackPaths.length - 1;
    i >= 0 && stackPaths[i] == customerProductDetailPath;
    i--
  ) {
    depth++;
  }

  // Defensive: the hatch only ever renders on a product detail, so the top
  // should always be one. If it isn't, there is nothing to escape.
  if (depth == 0) {
    return const ProductEscapePlan._(
      popCount: 0,
      originPath: null,
      isHomeFallback: false,
      showHatch: false,
    );
  }

  // No non-product screen underneath the chain → Home fallback. Surfaced even
  // at depth 1 (a single deep-linked product), where Back would exit the app.
  if (depth >= stackPaths.length) {
    return const ProductEscapePlan._(
      popCount: 0,
      originPath: null,
      isHomeFallback: true,
      showHatch: true,
    );
  }

  return ProductEscapePlan._(
    popCount: depth,
    originPath: stackPaths[stackPaths.length - depth - 1],
    isHomeFallback: false,
    showHatch: depth >= _minRabbitHoleDepth,
  );
}

/// The icon + i18n tooltip key the hatch wears, chosen from where it will land
/// so the affordance reads correctly.
///
/// Only screens reached by a real `push` carry a route pattern we can name — the
/// Category list (`/product-list`), a Shop (`/shop/:id`) and Search (`/search`).
/// The five bottom-nav tabs (Home, Categories, Cart, Favorites, Profile) all live
/// inside the single `/` shell as an `IndexedStack`, so a rabbit hole started
/// from any of them resolves to origin `/` — we can't tell *which* tab without
/// coupling to the shell's state, so it gets a neutral "back to browsing" look
/// rather than a tab-specific (and possibly wrong) one. The pop still lands the
/// user on the exact tab they left (the IndexedStack keeps it alive).
@immutable
class EscapeHatchLook {
  const EscapeHatchLook(this.icon, this.tooltipKey);

  final IconData icon;

  /// Dot-namespaced translation key — resolve with `tr(...)` at the call site
  /// (keeping this file widget/i18n-runtime free for easy testing).
  final String tooltipKey;
}

EscapeHatchLook escapeHatchLook(ProductEscapePlan plan) {
  if (plan.isHomeFallback) {
    return const EscapeHatchLook(Iconsax.home_2, 'product.back_home');
  }
  return switch (plan.originPath) {
    '/product-list' => const EscapeHatchLook(
      Iconsax.category,
      'product.back_to_list',
    ),
    '/shop/:id' => const EscapeHatchLook(Iconsax.shop, 'product.back_to_shop'),
    '/search' => const EscapeHatchLook(
      Iconsax.search_normal,
      'product.back_to_results',
    ),
    // '/' (any home-shell tab) and any other origin: a neutral, never-wrong
    // "back to browsing" affordance.
    _ => const EscapeHatchLook(Iconsax.element_3, 'product.back_to_browsing'),
  };
}

/// The stack of route *patterns* (bottom → top) currently held by the customer
/// router. Shell matches (none in the customer router today) collapse to '' and
/// simply never match the product pattern.
List<String> currentStackPaths(BuildContext context) {
  final config = GoRouter.of(context).routerDelegate.currentConfiguration;
  return [
    for (final match in config.matches)
      if (match.route case final GoRoute route) route.path else '',
  ];
}

/// Reads the live stack and returns the plan for the screen on top. Use this for
/// the AppBar's icon/visibility.
ProductEscapePlan planProductEscape(BuildContext context) =>
    resolveProductEscapePlan(currentStackPaths(context));

/// Executes the escape: collapses the rabbit hole back to its browsing origin by
/// popping the stacked detail pages (preserving the origin screen's existing
/// state), or routes Home when there is no origin to return to.
///
/// Re-resolves against the *live* stack at tap time so it is always correct even
/// if the cached visual plan was computed at an earlier build.
void escapeProductRabbitHole(BuildContext context) {
  final router = GoRouter.of(context);
  final plan = resolveProductEscapePlan(currentStackPaths(context));

  if (plan.isHomeFallback) {
    router.go('/');
    return;
  }
  // Popping (vs. go) keeps the origin's Bloc/scroll state intact. Each pop is
  // guarded so we can never pop past the origin, even under a racing rebuild.
  for (var i = 0; i < plan.popCount && router.canPop(); i++) {
    router.pop();
  }
}

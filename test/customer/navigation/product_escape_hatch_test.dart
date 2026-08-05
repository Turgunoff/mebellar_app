import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/customer/navigation/product_escape_hatch.dart';

void main() {
  const pd = customerProductDetailPath; // '/product-detail/:id'

  group('resolveProductEscapePlan', () {
    test('rabbit hole from a category list pops back to the list', () {
      // home → list → A → B → C  (3 deep)
      final plan = resolveProductEscapePlan(['/', '/product-list', pd, pd, pd]);

      expect(plan.popCount, 3);
      expect(plan.originPath, '/product-list');
      expect(plan.isHomeFallback, isFalse);
      expect(plan.showHatch, isTrue);
    });

    test('rabbit hole from a shop profile pops back to the shop', () {
      final plan = resolveProductEscapePlan(['/', '/shop/:id', pd, pd]);

      expect(plan.popCount, 2);
      expect(plan.originPath, '/shop/:id');
      expect(plan.showHatch, isTrue);
    });

    test('rabbit hole started from Home returns to Home (popped, not go)', () {
      final plan = resolveProductEscapePlan(['/', pd, pd, pd]);

      expect(plan.popCount, 3);
      expect(plan.originPath, '/');
      expect(plan.isHomeFallback, isFalse);
    });

    test(
      'only the contiguous top run counts — a shop mid-chain is the origin',
      () {
        // list → A → shop → B → C : escape should land on the shop, not the list
        final plan = resolveProductEscapePlan([
          '/',
          '/product-list',
          pd,
          '/shop/:id',
          pd,
          pd,
        ]);

        expect(plan.popCount, 2);
        expect(plan.originPath, '/shop/:id');
      },
    );

    test(
      'depth 1 with a real origin hides the hatch (Back already suffices)',
      () {
        final plan = resolveProductEscapePlan(['/', '/product-list', pd]);

        expect(plan.popCount, 1);
        expect(plan.originPath, '/product-list');
        expect(plan.showHatch, isFalse);
      },
    );

    test(
      'whole stack is product details → Home fallback, shown even at depth 1',
      () {
        // Cold deep-link straight into a shared product.
        final single = resolveProductEscapePlan([pd]);
        expect(single.isHomeFallback, isTrue);
        expect(single.popCount, 0);
        expect(single.originPath, isNull);
        expect(single.showHatch, isTrue);

        // Deep-link then a recommendation chain.
        final chain = resolveProductEscapePlan([pd, pd, pd]);
        expect(chain.isHomeFallback, isTrue);
        expect(chain.popCount, 0);
        expect(chain.showHatch, isTrue);
      },
    );

    test('not on a product detail → nothing to escape, hatch hidden', () {
      final plan = resolveProductEscapePlan(['/', '/product-list']);

      expect(plan.popCount, 0);
      expect(plan.showHatch, isFalse);
      expect(plan.isHomeFallback, isFalse);
    });

    test('search origin (a real standalone push) resolves correctly', () {
      expect(
        resolveProductEscapePlan(['/', '/search', pd, pd]).originPath,
        '/search',
      );
    });

    test(
      'in-shell-tab dive (Home/Favorites/Cart) resolves to the / shell origin',
      () {
        // The bottom-nav tabs live inside the single `/` shell, so a rabbit
        // hole started from any of them sits directly on `/` — there is no
        // `/favorites` (etc.) entry in the real stack.
        final plan = resolveProductEscapePlan(['/', pd, pd]);

        expect(plan.originPath, '/');
        expect(plan.popCount, 2);
        expect(plan.isHomeFallback, isFalse);
        expect(plan.showHatch, isTrue);
      },
    );
  });

  group('escapeHatchLook', () {
    EscapeHatchLook lookFrom(List<String> stack) =>
        escapeHatchLook(resolveProductEscapePlan(stack));

    test('icon + tooltip key adapt to the origin', () {
      expect(lookFrom(['/', '/product-list', pd, pd]).icon, Iconsax.category);
      expect(
        lookFrom(['/', '/product-list', pd, pd]).tooltipKey,
        'product.back_to_list',
      );

      expect(lookFrom(['/', '/shop/:id', pd, pd]).icon, Iconsax.shop);
      expect(
        lookFrom(['/', '/shop/:id', pd, pd]).tooltipKey,
        'product.back_to_shop',
      );

      expect(lookFrom(['/', '/search', pd, pd]).icon, Iconsax.search_normal);
    });

    test('home fallback (deep-link only) wears the Home affordance', () {
      final look = lookFrom([pd, pd]);
      expect(look.icon, Iconsax.home_2);
      expect(look.tooltipKey, 'product.back_home');
    });

    test('in-shell-tab origin (/) gets the neutral browsing affordance, '
        'not a (possibly-wrong) tab-specific one', () {
      final look = lookFrom(['/', pd, pd]);
      expect(look.icon, Iconsax.home_2_copy);
      expect(look.tooltipKey, 'product.back_to_browsing');
    });

    test('unknown origin gets the generic browsing affordance', () {
      final look = lookFrom(['/', '/orders/:id', pd, pd]);
      expect(look.icon, Iconsax.home_2_copy);
      expect(look.tooltipKey, 'product.back_to_browsing');
    });
  });
}

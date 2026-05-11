import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/cart_item_model.dart';
import '../../../widgets/glass_bottom_nav.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../bloc/cart_bloc.dart';

/// Customer-facing cart (Savatcha).
///
/// Renders the live snapshot rows held by [CartBloc] and dispatches
/// `UpdateQuantity` / `RemoveFromCart` / `ClearCart` events. The bottom
/// sticky panel shows `totalPrice` formatted as `#,##0 UZS` and a
/// "Rasmiylashtirish" button which navigates the user to the checkout
/// route — checkout itself is wired in a separate sprint.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ColoredBox(
      color: pt.background,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<CartBloc, CartState>(
          builder: (context, state) {
            if (state.status == CartStatus.loading && state.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.isEmpty) {
              return const _CartEmptyState();
            }
            return Column(
              children: [
                _CartHeader(itemCount: state.totalUnits),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = state.items[i];
                      return _CartItemRow(
                        item: item,
                        onIncrement: () => context.read<CartBloc>().add(
                              UpdateQuantity(
                                productId: item.productId,
                                newQuantity: item.quantity + 1,
                              ),
                            ),
                        onDecrement: () => context.read<CartBloc>().add(
                              UpdateQuantity(
                                productId: item.productId,
                                newQuantity: item.quantity - 1,
                              ),
                            ),
                        onRemove: () => context.read<CartBloc>().add(
                              RemoveFromCart(item.productId),
                            ),
                      );
                    },
                  ),
                ),
                _StickyCheckout(
                  totalPrice: state.totalPrice,
                  onCheckout: () => _onCheckout(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onCheckout(BuildContext context) {
    HapticFeedback.lightImpact();
    // Checkout integration with the new snapshot model is tracked separately;
    // for now the button confirms the intent so the flow is testable.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('cart.checkout_placeholder')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              tr('cart.title'),
              style: PremiumTokens.display(size: 32, letterSpacing: -0.6),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              tr('cart.units_count', args: ['$itemCount']),
              style: PremiumTokens.body(
                size: 13,
                color: pt.grey,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cart row ───────────────────────────────────────────────────────────────

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItemModel item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PremiumTokens.softShadow,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              color: pt.imageBg,
              child: item.productImage.isEmpty
                  ? Icon(Iconsax.gallery_slash, color: pt.greyLight)
                  : CachedNetworkImage(
                      imageUrl: item.productImage,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: pt.imageBg),
                      errorWidget: (_, _, _) => Icon(
                        Iconsax.gallery_slash,
                        color: pt.greyLight,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkResponse(
                      onTap: onRemove,
                      radius: 18,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Iconsax.trash,
                          size: 18,
                          color: pt.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatPrice(item.productPrice)} UZS',
                  style: PremiumTokens.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: PremiumTokens.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QuantityStepper(
                      value: item.quantity,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
                    const Spacer(),
                    Text(
                      '${_formatPrice(item.lineTotal)} UZS',
                      style: PremiumTokens.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: pt.dark,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final canDecrement = value > 1;
    return Container(
      decoration: BoxDecoration(
        color: pt.imageBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Iconsax.minus,
            onTap: canDecrement ? onDecrement : null,
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: PremiumTokens.body(
                size: 13,
                weight: FontWeight.w600,
              ),
            ),
          ),
          _StepperButton(icon: Iconsax.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final disabled = onTap == null;
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 14,
          color: disabled ? pt.greyLight : pt.dark,
        ),
      ),
    );
  }
}

// ── Sticky checkout ────────────────────────────────────────────────────────

class _StickyCheckout extends StatelessWidget {
  const _StickyCheckout({
    required this.totalPrice,
    required this.onCheckout,
  });

  final double totalPrice;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -4),
            blurRadius: 18,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: GlassBottomNav.reservedHeight(context) + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('cart.grand_total'),
                  style: PremiumTokens.body(size: 13, color: pt.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatPrice(totalPrice)} UZS',
                  style: PremiumTokens.display(size: 22, letterSpacing: -0.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 52,
            child: Material(
              color: PremiumTokens.accent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onCheckout,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr('cart.checkout'),
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Iconsax.arrow_right_1,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _CartEmptyState extends StatelessWidget {
  const _CartEmptyState();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final bottomPad = GlassBottomNav.reservedHeight(context) + 24;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: Text(
            tr('cart.title'),
            style: PremiumTokens.display(size: 32, letterSpacing: -0.6),
          ),
        ),
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: pt.surface,
              shape: BoxShape.circle,
              boxShadow: PremiumTokens.softShadow,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Iconsax.shopping_bag,
              size: 64,
              color: PremiumTokens.accent,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          tr('cart.empty'),
          textAlign: TextAlign.center,
          style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
        ),
        const SizedBox(height: 12),
        Text(
          tr('cart.empty_hint'),
          textAlign: TextAlign.center,
          style: PremiumTokens.body(
            size: 14,
            color: pt.grey,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// `#,##0` formatter without depending on intl in this widget tree. Matches
/// the formatting used elsewhere in the catalog UI ("3,500,000 UZS").
String _formatPrice(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

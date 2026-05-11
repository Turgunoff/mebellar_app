import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../auth/auth_bottom_sheet.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/cart_item_model.dart';
import '../../../../shared/widgets/premium_empty_state.dart';
import '../../../customer_app.dart';
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
      child: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state.status == CartStatus.loading && state.items.isEmpty) {
            return const SafeArea(
              bottom: false,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state.isEmpty) {
            return SafeArea(
              bottom: false,
              child: PremiumEmptyState(
                icon: Iconsax.shopping_bag,
                title: "Savatchangiz bo'sh",
                subtitle:
                    "Katalogga o'tib, o'zingizga yoqqan premium mebellarni xarid qiling.",
                buttonText: "Katalogga o'tish",
                onButtonPressed: () =>
                    CustomerShellScope.of(context).goToTab(0),
                bottomPadding: GlassBottomNav.reservedHeight(context) + 24,
              ),
            );
          }
          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 120.0,
                    backgroundColor: pt.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: false,
                      expandedTitleScale: 1.6,
                      titlePadding: const EdgeInsetsDirectional.only(
                        start: 20,
                        bottom: 14,
                      ),
                      title: Text(
                        tr('cart.title'),
                        style: PremiumTokens.display(
                          size: 20,
                          letterSpacing: -0.4,
                        ),
                      ),
                      background: Container(
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.only(left: 20, bottom: 52),
                        child: Text(
                          tr('cart.units_count',
                              args: ['${state.totalUnits}']),
                          style: PremiumTokens.body(size: 13, color: pt.grey),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final item = state.items[i];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: i < state.items.length - 1 ? 12 : 0,
                            ),
                            child: _CartItemRow(
                              item: item,
                              onIncrement: () =>
                                  context.read<CartBloc>().add(
                                        UpdateQuantity(
                                          productId: item.productId,
                                          newQuantity: item.quantity + 1,
                                        ),
                                      ),
                              onDecrement: () =>
                                  context.read<CartBloc>().add(
                                        UpdateQuantity(
                                          productId: item.productId,
                                          newQuantity: item.quantity - 1,
                                        ),
                                      ),
                              onRemove: () => context.read<CartBloc>().add(
                                    RemoveFromCart(item.productId),
                                  ),
                            ),
                          );
                        },
                        childCount: state.items.length,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StickyCheckout(
                  totalPrice: state.totalPrice,
                  onCheckout: () => _onCheckout(context, state.items),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onCheckout(BuildContext context, List<CartItemModel> items) {
    HapticFeedback.lightImpact();
    final authState = context.read<AuthCubit>().state;
    if (authState is AppAuthUnauthenticated) {
      showAuthBottomSheet(context);
      return;
    }
    context.push('/checkout', extra: items);
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

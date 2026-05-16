import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../home/widgets/premium/premium_tokens.dart';
import '../../orders/cubit/profile_orders_cubit.dart';

/// Orders quick-access block — four status tiles plus a "see all" link.
class OrdersBlock extends StatelessWidget {
  const OrdersBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return BlocBuilder<ProfileOrdersCubit, ProfileOrdersState>(
      builder: (context, ordersState) {
        return Container(
          decoration: BoxDecoration(
            color: pt.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: PremiumTokens.softShadow,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Buyurtmalarim',
                        style: PremiumTokens.body(
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/orders'),
                      style: TextButton.styleFrom(
                        foregroundColor: PremiumTokens.accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Barchasi',
                            style: PremiumTokens.body(
                              size: 13,
                              weight: FontWeight.w600,
                              color: PremiumTokens.accent,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Iconsax.arrow_right_3,
                            size: 14,
                            color: PremiumTokens.accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: _OrderStatusTile(
                        icon: Iconsax.clock,
                        label: 'Kutilmoqda',
                        count: ordersState.pendingCount,
                        onTap: () => context.push('/orders'),
                      ),
                    ),
                    Expanded(
                      child: _OrderStatusTile(
                        icon: Iconsax.box_1,
                        label: 'Tayyorlanmoqda',
                        count: ordersState.processingCount,
                        onTap: () => context.push('/orders'),
                      ),
                    ),
                    Expanded(
                      child: _OrderStatusTile(
                        icon: Iconsax.box_time,
                        label: "Yo'lda",
                        count: ordersState.deliveringCount,
                        onTap: () => context.push('/orders'),
                      ),
                    ),
                    Expanded(
                      child: _OrderStatusTile(
                        icon: Iconsax.tick_circle,
                        label: 'Yetkazilgan',
                        count: 0,
                        showCount: false,
                        onTap: () => context.push('/orders'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderStatusTile extends StatelessWidget {
  const _OrderStatusTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.showCount = true,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: pt.imageBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: pt.dark),
                ),
                if (showCount && count > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: PremiumTokens.accent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: pt.surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: PremiumTokens.body(
                          size: 10,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: PremiumTokens.body(size: 11, color: pt.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

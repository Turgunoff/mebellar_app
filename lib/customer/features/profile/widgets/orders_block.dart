import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../home/widgets/premium/premium_tokens.dart';
import '../../orders/cubit/profile_orders_cubit.dart';

/// Orders entry point on the profile screen — a single tappable card that
/// opens the full orders screen. The per-status breakdown lives there (behind
/// filter tabs), so this block only surfaces a one-line activity summary.
class OrdersBlock extends StatelessWidget {
  const OrdersBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return BlocBuilder<ProfileOrdersCubit, ProfileOrdersState>(
      builder: (context, state) {
        final activeCount = state.pendingCount +
            state.processingCount +
            state.deliveringCount;
        final total = state.orders.length;

        final (String subtitle, bool highlight) = switch (activeCount) {
          > 0 => ('$activeCount ta faol buyurtma', true),
          _ when total > 0 => ('Jami $total ta buyurtma', false),
          _ => ("Hali buyurtma yo'q", false),
        };

        return Container(
          decoration: BoxDecoration(
            color: pt.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: PremiumTokens.softShadow,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/orders'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: PremiumTokens.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Iconsax.bag_2,
                        size: 22,
                        color: PremiumTokens.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buyurtmalarim',
                            style: PremiumTokens.body(
                              size: 15,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: PremiumTokens.body(
                              size: 12.5,
                              weight: highlight
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: highlight
                                  ? PremiumTokens.accent
                                  : pt.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Iconsax.arrow_right_3,
                      size: 18,
                      color: pt.greyLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

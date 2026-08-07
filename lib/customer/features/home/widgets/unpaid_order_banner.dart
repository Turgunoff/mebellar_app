import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../orders/cubit/unpaid_order_cubit.dart';
import '../../orders/widgets/payment_countdown.dart';
import '../../../../core/theme/premium_tokens.dart';

class UnpaidOrderBanner extends StatelessWidget {
  const UnpaidOrderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UnpaidOrderCubit, UnpaidOrderState>(
      builder: (context, state) {
        final order = state.order;
        final receivedAt = state.receivedAt;
        if (order == null ||
            receivedAt == null ||
            order.paymentExpiresAt == null ||
            !order.awaitsOnlinePayment) {
          return const SizedBox.shrink();
        }
        final pt = PremiumTokens.of(context);
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: pt.warningBg,
            elevation: 0,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => context.push('/orders/${order.id}'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pt.onWarningBg.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: PaymentCountdown(
                        expiresAt: order.paymentExpiresAt!,
                        receivedAt: receivedAt,
                        onExpired: () =>
                            context.read<UnpaidOrderCubit>().clear(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                        labelBuilder: (time) =>
                            tr('orders.payment_countdown_label', args: [time]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => context.push('/orders/${order.id}'),
                      child: Text(tr('orders.home_unpaid_banner_pay')),
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

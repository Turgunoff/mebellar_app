// ignore_for_file: deprecated_member_use
// RadioListTile groupValue/onChanged are deprecated in favour of RadioGroup
// ancestor (Flutter 3.32+). Sprint 11 polish will migrate; the deprecated
// API still works correctly for V1.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/cart.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/repositories/address_repository.dart';
import '../../../../shared/repositories/cart_repository.dart';
import '../../../../shared/repositories/order_repository.dart';
import '../../profile/addresses/bloc/addresses_bloc.dart';
import '../../profile/addresses/screens/address_edit_screen.dart';
import '../bloc/checkout_bloc.dart';
import '../widgets/checkout_step_indicator.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => CheckoutBloc(
            orderRepo: sl<OrderRepository>(),
            addressRepo: sl<AddressRepository>(),
            cartRepo: sl<CartRepository>(),
          )..add(CheckoutStarted(cart)),
        ),
        BlocProvider(
          create: (_) => AddressesBloc(sl<AddressRepository>())
            ..add(const AddressesRequested()),
        ),
      ],
      child: const _CheckoutView(),
    );
  }
}

class _CheckoutView extends StatelessWidget {
  const _CheckoutView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckoutBloc, CheckoutState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == CheckoutStatus.success ||
            state.status == CheckoutStatus.partialFailure ||
            state.status == CheckoutStatus.failure) {
          _showResult(context, state);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('checkout.title')),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(20),
              child: CheckoutStepIndicator(
                currentStep: state.step.index,
                totalSteps: CheckoutStep.total,
              ),
            ),
          ),
          body: switch (state.step) {
            CheckoutStep.review => _ReviewStep(state: state),
            CheckoutStep.address => _AddressStep(state: state),
            CheckoutStep.delivery => _DeliveryStep(state: state),
            CheckoutStep.payment => _PaymentStep(state: state),
            CheckoutStep.confirm => _ConfirmStep(state: state),
          },
          bottomNavigationBar: _BottomBar(state: state),
        );
      },
    );
  }

  void _showResult(BuildContext context, CheckoutState state) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(switch (state.status) {
          CheckoutStatus.success => tr('checkout.success_title'),
          CheckoutStatus.partialFailure =>
            tr('checkout.partial_title'),
          _ => tr('checkout.failure_title'),
        }),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.status != CheckoutStatus.failure)
                Text(tr('checkout.success_subtitle',
                    args: ['${state.results.where((r) => r.success).length}'])),
              const SizedBox(height: 8),
              for (final r in state.results)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    r.success ? Icons.check_circle_outline : Icons.error_outline,
                    color: r.success ? Colors.green : Theme.of(ctx).colorScheme.error,
                  ),
                  title: Text(r.shopName),
                  subtitle: Text(r.success
                      ? r.order!.orderNumber
                      : (r.error ?? tr('error.unknown'))),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (context.mounted) {
                final firstOrder = state.results
                    .firstWhere((r) => r.success,
                        orElse: () => const ShopSubmissionResult(
                              shopId: '',
                              shopName: '',
                            ))
                    .order;
                if (firstOrder != null) {
                  context.go('/orders/${firstOrder.id}');
                } else {
                  context.go('/orders');
                }
              }
            },
            child: Text(tr('orders.title')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (context.mounted) context.go('/');
            },
            child: Text(tr('checkout.go_home')),
          ),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state});
  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final priceFormat = NumberFormat('#,###', lang);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('checkout.step_review'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final group in state.cart.groupByShop()) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.shop.name.get(lang),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final item in group.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: item.product.heroImage.isEmpty
                                  ? const ColoredBox(color: Color(0x11000000))
                                  : CachedNetworkImage(
                                      imageUrl: item.product.heroImage,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name.get(lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.quantity} Г— ${priceFormat.format(item.product.price)} so\'m',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${priceFormat.format(item.lineTotal)} so\'m',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  Row(
                    children: [
                      Text(tr('cart.shop_subtotal')),
                      const Spacer(),
                      Text(
                        '${priceFormat.format(group.subtotal)} so\'m',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AddressStep extends StatelessWidget {
  const _AddressStep({required this.state});
  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return BlocBuilder<AddressesBloc, AddressesState>(
      builder: (context, addrState) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('checkout.step_address'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (addrState.addresses.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.location_off_outlined, size: 48),
                      const SizedBox(height: 8),
                      Text(tr('address.empty')),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _openCreate(context),
                        icon: const Icon(Icons.add),
                        label: Text(tr('address.add')),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...addrState.addresses.map((a) {
                final selected = state.address?.id == a.id;
                final scheme = Theme.of(context).colorScheme;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: RadioListTile<String>(
                    value: a.id,
                    groupValue: state.address?.id,
                    onChanged: (_) => context
                        .read<CheckoutBloc>()
                        .add(CheckoutAddressSelected(a)),
                    title: Text('${a.label} вЂ” ${a.recipientName}'),
                    subtitle: Text(a.formatted(lang)),
                  ),
                );
              }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openCreate(context),
              icon: const Icon(Icons.add),
              label: Text(tr('address.add')),
            ),
          ],
        );
      },
    );
  }

  void _openCreate(BuildContext context) {
    final addressBloc = context.read<AddressesBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: addressBloc,
          child: const AddressEditScreen(),
        ),
      ),
    );
  }
}

class _DeliveryStep extends StatelessWidget {
  const _DeliveryStep({required this.state});
  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final groups = state.cart.groupByShop();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('checkout.step_delivery'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final g in groups) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.shop.name.get(lang),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final method in OrderDeliveryMethod.values)
                    RadioListTile<OrderDeliveryMethod>(
                      value: method,
                      groupValue: state.deliveryByShop[g.shop.id],
                      onChanged: (m) {
                        if (m == null) return;
                        context.read<CheckoutBloc>().add(
                              CheckoutDeliveryMethodSelected(
                                shopId: g.shop.id,
                                method: m,
                              ),
                            );
                      },
                      title: Text(_methodTitle(method)),
                      subtitle: Text(_methodSubtitle(method)),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _methodTitle(OrderDeliveryMethod m) {
    return switch (m) {
      OrderDeliveryMethod.delivery => tr('delivery.standard'),
      OrderDeliveryMethod.expressDelivery => tr('delivery.express'),
      OrderDeliveryMethod.pickup => tr('delivery.pickup'),
    };
  }

  String _methodSubtitle(OrderDeliveryMethod m) {
    return switch (m) {
      OrderDeliveryMethod.delivery => tr('delivery.standard_hint'),
      OrderDeliveryMethod.expressDelivery => tr('delivery.express_hint'),
      OrderDeliveryMethod.pickup => tr('delivery.pickup_hint'),
    };
  }
}

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({required this.state});
  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('checkout.step_payment'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        RadioListTile<OrderPaymentMethod>(
          value: OrderPaymentMethod.cashOnDelivery,
          groupValue: state.paymentMethod,
          onChanged: (m) {
            if (m == null) return;
            context.read<CheckoutBloc>().add(CheckoutPaymentSelected(m));
          },
          title: Text(tr('payment.cash')),
          subtitle: Text(tr('payment.cash_hint')),
          secondary: const Icon(Icons.payments_outlined),
        ),
        RadioListTile<OrderPaymentMethod>(
          value: OrderPaymentMethod.card,
          groupValue: state.paymentMethod,
          onChanged: null,
          title: Text(tr('payment.card')),
          subtitle: Text(tr('payment.card_disabled')),
          secondary: const Icon(Icons.credit_card_outlined),
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.state});
  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final priceFormat = NumberFormat('#,###', lang);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('checkout.step_confirm'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (state.address != null)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(state.address!.label),
              subtitle: Text(
                '${state.address!.recipientName}\n${state.address!.phone}\n${state.address!.formatted(lang)}',
              ),
              isThreeLine: true,
            ),
          ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _summaryRow(context, tr('cart.grand_total'),
                    '${priceFormat.format(state.cart.grandTotal)} so\'m'),
                const SizedBox(height: 6),
                _summaryRow(context, tr('checkout.delivery_fee'),
                    '${priceFormat.format(state.deliveryFeeTotal)} so\'m'),
                const Divider(),
                _summaryRow(
                  context,
                  tr('checkout.total'),
                  '${priceFormat.format(state.grandTotal)} so\'m',
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(tr('payment.cash')),
            subtitle: Text(tr('payment.cash_hint')),
          ),
        ),
        if (state.cart.groupByShop().length > 1) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('checkout.multi_shop_note',
                          args: ['${state.cart.groupByShop().length}']),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value,
      {bool isBold = false}) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state});
  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    final isFirst = state.step == CheckoutStep.review;
    final isLast = state.step == CheckoutStep.confirm;
    final canAdvance = state.canAdvanceFrom(state.step);
    final isBusy = state.status == CheckoutStatus.submitting;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (!isFirst)
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy
                      ? null
                      : () => context
                          .read<CheckoutBloc>()
                          .add(const CheckoutPreviousStep()),
                  child: Text(tr('common.back')),
                ),
              ),
            if (!isFirst) const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isBusy
                    ? null
                    : isLast
                        ? () => context
                            .read<CheckoutBloc>()
                            .add(const CheckoutSubmitted())
                        : (canAdvance
                            ? () => context
                                .read<CheckoutBloc>()
                                .add(const CheckoutNextStep())
                            : null),
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isLast ? Icons.check : Icons.arrow_forward),
                label: Text(isLast
                    ? tr('checkout.place_order')
                    : tr('common.next')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

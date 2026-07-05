import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/remote_config.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/services/facebook_analytics_service.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../orders/cubit/profile_orders_cubit.dart';
import '../../../../shared/models/cart_item_model.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/pending_payment_service.dart';
import '../../../../shared/repositories/cart_repository.dart';
import '../../../../shared/repositories/checkout_repository.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../../../../shared/widgets/product_color_chip.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/checkout_cubit.dart';
import '../../../../shared/widgets/payment_provider_tile.dart';
import 'map_address_picker_screen.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, required this.items});

  final List<CartItemModel> items;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CheckoutCubit(
        items: items,
        checkout: sl<CheckoutRepository>(),
        cartRepo: sl<CartRepository>(),
        payments: sl<PaymentRepository>(),
        analytics: sl<AnalyticsService>(),
        facebookAnalytics: sl.isRegistered<FacebookAnalyticsService>()
            ? sl<FacebookAnalyticsService>()
            : null,
      ),
      child: const _CheckoutView(),
    );
  }
}

class _CheckoutView extends StatelessWidget {
  const _CheckoutView();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (ctx, state) {
        if (state.status == CheckoutStatus.success) {
          sl<ProfileOrdersCubit>().fetch();
          unawaited(_onCheckoutSuccess(ctx, state));
        }
        if (state.status == CheckoutStatus.failure) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.error ?? tr('common.generic_error')),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
          );
        }
      },
      builder: (ctx, state) {
        return Scaffold(
          backgroundColor: pt.background,
          appBar: AppBar(
            backgroundColor: pt.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Iconsax.arrow_left_2_copy, color: pt.dark),
              onPressed: () => context.pop(),
            ),
            title: Text(
              tr('checkout.appbar_title'),
              style: PremiumTokens.display(size: 20, letterSpacing: -0.4),
            ),
            centerTitle: false,
          ),
          body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _DeliveryCard(state: state, pt: pt),
                        const SizedBox(height: 16),
                        _PaymentCard(state: state, pt: pt),
                        const SizedBox(height: 16),
                        _OrderGroupsCard(state: state, pt: pt),
                        const SizedBox(height: 16),
                        _OrderSummaryCard(state: state, pt: pt),
                      ]),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ConfirmBar(state: state, pt: pt),
              ),
            ],
          ),
        );
      },
    );
  }

  /// On success, branch on the payment method:
  ///   * **External (Payme/Click):** the order is placed but UNPAID. We mark it
  ///     as a pending payment BEFORE handing off (so a mid-payment app-kill is
  ///     recoverable on cold start), launch the provider app, and land the
  ///     customer on their orders list — NO premature "order accepted" modal.
  ///     The [PaymentRecoveryGate] confirms settlement when they return.
  ///   * **Cash on delivery:** there's no payment to confirm — the order is
  ///     genuinely accepted, so we show the receipt dialog as before.
  Future<void> _onCheckoutSuccess(
    BuildContext context,
    CheckoutState state,
  ) async {
    final url = state.checkoutUrl;
    final isExternal = url != null && url.isNotEmpty;

    if (isExternal && state.placedOrderIds.isNotEmpty) {
      // The backend keys the Payme/Click account on the order id, so the first
      // placed order is the reference the status poll fetches.
      if (sl.isRegistered<PendingPaymentService>()) {
        await sl<PendingPaymentService>().mark(
          kind: PendingPaymentKind.order,
          reference: state.placedOrderIds.first,
        );
      }
      final uri = Uri.tryParse(url);
      // externalApplication forces the OS to open the Payme/Click app rather
      // than an in-app WebView.
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!context.mounted) return;
      // The order exists (unpaid) — surface it in the list instead of claiming
      // success. The recovery overlay polls on top of this on return.
      context.go('/orders');
      return;
    }

    if (!context.mounted) return;
    _showSuccessDialog(context, state.placedOrderIds.length);
  }

  void _showSuccessDialog(BuildContext context, int orderCount) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final pt = PremiumTokens.of(ctx);
        final multiOrder = orderCount > 1;
        return AlertDialog(
          backgroundColor: pt.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 32,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.tick_circle,
                  color: PremiumTokens.accent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                multiOrder
                    ? tr('checkout.success_multi_title', args: [orderCount])
                    : tr('checkout.success_single_title'),
                textAlign: TextAlign.center,
                style: PremiumTokens.display(size: 20, letterSpacing: -0.3),
              ),
              const SizedBox(height: 10),
              Text(
                multiOrder
                    ? tr('checkout.success_multi_body')
                    : tr('checkout.success_single_body'),
                textAlign: TextAlign.center,
                style: PremiumTokens.body(
                  size: 14,
                  color: pt.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (context.mounted) context.go('/orders');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: PremiumTokens.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    tr('checkout.view_my_orders'),
                    style: PremiumTokens.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (context.mounted) context.go('/');
                },
                child: Text(
                  tr('checkout.back_to_home'),
                  style: PremiumTokens.body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: pt.grey,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Section 1: Delivery ──────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.state, required this.pt});
  final CheckoutState state;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final hasAddress = state.hasAddress;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () async {
          final picked = await Navigator.of(context, rootNavigator: true)
              .push<PickedLocation>(
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/map-address-picker'),
                  builder: (_) => MapAddressPickerScreen(
                    initialAddress: state.deliveryAddress,
                  ),
                ),
              );
          if (picked != null && context.mounted) {
            context.read<CheckoutCubit>().updateAddress(picked.address);
          }
        },
        borderRadius: BorderRadius.circular(20),
        splashColor: PremiumTokens.accent.withValues(alpha: 0.06),
        highlightColor: PremiumTokens.accent.withValues(alpha: 0.04),
        child: _SectionCard(
          pt: pt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SectionHeader(
                      icon: Iconsax.location,
                      label: tr('checkout.delivery_address'),
                      pt: pt,
                    ),
                  ),
                  Icon(
                    Iconsax.arrow_right_3_copy,
                    size: 16,
                    color: pt.greyLight,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasAddress
                          ? PremiumTokens.accent.withValues(alpha: 0.1)
                          : pt.imageBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasAddress ? Iconsax.map : Iconsax.location_add,
                      color: hasAddress ? PremiumTokens.accent : pt.greyLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: hasAddress
                        ? Text(
                            state.deliveryAddress,
                            style: PremiumTokens.body(
                              size: 14,
                              weight: FontWeight.w600,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('checkout.address_enter_prompt'),
                                style: PremiumTokens.body(
                                  size: 14,
                                  weight: FontWeight.w500,
                                  color: pt.greyLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr('checkout.address_select_hint'),
                                style: PremiumTokens.body(
                                  size: 12,
                                  color: pt.greyLight,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              if (!hasAddress) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.info_circle,
                        size: 14,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tr('checkout.address_required_inline'),
                        style: PremiumTokens.body(
                          size: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section 2: Payment ───────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.state, required this.pt});
  final CheckoutState state;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      pt: pt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Iconsax.card,
            label: tr('checkout.step_payment'),
            pt: pt,
          ),
          const SizedBox(height: 8),
          _PaymentTile(
            icon: Iconsax.money,
            title: tr('payment.cash'),
            subtitle: tr('payment.cash_hint'),
            selected: state.payment == CheckoutPayment.cash,
            onTap: () => context.read<CheckoutCubit>().selectPayment(
              CheckoutPayment.cash,
            ),
            pt: pt,
          ),
          // Online providers are gated by the admin `payment_methods` switch;
          // the spacing rides inside each block so hiding a tile leaves no gap.
          if (RemoteConfig.instance.paymeVisible) ...[
            const SizedBox(height: 8),
            PaymentProviderTile(
              provider: PaymentProvider.payme,
              label: tr('payment.pay_with_payme'),
              selected: state.payment == CheckoutPayment.payme,
              comingSoon: RemoteConfig.instance.paymeComingSoon,
              onTap: RemoteConfig.instance.paymeEnabled
                  ? () => context.read<CheckoutCubit>().selectPayment(
                      CheckoutPayment.payme,
                    )
                  : null,
            ),
          ],
          if (RemoteConfig.instance.clickVisible) ...[
            const SizedBox(height: 8),
            PaymentProviderTile(
              provider: PaymentProvider.click,
              label: tr('payment.pay_with_click'),
              selected: state.payment == CheckoutPayment.click,
              comingSoon: RemoteConfig.instance.clickComingSoon,
              onTap: RemoteConfig.instance.clickEnabled
                  ? () => context.read<CheckoutCubit>().selectPayment(
                      CheckoutPayment.click,
                    )
                  : null,
            ),
          ],
          if (state.payment != CheckoutPayment.cash) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PremiumTokens.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Iconsax.info_circle,
                    size: 16,
                    color: PremiumTokens.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('checkout.deferred_payment_note'),
                      style: PremiumTokens.body(
                        size: 12,
                        color: pt.dark,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.pt,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? PremiumTokens.accent.withValues(alpha: 0.07)
              : pt.imageBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? PremiumTokens.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: disabled
                  ? pt.greyLight
                  : (selected ? PremiumTokens.accent : pt.dark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PremiumTokens.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: disabled ? pt.greyLight : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: PremiumTokens.body(
                      size: 12,
                      color: disabled ? pt.greyLight : pt.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (!disabled)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? PremiumTokens.accent : Colors.transparent,
                  border: Border.all(
                    color: selected ? PremiumTokens.accent : pt.greyLight,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Section 3: Order groups + summary ────────────────────────────────────────

class _OrderGroupsCard extends StatelessWidget {
  const _OrderGroupsCard({required this.state, required this.pt});
  final CheckoutState state;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final groups = state.groups;
    final multiShop = groups.length > 1;

    return _SectionCard(
      pt: pt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Iconsax.receipt,
            label: multiShop
                ? tr('checkout.order_count_header', args: [groups.length])
                : tr('checkout.order_contents_header'),
            pt: pt,
          ),
          if (multiShop) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: PremiumTokens.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.info_circle,
                    size: 13,
                    color: PremiumTokens.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr('checkout.multi_shop_fees_note'),
                      style: PremiumTokens.body(
                        size: 12,
                        color: PremiumTokens.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < groups.length; i++) ...[
            if (multiShop) ...[
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PremiumTokens.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: PremiumTokens.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      groups[i].shopName.isNotEmpty
                          ? groups[i].shopName
                          : tr('checkout.order_index_label', args: [i + 1]),
                      style: PremiumTokens.body(
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            for (final item in groups[i].items) ...[
              _ItemRow(item: item, pt: pt),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
            // Per-shop fees live with the shop's products: its subtotal, its
            // delivery, and its own installation switch — so toggling one
            // seller's installation never changes another seller's total.
            _GroupFees(
              state: state,
              group: groups[i],
              multiShop: multiShop,
              pt: pt,
            ),
            if (multiShop && i < groups.length - 1) ...[
              const SizedBox(height: 14),
              Divider(color: pt.divider, height: 1),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }
}

/// Per-shop fee breakdown rendered under each seller's products: that shop's
/// product subtotal, its delivery fee, an opt-in installation switch, and (in a
/// multi-shop cart) the shop's all-in order total.
class _GroupFees extends StatelessWidget {
  const _GroupFees({
    required this.state,
    required this.group,
    required this.multiShop,
    required this.pt,
  });

  final CheckoutState state;
  final ShopOrderGroup group;
  final bool multiShop;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: pt.divider, height: 1),
        const SizedBox(height: 12),
        _SummaryRow(
          label: tr('checkout.items_total'),
          value: '${_fmt(group.subtotal)} UZS',
          pt: pt,
        ),
        const SizedBox(height: 10),
        _DeliveryRow(
          deliveryFee: state.deliveryFeeFor(group),
          deliveryPriced: group.deliveryPriced,
          pt: pt,
        ),
        if (state.installationAvailableFor(group)) ...[
          const SizedBox(height: 4),
          _InstallationTile(state: state, group: group, pt: pt),
        ],
        // Only multi-shop carts need the per-shop total — for a single shop the
        // summary card's "Jami" already is this number.
        if (multiShop) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('checkout.group_total'),
                  style: PremiumTokens.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: pt.dark,
                  ),
                ),
              ),
              Text(
                '${_fmt(state.groupTotal(group))} UZS',
                style: PremiumTokens.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: PremiumTokens.accent,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A delivery line: the amount, "Tekin" when every line prices its own delivery
/// to zero, or "Sotuvchi belgilaydi" when no product pre-prices it.
class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({
    required this.deliveryFee,
    required this.deliveryPriced,
    required this.pt,
  });

  final double deliveryFee;
  final bool deliveryPriced;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            tr('checkout.delivery_fee'),
            style: PremiumTokens.body(size: 14, color: pt.grey),
          ),
        ),
        if (deliveryFee > 0)
          Text(
            '${_fmt(deliveryFee)} UZS',
            style: PremiumTokens.body(
              size: 14,
              weight: FontWeight.w600,
              color: pt.dark,
            ),
          )
        else if (deliveryPriced)
          Text(
            tr('checkout.delivery_free'),
            style: PremiumTokens.body(
              size: 14,
              weight: FontWeight.w700,
              color: pt.success,
            ),
          )
        else
          Text(
            tr('checkout.delivery_seller_sets'),
            style: PremiumTokens.body(
              size: 13,
              weight: FontWeight.w500,
              color: context.customColors.warning,
            ),
          ),
      ],
    );
  }
}

// ── Section 4: Invoice summary (subtotal · delivery · installation · total) ───

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.state, required this.pt});
  final CheckoutState state;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      pt: pt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Iconsax.receipt,
            label: tr('checkout.order_summary_header'),
            pt: pt,
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: tr('checkout.items_total'),
            value: '${_fmt(state.subtotal)} UZS',
            pt: pt,
          ),
          // Delivery and installation are shown per seller in the order cards
          // above; "Jami" is the dynamic sum of every shop's all-in order total,
          // counting installation only for the shops that opted in.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: pt.divider, height: 1),
          ),
          _SummaryRow(
            label: tr('checkout.group_total'),
            value: '${_fmt(state.grandTotal)} UZS',
            isBold: true,
            pt: pt,
          ),
        ],
      ),
    );
  }
}

/// Opt-in installation row for one shop. Flipping it recomputes that shop's
/// total — and the grand total — instantly; the fee is already known from the
/// quote, so no refetch happens, and only this shop's order is affected.
class _InstallationTile extends StatelessWidget {
  const _InstallationTile({
    required this.state,
    required this.group,
    required this.pt,
  });

  final CheckoutState state;
  final ShopOrderGroup group;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('checkout.want_installation'),
                style: PremiumTokens.body(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '+${_fmt(state.installationFeeFor(group))} UZS',
                style: PremiumTokens.body(size: 13, color: pt.grey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CupertinoSwitch(
          value: state.wantsInstallationFor(group.shopId),
          onChanged: (v) =>
              context.read<CheckoutCubit>().toggleInstallation(group.shopId, v),
          activeTrackColor: PremiumTokens.accent,
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.pt});
  final CartItemModel item;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        // Tap a line to open its product page. Inert only when the snapshot
        // somehow carries no product id.
        onTap: item.productId.isEmpty
            ? null
            : () => context.push('/product/${item.productId}'),
        borderRadius: BorderRadius.circular(12),
        splashColor: PremiumTokens.accent.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _ItemThumb(url: item.productImage, pt: pt),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.productName} × ${item.quantity}',
                      style: PremiumTokens.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: pt.dark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.selectedColor != null) ...[
                      const SizedBox(height: 3),
                      ProductColorChip(
                        slug: item.selectedColor,
                        swatchSize: 11,
                        labelStyle: PremiumTokens.body(
                          size: 11,
                          color: pt.greyLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_fmt(item.lineTotal)} UZS',
                style: PremiumTokens.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: pt.dark,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Iconsax.arrow_right_3_copy, size: 13, color: pt.greyLight),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded product thumbnail for a checkout invoice line. Falls back to
/// a neutral box-icon placeholder when the snapshot carries no image.
class _ItemThumb extends StatelessWidget {
  const _ItemThumb({required this.url, required this.pt});
  final String url;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: pt.imageBg,
      child: Icon(Iconsax.box, size: 16, color: pt.greyLight),
    );
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pt.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 126,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.pt,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final weight = isBold ? FontWeight.w700 : FontWeight.w400;
    final size = isBold ? 16.0 : 14.0;
    return Row(
      children: [
        Text(
          label,
          style: PremiumTokens.body(
            size: size,
            weight: weight,
            color: isBold ? pt.dark : pt.grey,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: PremiumTokens.body(
            size: size,
            weight: weight,
            color: isBold ? PremiumTokens.accent : pt.dark,
          ),
        ),
      ],
    );
  }
}

// ── Confirm bar ───────────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.state, required this.pt});
  final CheckoutState state;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final isBusy = state.status == CheckoutStatus.submitting;
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
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: isBusy ? null : () => _onConfirm(context),
          style: FilledButton.styleFrom(
            backgroundColor: PremiumTokens.accent,
            disabledBackgroundColor: PremiumTokens.accent.withValues(
              alpha: 0.6,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isBusy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr('checkout.confirm_order'),
                      style: PremiumTokens.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Iconsax.arrow_right_3_copy,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _onConfirm(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (!state.hasAddress) {
      _toast(context, tr('checkout.address_required'));
      return;
    }
    final authState = context.read<AuthCubit>().state;
    if (authState is! AppAuthAuthenticated) return;
    // The order is placed first; for Payme/Click the success listener then
    // opens the checkout deep-link in the payment app.
    context.read<CheckoutCubit>().submit(authState.userId);
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Shared card / header widgets ─────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, required this.pt});
  final Widget child;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.pt,
  });

  final IconData icon;
  final String label;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: PremiumTokens.accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: PremiumTokens.body(
            size: 13,
            weight: FontWeight.w700,
            color: pt.grey,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formats a number with space thousands separator (Uzbek convention).
String _fmt(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

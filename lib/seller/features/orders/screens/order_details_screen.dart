import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/order.dart' as model;
import '../../../../shared/models/order_status.dart';
import '../../../../shared/repositories/seller_order_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../bloc/seller_order_detail_bloc.dart';
import '../bloc/seller_orders_bloc.dart';
import '../widgets/order_details/items_card.dart';
import '../widgets/order_details/order_action_bar.dart';
import '../widgets/order_details/order_app_bar.dart';
import '../widgets/order_details/order_details_kit.dart';
import '../widgets/order_details/order_meta_card.dart';
import '../widgets/order_details/payment_summary_card.dart';
import '../widgets/order_details/status_timeline_card.dart';
import '../widgets/order_format.dart';

/// Seller order-details screen, backed by [SellerOrderDetailBloc].
///
/// ROADMAP B.1 — the order lifecycle (`pending → confirmed → preparing →
/// shipped → delivered`, plus cancel) is driven from the sticky
/// [OrderActionBar]; each button dispatches the matching bloc event.
class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    this.ordersBloc,
  });

  final String orderId;

  /// The list screen's bloc, when this detail was opened from the list — used
  /// to mirror status transitions back into the list without a refetch.
  final SellerOrdersBloc? ordersBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerOrderDetailBloc>(
      create: (_) => SellerOrderDetailBloc(
        sl<SellerOrderRepository>(),
        onUpdated: ordersBloc?.pushOrderUpdate,
      )..add(SellerOrderDetailRequested(orderId)),
      child: _OrderDetailView(orderId: orderId),
    );
  }
}

class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView({required this.orderId});

  final String orderId;

  void _dispatchTransition(BuildContext context, OrderStatus target) {
    final bloc = context.read<SellerOrderDetailBloc>();
    switch (target) {
      case OrderStatus.confirmed:
        bloc.add(const SellerOrderActionConfirmed());
      case OrderStatus.preparing:
        bloc.add(const SellerOrderActionMarkPreparing());
      case OrderStatus.shipped:
        bloc.add(const SellerOrderActionMarkShipped());
      case OrderStatus.delivered:
        bloc.add(const SellerOrderActionMarkDelivered());
      case OrderStatus.pending:
      case OrderStatus.cancelled:
        break; // Not a forward transition.
    }
  }

  Future<void> _promptCancel(BuildContext context) async {
    final bloc = context.read<SellerOrderDetailBloc>();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelReasonDialog(),
    );
    if (reason == null) return; // Dialog dismissed.
    final trimmed = reason.trim();
    bloc.add(SellerOrderActionCancelled(
      trimmed.isEmpty ? 'Sotuvchi tomonidan bekor qilindi' : trimmed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SellerOrderDetailBloc, SellerOrderDetailState>(
      listenWhen: (prev, curr) =>
          curr.error != null && curr.error != prev.error,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: kInk,
              content: Text(
                state.error!,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          );
      },
      builder: (context, state) {
        final order = state.order;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: OrderAppBar(orderId: order?.orderNumber ?? 'tafsilotlari'),
          body: _buildBody(context, state, order),
          bottomNavigationBar: order == null
              ? null
              : OrderActionBar(
                  status: order.status,
                  busy: state.status == SellerOrderDetailStatus.mutating,
                  onTransition: (target) =>
                      _dispatchTransition(context, target),
                  onCancel: () => _promptCancel(context),
                ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    SellerOrderDetailState state,
    model.Order? order,
  ) {
    if (order == null) {
      if (state.status == SellerOrderDetailStatus.failure) {
        return _DetailError(
          message: state.error ?? 'Buyurtma topilmadi',
          onRetry: () => context
              .read<SellerOrderDetailBloc>()
              .add(SellerOrderDetailRequested(orderId)),
        );
      }
      return const Center(child: BrandLoadingIndicator());
    }

    final colors = sellerOrderStatusColors(order.status);
    final subtotal =
        order.items.fold<num>(0, (sum, it) => sum + it.lineTotal);
    final delivery =
        order.grandTotal > subtotal ? order.grandTotal - subtotal : 0;

    return SafeArea(
      top: false,
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          OrderMetaCard(
            orderId: order.orderNumber,
            date: formatOrderDateTime(order.createdAt),
            statusLabel: sellerOrderStatusLabel(order.status),
            statusBg: colors.bg,
            statusFg: colors.fg,
          ),
          const SizedBox(height: 14),
          if (order.status != OrderStatus.cancelled) ...[
            StatusTimelineCard(currentStep: _timelineStep(order.status)),
            const SizedBox(height: 14),
          ],
          ItemsCard(items: _mapItems(order.items)),
          const SizedBox(height: 14),
          PaymentSummaryCard(
            subtotal: formatOrderAmount(subtotal),
            delivery: formatOrderAmount(delivery),
            total: formatOrderAmount(order.grandTotal),
            paymentMethod: _paymentLabel(order.paymentMethod),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static int _timelineStep(OrderStatus status) => switch (status) {
        OrderStatus.pending => 0,
        OrderStatus.confirmed => 1,
        OrderStatus.preparing => 2,
        OrderStatus.shipped => 3,
        OrderStatus.delivered => 4,
        OrderStatus.cancelled => 0,
      };

  static String _paymentLabel(model.OrderPaymentMethod method) =>
      switch (method) {
        model.OrderPaymentMethod.cashOnDelivery => 'Naqd pul',
        model.OrderPaymentMethod.card => 'Karta',
      };

  /// Maps domain [model.OrderItem]s to the detail kit's display struct.
  /// `order_items` stores no per-row product name, so the line is labelled by
  /// a short product reference until a `products` join enriches it.
  static List<OrderItem> _mapItems(List<model.OrderItem> items) {
    return [
      for (final it in items)
        OrderItem(
          name: (it.productName.uz?.isNotEmpty ?? false)
              ? it.productName.uz!
              : 'Mahsulot #${_shortId(it.productId)}',
          qty: it.quantity,
          unitPriceLabel: formatOrderAmount(it.unitPrice),
          subtotalLabel: formatOrderAmount(it.lineTotal),
        ),
    ];
  }

  static String _shortId(String id) =>
      (id.length >= 6 ? id.substring(0, 6) : id).toUpperCase();
}

/// Cancel-reason capture dialog — returns the entered reason, or `null` when
/// dismissed.
class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog();

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Buyurtmani bekor qilish',
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: kInk,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 3,
        style: const TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 14,
          color: kInk,
        ),
        decoration: InputDecoration(
          hintText: 'Bekor qilish sababi',
          hintStyle: const TextStyle(
            fontFamily: AppFonts.seller,
            color: kGrey,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kOutline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.terracotta),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Yopish',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontWeight: FontWeight.w600,
              color: kGrey,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.terracotta,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Tasdiqlash',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: kGreyMid),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kGrey,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Qayta urinish',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

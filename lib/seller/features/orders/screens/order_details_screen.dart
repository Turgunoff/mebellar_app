import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/order.dart' as model;
import '../../../../shared/models/order.dart' show FeeAdjustmentStatus;
import '../../../../shared/models/order_status.dart';
import '../../../../shared/repositories/seller_order_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/cancel_reason_sheet.dart';
import '../bloc/seller_order_detail_bloc.dart';
import '../bloc/seller_orders_bloc.dart';
import '../widgets/order_details/delivery_address_card.dart';
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
  const OrderDetailsScreen({super.key, required this.orderId, this.ordersBloc});

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
        analytics: sl<AnalyticsService>(),
      )..add(SellerOrderDetailRequested(orderId)),
      child: _OrderDetailView(orderId: orderId),
    );
  }
}

class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView({required this.orderId});

  final String orderId;

  void _dispatchTransition(BuildContext context, OrderStatus target) {
    // Block any transition while a fee proposal is awaiting customer approval.
    final order = context.read<SellerOrderDetailBloc>().state.order;
    if (order?.feeAdjustmentStatus == FeeAdjustmentStatus.pendingCustomer) {
      return;
    }
    // Intercept the first seller action (pending → confirmed) to show
    // customer contact info and prompt for pre-acceptance communication.
    if (target == OrderStatus.confirmed) {
      _showContactSheet(context);
      return;
    }
    _applyTransition(context, target);
  }

  void _applyTransition(BuildContext context, OrderStatus target) {
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
        break;
    }
  }

  Future<void> _showContactSheet(BuildContext context) async {
    final order = context.read<SellerOrderDetailBloc>().state.order;
    if (order == null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SellerColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CustomerContactSheet(order: order),
    );
    if (confirmed == true && context.mounted) {
      _applyTransition(context, OrderStatus.confirmed);
    }
  }

  Future<void> _showSetFeeDialog(BuildContext context) async {
    final fee = await showDialog<num>(
      context: context,
      builder: (_) => const _SetFeeDialog(),
    );
    if (fee == null || !context.mounted) return;
    context.read<SellerOrderDetailBloc>().add(
      SellerOrderDeliveryFeeSet(fee: fee),
    );
  }

  Future<void> _promptCancel(BuildContext context) async {
    final bloc = context.read<SellerOrderDetailBloc>();
    final c = SellerColors.of(context);
    final selection = await showCancelReasonSheet(
      context: context,
      loadReasons: sl<SellerOrderRepository>().fetchCancelReasons,
      style: CancelReasonStyle(
        surface: c.surface,
        ink: c.ink,
        muted: c.grey,
        border: c.outline,
        field: c.fillSoft,
        accent: AppColors.sellerPrimary,
        danger: const Color(0xFF9A3434),
        fontFamily: AppFonts.seller,
      ),
      labels: CancelReasonLabels(
        title: tr('orders.cancel_title'),
        subtitle: tr('orders.cancel_pick_subtitle'),
        otherHint: tr('orders.cancel_other_hint'),
        confirm: tr('orders.cancel'),
        otherRequired: tr('orders.cancel_other_required'),
        loadError: tr('orders.cancel_load_error'),
      ),
    );
    if (selection == null) return; // Sheet dismissed.
    bloc.add(
      SellerOrderActionCancelled(
        reasonCode: selection.code,
        reasonText: selection.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return BlocConsumer<SellerOrderDetailBloc, SellerOrderDetailState>(
      listenWhen: (prev, curr) =>
          curr.error != null && curr.error != prev.error,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: c.ink,
              content: Text(
                state.error!,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.surface,
                ),
              ),
            ),
          );
      },
      builder: (context, state) {
        final order = state.order;
        return Scaffold(
          backgroundColor: c.background,
          appBar: OrderAppBar(
            orderId: order?.orderNumber ?? 'tafsilotlari',
            orderUuid: order?.id,
          ),
          body: _buildBody(context, state, order),
          bottomNavigationBar: order == null
              ? null
              : OrderActionBar(
                  status: order.status,
                  busy:
                      state.status == SellerOrderDetailStatus.mutating ||
                      state.status == SellerOrderDetailStatus.settingFee,
                  feePendingCustomer:
                      order.feeAdjustmentStatus ==
                      FeeAdjustmentStatus.pendingCustomer,
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
          onRetry: () => context.read<SellerOrderDetailBloc>().add(
            SellerOrderDetailRequested(orderId),
          ),
        );
      }
      return const Center(child: BrandLoadingIndicator());
    }

    final colors = sellerOrderStatusColors(order.status);
    final subtotal = order.items.fold<num>(0, (sum, it) => sum + it.lineTotal);
    final delivery = order.grandTotal > subtotal
        ? order.grandTotal - subtotal
        : 0;
    final feePending =
        order.feeAdjustmentStatus == FeeAdjustmentStatus.pendingCustomer;
    // The invoice is editable only while the order is still pending. Once the
    // seller accepts it (confirmed → … → delivered) the delivery fee is locked,
    // so the "change delivery price" button disappears — matching the backend,
    // which rejects a fee change on any non-pending order.
    final canSetFee = order.status == OrderStatus.pending && !feePending;

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
          DeliveryAddressCard(
            address: order.address.streetLine,
            recipientName: order.address.recipientName,
            phone: order.address.phone,
          ),
          const SizedBox(height: 14),
          ItemsCard(items: _mapItems(order.items)),
          const SizedBox(height: 14),
          PaymentSummaryCard(
            subtotal: formatOrderAmount(subtotal),
            delivery: formatOrderAmount(delivery),
            total: formatOrderAmount(order.grandTotal),
            paymentMethod: _paymentLabel(order.paymentMethod),
            proposedDelivery: feePending
                ? formatOrderAmount(order.proposedDeliveryFee ?? 0)
                : null,
            feeAdjustmentNote: order.feeAdjustmentNote,
            onSetFee: canSetFee ? () => _showSetFeeDialog(context) : null,
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
          thumbnail: it.thumbnail,
          colorSlug: it.colorSlug,
        ),
    ];
  }

  static String _shortId(String id) =>
      (id.length >= 6 ? id.substring(0, 6) : id).toUpperCase();
}

/// Bottom sheet shown before the seller confirms (accepts) an order.
///
/// Displays the customer's name and phone so the seller can verify details
/// for large orders before committing. Returns `true` when the seller taps
/// "Qabul qilish", `null`/`false` when dismissed.
class _CustomerContactSheet extends StatelessWidget {
  const _CustomerContactSheet({required this.order});

  final model.Order order;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final name = order.address.recipientName;
    final phone = order.address.phone;
    final hasContact = name.isNotEmpty || phone.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.greyMid,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Qabul qilishdan oldin",
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD580), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Iconsax.warning_2,
                    size: 18,
                    color: Color(0xFF8C5A12),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Katta summa uchun buyurtmani qabul qilishdan oldin mijoz bilan tafsilotlarni aniqlab oling.",
                      style: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8C5A12),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (hasContact) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.fillSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Iconsax.user, size: 16, color: c.grey),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: TextStyle(
                              fontFamily: AppFonts.seller,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (name.isNotEmpty && phone.isNotEmpty)
                      const SizedBox(height: 10),
                    if (phone.isNotEmpty)
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse('tel:$phone')),
                        child: Row(
                          children: [
                            const Icon(
                              Iconsax.call,
                              size: 16,
                              color: AppColors.sellerPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.sellerPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Bosing",
                              style: TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 11,
                                color: c.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                "Mijoz aloqa ma'lumotlari topilmadi.",
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  color: c.grey,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Yopish',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontWeight: FontWeight.w600,
                          color: c.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sellerPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Qabul qilish',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Inserts spaces every 3 digits from the right so "600000" → "600 000".
class _SpaceThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) return oldValue;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _SetFeeDialog extends StatefulWidget {
  const _SetFeeDialog();

  @override
  State<_SetFeeDialog> createState() => _SetFeeDialogState();
}

class _SetFeeDialogState extends State<_SetFeeDialog> {
  final _feeController = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _feeController.addListener(
      () => setState(() => _valid = _parsedFee() != null),
    );
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  num? _parsedFee() {
    final raw = _feeController.text.trim().replaceAll(' ', '');
    return num.tryParse(raw);
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text(
        'Yetkazish narxini belgilash',
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
      ),
      content: TextField(
        controller: _feeController,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [_SpaceThousandsFormatter()],
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 15,
          color: c.ink,
        ),
        decoration: InputDecoration(
          hintText: 'Yetkazish narxi (UZS)',
          hintStyle: TextStyle(fontFamily: AppFonts.seller, color: c.grey),
          suffixText: 'UZS',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.sellerPrimary),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Yopish',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              color: c.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(_parsedFee())
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sellerPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.sellerPrimary.withValues(
              alpha: 0.4,
            ),
          ),
          child: const Text(
            'Saqlash',
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
    final c = SellerColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 44, color: c.greyMid),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.grey,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sellerPrimary,
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

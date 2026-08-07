import 'package:flutter/material.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/pending_payment_service.dart';
import '../../products/data/ar_token_repository.dart';

/// Full AR-token purchase ledger — every checkout intent the seller started,
/// with settlement status once Payme/Click confirms.
class ArTokenPurchaseHistoryScreen extends StatefulWidget {
  const ArTokenPurchaseHistoryScreen({
    super.key,
    required this.repo,
    this.pendingPayments,
  });

  final ArTokenRepository repo;
  final PendingPaymentService? pendingPayments;

  @override
  State<ArTokenPurchaseHistoryScreen> createState() =>
      _ArTokenPurchaseHistoryScreenState();
}

class _ArTokenPurchaseHistoryScreenState
    extends State<ArTokenPurchaseHistoryScreen> {
  List<ArTokenPurchase>? _items;
  bool _loading = true;
  bool _failed = false;
  String? _cancellingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final items = await widget.repo.purchaseHistory(limit: 50);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e, st) {
      appLog.handle(e, st, '[ar-purchase-history] load failed');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _confirmCancel(ArTokenPurchase purchase) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('seller.ar_purchase_cancel_title')),
        content: Text(tr('seller.ar_purchase_cancel_subtitle')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('common.back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(tr('seller.ar_purchase_cancel_action')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancellingId = purchase.id);
    try {
      await widget.repo.cancelPurchase(purchase.id);
      final pending = await widget.pendingPayments?.peek();
      if (pending != null &&
          pending.kind == PendingPaymentKind.arTokens &&
          pending.reference == purchase.id) {
        await widget.pendingPayments?.clear();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('seller.ar_purchase_cancel_success'))),
        );
        await _load();
      }
    } on ApiError catch (e, st) {
      appLog.handle(e, st, '[ar-purchase-history] cancel failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('seller.ar_purchase_cancel_failed'))),
        );
      }
    } catch (e, st) {
      appLog.handle(e, st, '[ar-purchase-history] cancel failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('seller.ar_purchase_cancel_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('seller.ar_purchase_history_title'),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        iconTheme: IconThemeData(color: c.ink),
      ),
      body: _buildBody(c),
    );
  }

  Widget _buildBody(SellerColors c) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: c.greyMid, size: 36),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _load,
              child: Text(tr('seller.reviews_retry')),
            ),
          ],
        ),
      );
    }
    final items = _items ?? const [];
    if (items.isEmpty) {
      return _EmptyHistory(c: c);
    }
    return RefreshIndicator(
      color: AppColors.sellerPrimary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final purchase = items[index];
          return _PurchaseTile(
            purchase: purchase,
            isCancelling: _cancellingId == purchase.id,
            onCancel: purchase.canCancel
                ? () => _confirmCancel(purchase)
                : null,
          );
        },
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.c});

  final SellerColors c;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.goldBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_rounded, color: c.gold, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              tr('seller.ar_purchase_history_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('seller.ar_purchase_history_empty_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({
    required this.purchase,
    this.onCancel,
    this.isCancelling = false,
  });

  final ArTokenPurchase purchase;
  final VoidCallback? onCancel;
  final bool isCancelling;

  static final _uzs = NumberFormat('#,##0', 'uz_UZ');
  static final _when = DateFormat('d MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final palette = _statusPalette(c, purchase.status);
    final providerLabel = switch (purchase.provider) {
      'click' => tr('seller.ar_purchase_provider_click'),
      'manual' => tr('seller.ar_purchase_provider_manual'),
      _ => tr('seller.ar_purchase_provider_payme'),
    };

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.goldBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bolt_rounded, color: c.gold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        'seller.ar_token_count',
                        namedArgs: {'count': '${purchase.tokens}'},
                      ),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_uzs.format(purchase.amountUzs)} ${tr('common.currency_uzs')}',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: c.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: _statusLabel(purchase.status),
                fg: palette.fg,
                bg: palette.bg,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MetaChip(label: providerLabel, color: c.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _when.format(purchase.createdAt.toLocal()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.greyMid,
                  ),
                ),
              ),
            ],
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: c.divider),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: isCancelling ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.grey,
                  side: BorderSide(color: c.divider),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: isCancelling
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.grey,
                        ),
                      )
                    : Text(
                        tr('seller.ar_purchase_cancel_action'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'paid' => tr('seller.ar_purchase_status_paid'),
    'cancelled' => tr('seller.ar_purchase_status_cancelled'),
    'pending_review' => tr('seller.ar_purchase_status_pending_review'),
    'rejected' => tr('seller.ar_purchase_status_rejected'),
    _ => tr('seller.ar_purchase_status_pending'),
  };

  static ({Color fg, Color bg}) _statusPalette(SellerColors c, String status) =>
      switch (status) {
        'paid' => (fg: c.positive, bg: c.positiveBg),
        'cancelled' => (fg: c.grey, bg: c.fillSoft),
        'rejected' => (fg: AppColors.sellerNegative, bg: c.fillSoft),
        'pending_review' => (
          fg: c.primary,
          bg: c.primary.withValues(alpha: 0.1),
        ),
        _ => (fg: c.warning, bg: c.warningBg),
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.fillSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

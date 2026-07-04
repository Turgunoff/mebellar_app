import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/pending_payment_service.dart';
import '../../products/data/ar_token_repository.dart';

/// Full AR-token purchase ledger — every checkout intent the seller started,
/// with settlement status once Payme/Click confirms.
class ArTokenPurchaseHistoryScreen extends StatefulWidget {
  const ArTokenPurchaseHistoryScreen({super.key});

  @override
  State<ArTokenPurchaseHistoryScreen> createState() =>
      _ArTokenPurchaseHistoryScreenState();
}

class _ArTokenPurchaseHistoryScreenState
    extends State<ArTokenPurchaseHistoryScreen> {
  List<ArTokenPurchase>? _items;
  bool _loading = true;
  bool _failed = false;

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
      final items = await sl<ArTokenRepository>().purchaseHistory(limit: 50);
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
    try {
      await sl<ArTokenRepository>().cancelPurchase(purchase.id);
      final pending = await sl<PendingPaymentService>().peek();
      if (pending != null &&
          pending.kind == PendingPaymentKind.arTokens &&
          pending.reference == purchase.id) {
        await sl<PendingPaymentService>().clear();
      }
      if (mounted) await _load();
    } catch (e, st) {
      appLog.handle(e, st, '[ar-purchase-history] cancel failed');
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
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PurchaseTile(
            purchase: items[index],
            onCancel: items[index].isPending
                ? () => _confirmCancel(items[index])
                : null,
          ),
        ),
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
  const _PurchaseTile({required this.purchase, this.onCancel});

  final ArTokenPurchase purchase;
  final VoidCallback? onCancel;

  static final _uzs = NumberFormat('#,##0', 'uz_UZ');
  static final _when = DateFormat('d MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final palette = _statusPalette(c, purchase.status);
    final providerLabel = purchase.provider == 'click'
        ? tr('seller.ar_purchase_provider_click')
        : tr('seller.ar_purchase_provider_payme');

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: palette.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.goldBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: c.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tr(
                                      'seller.ar_token_count',
                                      namedArgs: {
                                        'count': '${purchase.tokens}',
                                      },
                                    ),
                                    style: TextStyle(
                                      fontFamily: AppFonts.seller,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: c.ink,
                                    ),
                                  ),
                                ),
                                _StatusChip(
                                  label: _statusLabel(purchase.status),
                                  fg: palette.fg,
                                  bg: palette.bg,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_uzs.format(purchase.amountUzs)} ${tr('common.currency_uzs')}',
                              style: TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: c.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _MetaChip(label: providerLabel, color: c.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _when.format(purchase.createdAt.toLocal()),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppFonts.seller,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: c.greyMid,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (onCancel != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: onCancel,
                                  style: TextButton.styleFrom(
                                    foregroundColor: c.warning,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'paid' => tr('seller.ar_purchase_status_paid'),
    'cancelled' => tr('seller.ar_purchase_status_cancelled'),
    _ => tr('seller.ar_purchase_status_pending'),
  };

  static ({Color accent, Color fg, Color bg}) _statusPalette(
    SellerColors c,
    String status,
  ) => switch (status) {
    'paid' => (accent: c.positive, fg: c.positive, bg: c.positiveBg),
    'cancelled' => (accent: c.greyMid, fg: c.grey, bg: c.fillSoft),
    _ => (accent: c.warning, fg: c.warning, bg: c.warningBg),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.fillSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

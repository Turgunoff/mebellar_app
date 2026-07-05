import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/payments/payment_pending_copy.dart';
import '../../../../shared/models/seller_wallet.dart';
import '../../../../shared/repositories/seller_wallet_repository.dart';

/// Full wallet ledger — manual top-up moderation rows plus balance movements.
class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List<WalletTopUp>? _topUps;
  List<WalletTransaction>? _transactions;
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
      final repo = sl<SellerWalletRepository>();
      final results = await Future.wait([
        repo.fetchTopUps(),
        repo.fetchTransactions(limit: 50),
      ]);
      if (mounted) {
        setState(() {
          _topUps = results[0] as List<WalletTopUp>;
          _transactions = results[1] as List<WalletTransaction>;
          _loading = false;
        });
      }
    } catch (e, st) {
      appLog.handle(e, st, '[wallet-history] load failed');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
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
          tr('seller.wallet_history_title'),
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

    final topUps = _topUps ?? const [];
    final transactions = _transactions ?? const [];
    if (topUps.isEmpty && transactions.isEmpty) {
      return _EmptyHistory(c: c);
    }

    return RefreshIndicator(
      color: AppColors.sellerPrimary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          if (topUps.isNotEmpty) ...[
            _SectionTitle(label: tr('seller.wallet_topup_requests_title')),
            const SizedBox(height: 10),
            for (var i = 0; i < topUps.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _TopUpTile(topUp: topUps[i]),
            ],
            const SizedBox(height: 24),
          ],
          if (transactions.isNotEmpty) ...[
            _SectionTitle(label: tr('seller.wallet_activity_title')),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.divider),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < transactions.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 64,
                        color: c.divider,
                      ),
                    _TransactionTile(tx: transactions[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Text(
      label,
      style: TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: c.ink,
        letterSpacing: -0.2,
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
                color: c.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: c.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('seller.wallet_history_empty'),
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
              tr('seller.wallet_history_empty_hint'),
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

class _TopUpTile extends StatelessWidget {
  const _TopUpTile({required this.topUp});

  final WalletTopUp topUp;

  static final _uzs = NumberFormat('#,##0', 'uz_UZ');
  static final _when = DateFormat('d MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final palette = _statusPalette(c, topUp.status);
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
                  color: c.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Iconsax.card, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('seller.ar_purchase_provider_manual'),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _when.format(topUp.submittedAt.toLocal()),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: _statusLabel(topUp.status),
                fg: palette.fg,
                bg: palette.bg,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_uzs.format(topUp.amount)} ${tr('seller.wallet_currency_som')}',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.ink,
              letterSpacing: -0.3,
            ),
          ),
          if (topUp.rejectionReason case final reason? when reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                resolvePaymentCancellationReason(reason),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.sellerNegative,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'approved' => tr('seller.wallet_topup_status_approved'),
    'rejected' => tr('seller.wallet_topup_status_rejected'),
    'cancelled' => tr('seller.wallet_topup_status_cancelled'),
    _ => tr('seller.wallet_topup_status_pending'),
  };

  static ({Color fg, Color bg}) _statusPalette(SellerColors c, String status) =>
      switch (status) {
        'approved' => (fg: c.positive, bg: c.positiveBg),
        'rejected' => (fg: AppColors.sellerNegative, bg: c.fillSoft),
        'cancelled' => (fg: c.grey, bg: c.fillSoft),
        _ => (fg: c.primary, bg: c.primary.withValues(alpha: 0.1)),
      };
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final WalletTransaction tx;

  static final _fmt = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final debit = tx.isDebit;
    final accent = debit ? c.negative : c.positive;
    final accentBg = debit ? c.negativeBg : c.positiveBg;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: accentBg, shape: BoxShape.circle),
            child: Icon(
              debit ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
              color: accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.note ?? tx.typeLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _fmt.format(tx.createdAt.toLocal()),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${debit ? '−' : '+'}${formatSom(tx.amount.abs())}',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
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

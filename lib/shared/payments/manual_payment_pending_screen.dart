import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../seller/features/products/data/ar_token_repository.dart';
import '../../seller/features/wallet/screens/ar_token_purchase_history_screen.dart';
import '../../seller/features/wallet/screens/wallet_history_screen.dart';
import '../models/seller_wallet.dart';
import '../repositories/seller_wallet_repository.dart';

/// Shared "Kutilmoqda" screen for manual (P2P card + receipt) payments that
/// await admin approval — wallet top-ups and AR-token purchases.
sealed class ManualPaymentPendingArgs {
  ManualPaymentPendingArgs({
    required this.referenceId,
    required this.submittedAt,
  });

  final String referenceId;
  final DateTime submittedAt;

  Duration get slaRemaining {
    final due = submittedAt.add(const Duration(hours: 24));
    final left = due.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isStillPending;
}

final class WalletTopUpPendingArgs extends ManualPaymentPendingArgs {
  WalletTopUpPendingArgs({required WalletTopUp topUp})
    : _topUp = topUp,
      super(referenceId: topUp.id, submittedAt: topUp.submittedAt);

  final WalletTopUp _topUp;

  WalletTopUp get topUp => _topUp;

  int get amount => _topUp.amount;

  @override
  bool get isStillPending => _topUp.isPending;

  WalletTopUpPendingArgs copyWithTopUp(WalletTopUp topUp) =>
      WalletTopUpPendingArgs(topUp: topUp);
}

final class ArTokenPurchasePendingArgs extends ManualPaymentPendingArgs {
  ArTokenPurchasePendingArgs({required ArTokenPurchase purchase})
    : _purchase = purchase,
      super(referenceId: purchase.id, submittedAt: purchase.createdAt);

  final ArTokenPurchase _purchase;

  ArTokenPurchase get purchase => _purchase;

  int get tokens => _purchase.tokens;

  int get amountUzs => _purchase.amountUzs;

  @override
  bool get isStillPending => _purchase.isPendingReview;

  ArTokenPurchasePendingArgs copyWithPurchase(ArTokenPurchase purchase) =>
      ArTokenPurchasePendingArgs(purchase: purchase);
}

class ManualPaymentPendingScreen extends StatefulWidget {
  const ManualPaymentPendingScreen({super.key, required this.args});

  final ManualPaymentPendingArgs args;

  @override
  State<ManualPaymentPendingScreen> createState() =>
      _ManualPaymentPendingScreenState();
}

class _ManualPaymentPendingScreenState
    extends State<ManualPaymentPendingScreen> {
  late ManualPaymentPendingArgs _live = widget.args;
  Timer? _ticker;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      switch (_live) {
        case WalletTopUpPendingArgs(:final topUp):
          final rows = await sl<SellerWalletRepository>().fetchTopUps();
          final match = rows
              .where((row) => row.id == topUp.id)
              .cast<WalletTopUp?>()
              .firstOrNull;
          if (match == null || !mounted) return;
          final next = (_live as WalletTopUpPendingArgs).copyWithTopUp(match);
          if (_live.isStillPending && match.isResolved) {
            await _showResolution(next);
            if (mounted) Navigator.of(context).pop();
            return;
          }
          setState(() => _live = next);
        case ArTokenPurchasePendingArgs(:final purchase):
          final rows = await sl<ArTokenRepository>().purchaseHistory(limit: 50);
          final match = rows
              .where((row) => row.id == purchase.id)
              .cast<ArTokenPurchase?>()
              .firstOrNull;
          if (match == null || !mounted) return;
          final next = (_live as ArTokenPurchasePendingArgs).copyWithPurchase(
            match,
          );
          if (_live.isStillPending && match.isResolved) {
            await _showResolution(next);
            if (mounted) Navigator.of(context).pop();
            return;
          }
          setState(() => _live = next);
      }
    } catch (_) {
      // Best-effort polling — network blips shouldn't crash the screen.
    }
  }

  Future<void> _confirmCancelAr() async {
    final purchase = (_live as ArTokenPurchasePendingArgs).purchase;
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
    await sl<ArTokenRepository>().cancelPurchase(purchase.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showResolution(ManualPaymentPendingArgs resolved) async {
    if (!mounted) return;
    final approved = switch (resolved) {
      WalletTopUpPendingArgs(:final topUp) => topUp.isApproved,
      ArTokenPurchasePendingArgs(:final purchase) => purchase.isPaid,
    };
    final rejectionReason = switch (resolved) {
      WalletTopUpPendingArgs(:final topUp) => topUp.rejectionReason,
      ArTokenPurchasePendingArgs() => null,
    };
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          approved ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 36,
          color: approved
              ? SellerColors.of(ctx).positive
              : Theme.of(ctx).colorScheme.error,
        ),
        title: Text(
          approved
              ? tr('seller.manual_payment_approved_title')
              : tr('seller.manual_payment_rejected_title'),
        ),
        content: Text(switch (resolved) {
          WalletTopUpPendingArgs(:final topUp) when approved => tr(
            'seller.wallet_topup_approved_subtitle',
            namedArgs: {'amount': formatSom(topUp.amount)},
          ),
          ArTokenPurchasePendingArgs(:final purchase) when approved => tr(
            'seller.ar_purchase_approved_subtitle',
            namedArgs: {'count': '${purchase.tokens}'},
          ),
          WalletTopUpPendingArgs() =>
            rejectionReason ?? tr('seller.manual_payment_rejected_subtitle'),
          ArTokenPurchasePendingArgs() => tr(
            'seller.manual_payment_rejected_subtitle',
          ),
        }),
        actions: [
          if (!approved)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('tariff.try_again')),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common.ok')),
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    final route = switch (_live) {
      WalletTopUpPendingArgs() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/seller-wallet-history'),
        builder: (_) => const WalletHistoryScreen(),
      ),
      ArTokenPurchasePendingArgs() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/ar-token-purchase-history'),
        builder: (_) => const ArTokenPurchaseHistoryScreen(),
      ),
    };
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('tariff.pending_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top_outlined,
                size: 56,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr('tariff.pending_headline'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            tr('tariff.pending_subtitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _SlaCard(
            remaining: _live.slaRemaining,
            submittedAt: _live.submittedAt,
          ),
          const SizedBox(height: 16),
          _SummaryCard(args: _live),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _openHistory,
            icon: const Icon(Icons.history),
            label: Text(_historyLabel),
          ),
          const SizedBox(height: 8),
          if (_live case ArTokenPurchasePendingArgs(
            :final purchase,
          ) when purchase.canCancel && _live.isStillPending)
            TextButton.icon(
              onPressed: _confirmCancelAr,
              icon: Icon(Icons.cancel_outlined, color: scheme.error),
              label: Text(
                tr('tariff.cancel_request'),
                style: TextStyle(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }

  String get _historyLabel => switch (_live) {
    WalletTopUpPendingArgs() => tr('seller.wallet_history_title'),
    ArTokenPurchasePendingArgs() => tr('seller.ar_purchase_history_title'),
  };
}

class _SlaCard extends StatelessWidget {
  const _SlaCard({required this.remaining, required this.submittedAt});

  final Duration remaining;
  final DateTime submittedAt;

  String _formatRemaining(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              tr('tariff.sla_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _formatRemaining(remaining),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'tariff.submitted_at',
                args: [
                  DateFormat(
                    'dd MMM, HH:mm',
                    lang,
                  ).format(submittedAt.toLocal()),
                ],
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.args});

  final ManualPaymentPendingArgs args;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final priceFormat = NumberFormat('#,###', lang);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(switch (args) {
              WalletTopUpPendingArgs() => Icons.account_balance_wallet_outlined,
              ArTokenPurchasePendingArgs() => Icons.bolt_rounded,
            }),
            title: Text(switch (args) {
              WalletTopUpPendingArgs() => tr(
                'seller.wallet_topup_section_title',
              ),
              ArTokenPurchasePendingArgs(:final purchase) => tr(
                'seller.ar_token_count',
                namedArgs: {'count': '${purchase.tokens}'},
              ),
            }),
            subtitle: Text(switch (args) {
              WalletTopUpPendingArgs() => tr(
                'seller.manual_payment_wallet_note',
              ),
              ArTokenPurchasePendingArgs() => tr(
                'seller.manual_payment_ar_note',
              ),
            }),
            trailing: Text(switch (args) {
              WalletTopUpPendingArgs(:final amount) =>
                '${priceFormat.format(amount)} so\'m',
              ArTokenPurchasePendingArgs(:final amountUzs) =>
                '${priceFormat.format(amountUzs)} so\'m',
            }, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

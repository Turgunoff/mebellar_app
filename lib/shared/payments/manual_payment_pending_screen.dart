import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../seller/features/products/data/ar_token_repository.dart';
import '../../seller/features/tariff/screens/tariff_history_screen.dart';
import '../../seller/features/wallet/screens/ar_token_purchase_history_screen.dart';
import '../../seller/features/wallet/screens/wallet_history_screen.dart';
import '../models/seller_wallet.dart';
import '../models/tariff.dart';
import '../repositories/seller_wallet_repository.dart';
import '../repositories/tariff_repository.dart';
import 'payment_pending_copy.dart';

/// Shared pending screen for seller payments — P2P (admin review) and online
/// (Payme/Click webhook settlement).
sealed class ManualPaymentPendingArgs {
  ManualPaymentPendingArgs({
    required this.referenceId,
    required this.submittedAt,
  });

  final String referenceId;
  final DateTime submittedAt;

  bool get isManualReview;

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
  bool get isManualReview => true;

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
  bool get isManualReview => isManualPaymentReview(
    provider: _purchase.provider,
    status: _purchase.status,
  );

  @override
  bool get isStillPending => _purchase.isPending || _purchase.isPendingReview;

  ArTokenPurchasePendingArgs copyWithPurchase(ArTokenPurchase purchase) =>
      ArTokenPurchasePendingArgs(purchase: purchase);
}

final class WalletDepositPendingArgs extends ManualPaymentPendingArgs {
  WalletDepositPendingArgs({required WalletDeposit deposit})
    : _deposit = deposit,
      super(referenceId: deposit.id, submittedAt: deposit.createdAt);

  final WalletDeposit _deposit;

  WalletDeposit get deposit => _deposit;

  int get amount => _deposit.amount;

  @override
  bool get isManualReview => false;

  @override
  bool get isStillPending => _deposit.isPending;
}

final class TariffSubscriptionPendingArgs extends ManualPaymentPendingArgs {
  TariffSubscriptionPendingArgs({required TariffSubscription subscription})
    : _subscription = subscription,
      super(
        referenceId: subscription.id,
        submittedAt: subscription.submittedAt,
      );

  final TariffSubscription _subscription;

  TariffSubscription get subscription => _subscription;

  int get amount => _subscription.amount;

  @override
  bool get isManualReview =>
      _subscription.paymentScreenshotUrl != null &&
      _subscription.paymentScreenshotUrl!.isNotEmpty;

  @override
  bool get isStillPending => _subscription.status.isPending;

  @override
  Duration get slaRemaining => _subscription.slaRemaining;

  TariffSubscriptionPendingArgs copyWithSubscription(
    TariffSubscription subscription,
  ) => TariffSubscriptionPendingArgs(subscription: subscription);
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
        case WalletDepositPendingArgs(:final deposit):
          final status = await sl<SellerWalletRepository>().depositStatus(
            deposit.id,
          );
          if (!mounted) return;
          if (status == 'paid') {
            await _showWalletDepositPaid(deposit);
            if (mounted) Navigator.of(context).pop();
          } else if (status == 'cancelled') {
            if (mounted) Navigator.of(context).pop();
          }
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
        case TariffSubscriptionPendingArgs(:final subscription):
          final repo = sl<TariffRepository>();
          TariffSubscription? match;
          final pending = (await repo.currentPending()).valueOrNull;
          if (pending?.id == subscription.id) {
            match = pending;
          } else {
            final history = (await repo.history()).valueOrNull ?? const [];
            match = history
                .where((row) => row.id == subscription.id)
                .cast<TariffSubscription?>()
                .firstOrNull;
          }
          if (match == null || !mounted) return;
          final next = (_live as TariffSubscriptionPendingArgs)
              .copyWithSubscription(match);
          if (_live.isStillPending && !match.status.isPending) {
            await _showTariffResolution(next);
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

  Future<void> _confirmCancelTariff() async {
    final subscription = (_live as TariffSubscriptionPendingArgs).subscription;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('tariff.cancel_title')),
        content: Text(tr('tariff.cancel_subtitle')),
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
            child: Text(tr('orders.cancel')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await sl<TariffRepository>().cancelPending(subscription.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showWalletDepositPaid(WalletDeposit deposit) async {
    await _showResolution(WalletDepositPendingArgs(deposit: deposit));
  }

  Future<void> _showResolution(ManualPaymentPendingArgs resolved) async {
    if (resolved is TariffSubscriptionPendingArgs) {
      return _showTariffResolution(resolved);
    }
    if (!mounted) return;
    final approved = switch (resolved) {
      WalletTopUpPendingArgs(:final topUp) => topUp.isApproved,
      WalletDepositPendingArgs() => true,
      ArTokenPurchasePendingArgs(:final purchase) => purchase.isPaid,
      TariffSubscriptionPendingArgs() => throw StateError('tariff'),
    };
    final rejectionReason = switch (resolved) {
      WalletTopUpPendingArgs(:final topUp) => topUp.rejectionReason,
      WalletDepositPendingArgs() => null,
      ArTokenPurchasePendingArgs() => null,
      TariffSubscriptionPendingArgs() => throw StateError('tariff'),
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
          WalletDepositPendingArgs(:final deposit) when approved => tr(
            'seller.wallet_topup_approved_subtitle',
            namedArgs: {'amount': formatSom(deposit.amount)},
          ),
          ArTokenPurchasePendingArgs(:final purchase) when approved => tr(
            'seller.ar_purchase_approved_subtitle',
            namedArgs: {'count': '${purchase.tokens}'},
          ),
          WalletTopUpPendingArgs() =>
            rejectionReason ?? tr('seller.manual_payment_rejected_subtitle'),
          WalletDepositPendingArgs() => tr(
            'seller.manual_payment_rejected_subtitle',
          ),
          ArTokenPurchasePendingArgs() => tr(
            'seller.manual_payment_rejected_subtitle',
          ),
          TariffSubscriptionPendingArgs() => throw StateError('tariff'),
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

  Future<void> _showTariffResolution(
    TariffSubscriptionPendingArgs resolved,
  ) async {
    if (!mounted) return;
    final sub = resolved.subscription;
    final approved = sub.status.isApproved;
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
          approved ? tr('tariff.approved_title') : tr('tariff.rejected_title'),
        ),
        content: Text(
          approved
              ? tr(
                  'tariff.approved_subtitle',
                  args: [tr('tariff.plan.${sub.plan.code}_label')],
                )
              : (sub.rejectionReason ?? tr('tariff.rejected_subtitle')),
        ),
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
      WalletTopUpPendingArgs() ||
      WalletDepositPendingArgs() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/seller-wallet-history'),
        builder: (_) => const WalletHistoryScreen(),
      ),
      ArTokenPurchasePendingArgs() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/ar-token-purchase-history'),
        builder: (_) => const ArTokenPurchaseHistoryScreen(),
      ),
      TariffSubscriptionPendingArgs() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/seller-tariff-history'),
        builder: (_) => const TariffHistoryScreen(),
      ),
    };
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final manualReview = _live.isManualReview;
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
            pendingHeadline(manualReview: manualReview),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            pendingSubtitle(manualReview: manualReview),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _SlaCard(
            remaining: _live.slaRemaining,
            submittedAt: _live.submittedAt,
            manualReview: manualReview,
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
          if (_live case TariffSubscriptionPendingArgs(
            :final subscription,
          ) when subscription.status.isPending && _live.isStillPending)
            TextButton.icon(
              onPressed: _confirmCancelTariff,
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
    WalletTopUpPendingArgs() ||
    WalletDepositPendingArgs() => tr('seller.wallet_history_title'),
    ArTokenPurchasePendingArgs() => tr('seller.ar_purchase_history_title'),
    TariffSubscriptionPendingArgs() => tr('tariff.history'),
  };
}

class _SlaCard extends StatelessWidget {
  const _SlaCard({
    required this.remaining,
    required this.submittedAt,
    required this.manualReview,
  });

  final Duration remaining;
  final DateTime submittedAt;
  final bool manualReview;

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
              pendingSlaTitle(manualReview: manualReview),
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
              WalletTopUpPendingArgs() || WalletDepositPendingArgs() =>
                Icons.account_balance_wallet_outlined,
              ArTokenPurchasePendingArgs() => Icons.bolt_rounded,
              TariffSubscriptionPendingArgs() =>
                Icons.workspace_premium_outlined,
            }),
            title: Text(switch (args) {
              WalletTopUpPendingArgs() || WalletDepositPendingArgs() => tr(
                'seller.wallet_topup_section_title',
              ),
              ArTokenPurchasePendingArgs(:final purchase) => tr(
                'seller.ar_token_count',
                namedArgs: {'count': '${purchase.tokens}'},
              ),
              TariffSubscriptionPendingArgs(:final subscription) => tr(
                'tariff.plan.${subscription.plan.code}_label',
              ),
            }),
            subtitle: Text(switch (args) {
              WalletTopUpPendingArgs() => tr(
                'seller.manual_payment_wallet_note',
              ),
              WalletDepositPendingArgs() => tr(
                'seller.pending_online_subtitle',
              ),
              ArTokenPurchasePendingArgs() when args.isManualReview => tr(
                'seller.manual_payment_ar_note',
              ),
              ArTokenPurchasePendingArgs() => tr(
                'seller.pending_online_subtitle',
              ),
              TariffSubscriptionPendingArgs(:final subscription) => tr(
                'tariff.period_${subscription.period.code}',
              ),
            }),
            trailing: Text(switch (args) {
              WalletTopUpPendingArgs(:final amount) ||
              WalletDepositPendingArgs(
                :final amount,
              ) => '${priceFormat.format(amount)} so\'m',
              ArTokenPurchasePendingArgs(:final amountUzs) =>
                '${priceFormat.format(amountUzs)} so\'m',
              TariffSubscriptionPendingArgs(:final amount) =>
                '${priceFormat.format(amount)} so\'m',
            }, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (args case TariffSubscriptionPendingArgs())
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                tr('tariff.current_remains'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/di/service_locator.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
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

  /// The pending window this screen counts down against. Manual-review flows
  /// mirror the backend's 24h moderation SLA; online (Payme/Click) flows use
  /// their own, much shorter window — see [WalletDepositPendingArgs].
  Duration get slaWindow => const Duration(hours: 24);

  Duration get slaRemaining {
    final due = submittedAt.add(slaWindow);
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

  // Payme/Click is a "pay right now in the app" flow, not an admin-review
  // queue — a 24h countdown oversells how long the seller actually has and
  // doesn't match the backend's own transaction lifecycle (Payme's protocol
  // auto-cancels a created-but-unperformed transaction after 12h; see
  // `TRANSACTION_TIMEOUT_MS` in woody_backend/app/services/payme_repos.py).
  // 15 minutes nudges the seller to finish the checkout immediately.
  @override
  Duration get slaWindow => const Duration(minutes: 15);

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
            await _handleResolved(next);
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
            await _handleResolved(next);
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

  Future<void> _confirmCancelWallet() async {
    final topUp = (_live as WalletTopUpPendingArgs).topUp;
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
    await sl<SellerWalletRepository>().cancelTopUp(topUp.id);
    if (mounted) Navigator.of(context).pop();
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

  Future<void> _confirmCancelDeposit() async {
    final deposit = (_live as WalletDepositPendingArgs).deposit;
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
    await sl<SellerWalletRepository>().cancelDeposit(deposit.id);
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

  Future<void> _handleResolved(ManualPaymentPendingArgs resolved) async {
    if (resolved is TariffSubscriptionPendingArgs) {
      await _showTariffResolution(resolved);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final cancelled = switch (resolved) {
      WalletTopUpPendingArgs(:final topUp) => topUp.isCancelled,
      ArTokenPurchasePendingArgs(:final purchase) => purchase.isCancelled,
      WalletDepositPendingArgs() => false,
      TariffSubscriptionPendingArgs() => false,
    };
    final slaReason = switch (resolved) {
      WalletTopUpPendingArgs(:final topUp) => topUp.rejectionReason,
      ArTokenPurchasePendingArgs(:final purchase) => purchase.rejectionReason,
      WalletDepositPendingArgs() => null,
      TariffSubscriptionPendingArgs() => null,
    };

    if (cancelled) {
      if (isSlaExpiredCancellation(slaReason)) {
        await _showSlaExpiredDialog();
      }
    } else {
      await _showResolution(resolved);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showSlaExpiredDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Iconsax.timer_1,
          size: 36,
          color: SellerColors.of(ctx).primary,
        ),
        title: Text(tr('seller.payment_sla_expired_title')),
        content: Text(tr('seller.payment_sla_expired_message')),
        actions: [
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
          WalletTopUpPendingArgs() => resolvePaymentCancellationReason(
            rejectionReason,
          ),
          WalletDepositPendingArgs() => tr(
            'seller.manual_payment_rejected_subtitle',
          ),
          ArTokenPurchasePendingArgs(:final purchase) =>
            resolvePaymentCancellationReason(purchase.rejectionReason),
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
    if (sub.status == TariffUpgradeStatus.cancelled &&
        !isSlaExpiredCancellation(sub.rejectionReason)) {
      return;
    }
    final approved = sub.status.isApproved;
    final slaExpired = isSlaExpiredCancellation(sub.rejectionReason);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          approved
              ? Icons.check_circle_outline
              : slaExpired
              ? Iconsax.timer_1
              : Icons.cancel_outlined,
          size: 36,
          color: approved
              ? SellerColors.of(ctx).positive
              : slaExpired
              ? SellerColors.of(ctx).primary
              : Theme.of(ctx).colorScheme.error,
        ),
        title: Text(
          approved
              ? tr('tariff.approved_title')
              : slaExpired
              ? tr('seller.payment_sla_expired_title')
              : tr('tariff.rejected_title'),
        ),
        content: Text(
          approved
              ? tr(
                  'tariff.approved_subtitle',
                  args: [tr('tariff.plan.${sub.plan.code}_label')],
                )
              : resolvePaymentCancellationReason(sub.rejectionReason),
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
    final c = SellerColors.of(context);
    final manualReview = _live.isManualReview;
    final canCancel = switch (_live) {
      WalletTopUpPendingArgs(:final topUp) =>
        topUp.canCancel && _live.isStillPending,
      ArTokenPurchasePendingArgs(:final purchase) =>
        purchase.canCancel && _live.isStillPending,
      TariffSubscriptionPendingArgs(:final subscription) =>
        subscription.status.isPending && _live.isStillPending,
      WalletDepositPendingArgs(:final deposit) =>
        deposit.canCancel && _live.isStillPending,
    };
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: c.ink,
        title: Text(
          tr('tariff.pending_title'),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          _PendingHero(manualReview: manualReview),
          const SizedBox(height: 28),
          _SlaCard(
            remaining: _live.slaRemaining,
            window: _live.slaWindow,
            submittedAt: _live.submittedAt,
            manualReview: manualReview,
          ),
          const SizedBox(height: 14),
          _SummaryCard(args: _live),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _openHistory,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(Iconsax.clock, size: 20, color: c.primary),
              label: Text(
                _historyLabel,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (canCancel) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                onPressed: switch (_live) {
                  WalletTopUpPendingArgs() => _confirmCancelWallet,
                  ArTokenPurchasePendingArgs() => _confirmCancelAr,
                  TariffSubscriptionPendingArgs() => _confirmCancelTariff,
                  WalletDepositPendingArgs() => _confirmCancelDeposit,
                },
                style: TextButton.styleFrom(
                  foregroundColor: c.negative,
                  backgroundColor: c.negativeBg.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(Iconsax.close_circle, size: 18, color: c.negative),
                label: Text(
                  tr('tariff.cancel_request'),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
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

class _PendingHero extends StatelessWidget {
  const _PendingHero({required this.manualReview});

  final bool manualReview;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final accent = manualReview ? c.progress : c.primary;
    final accentBg = manualReview ? c.progressBg : c.primarySoft;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentBg.withValues(alpha: 0.55),
              ),
            ),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                manualReview ? Iconsax.timer_1 : Iconsax.flash_circle,
                size: 40,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accentBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            tr('tariff.pending_title'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          pendingHeadline(manualReview: manualReview),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: c.ink,
            letterSpacing: -0.4,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          pendingSubtitle(manualReview: manualReview),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.grey,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SlaCard extends StatelessWidget {
  const _SlaCard({
    required this.remaining,
    required this.window,
    required this.submittedAt,
    required this.manualReview,
  });

  final Duration remaining;
  final Duration window;
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
    final c = SellerColors.of(context);
    final lang = context.locale.languageCode;
    final accent = manualReview ? c.progress : c.primary;
    final elapsed = window - remaining;
    final progress = (elapsed.inSeconds / window.inSeconds).clamp(0.0, 1.0);
    final parts = _formatRemaining(remaining).split(':');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.divider),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Iconsax.timer, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pendingSlaTitle(manualReview: manualReview),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: c.trackBg,
              color: accent,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: c.greyMid,
                        height: 1,
                      ),
                    ),
                  ),
                _TimeBox(value: parts[i], accent: accent),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            remaining == Duration.zero
                ? tr('seller.payment_sla_expired_timer_hint')
                : tr(
                    'tariff.submitted_at',
                    args: [
                      DateFormat(
                        'dd MMM, HH:mm',
                        lang,
                      ).format(submittedAt.toLocal()),
                    ],
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.greyMid,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.value, required this.accent});

  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: c.fillSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.divider),
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: accent,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1,
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
    final c = SellerColors.of(context);
    final lang = context.locale.languageCode;
    final priceFormat = NumberFormat('#,###', lang);
    final icon = switch (args) {
      WalletTopUpPendingArgs() ||
      WalletDepositPendingArgs() => Iconsax.wallet_3,
      ArTokenPurchasePendingArgs() => Iconsax.flash_1,
      TariffSubscriptionPendingArgs() => Iconsax.crown_1,
    };
    final title = switch (args) {
      WalletTopUpPendingArgs() ||
      WalletDepositPendingArgs() => tr('seller.wallet_topup_section_title'),
      ArTokenPurchasePendingArgs(:final purchase) => tr(
        'seller.ar_token_count',
        namedArgs: {'count': '${purchase.tokens}'},
      ),
      TariffSubscriptionPendingArgs(:final subscription) => tr(
        'tariff.plan.${subscription.plan.code}_label',
      ),
    };
    final note = switch (args) {
      WalletTopUpPendingArgs() => tr('seller.manual_payment_wallet_note'),
      WalletDepositPendingArgs() => tr('seller.pending_online_subtitle'),
      ArTokenPurchasePendingArgs() when args.isManualReview => tr(
        'seller.manual_payment_ar_note',
      ),
      ArTokenPurchasePendingArgs() => tr('seller.pending_online_subtitle'),
      TariffSubscriptionPendingArgs(:final subscription) => tr(
        'tariff.period_${subscription.period.code}',
      ),
    };
    final amountLabel = switch (args) {
      WalletTopUpPendingArgs(:final amount) ||
      WalletDepositPendingArgs(
        :final amount,
      ) => '${priceFormat.format(amount)} so\'m',
      ArTokenPurchasePendingArgs(:final amountUzs) =>
        '${priceFormat.format(amountUzs)} so\'m',
      TariffSubscriptionPendingArgs(:final amount) =>
        '${priceFormat.format(amount)} so\'m',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: c.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: c.grey,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.fillFaint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(
                  tr('seller.wallet_amount_label'),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.greyMid,
                  ),
                ),
                const Spacer(),
                Text(
                  amountLabel,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (args case TariffSubscriptionPendingArgs()) ...[
            const SizedBox(height: 10),
            Text(
              tr('tariff.current_remains'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c.greyMid,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

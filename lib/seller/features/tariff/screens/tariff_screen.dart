import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/tariff.dart';
import '../../payments/manual_payment_pending_screen.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/seller_payment_refresh.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/tariff_bloc.dart';
import '../screens/tariff_payment_screen.dart';
import 'tariff_history_screen.dart';

// Every colour is read from `SellerColors.of(context)` per build so the screen
// flips with the seller theme — the pending/expiry banner brand tint uses
// `c.primarySoft` / `c.onPrimarySoft` (soft tint in light, low-luminance wash in
// dark). Plus Jakarta Sans is applied directly via `AppFonts.seller`.

class TariffScreen extends StatelessWidget {
  const TariffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TariffBloc(sl<TariffRepository>())..add(const TariffRequested()),
      child: const _TariffView(),
    );
  }
}

// =============================================================================
// 1. View — scaffold + listener that refreshes once admin resolves a pending
//    upgrade so the snapshot reflects the new plan / new history row. Also
//    listens to [SellerPaymentRefreshHub] so a Payme/Click tariff settle
//    refetches without a manual pull-to-refresh.
// =============================================================================
class _TariffView extends StatefulWidget {
  const _TariffView();

  @override
  State<_TariffView> createState() => _TariffViewState();
}

class _TariffViewState extends State<_TariffView> {
  StreamSubscription<PendingPaymentKind>? _refreshSub;

  @override
  void initState() {
    super.initState();
    _refreshSub = SellerPaymentRefreshHub.instance.stream.listen((kind) {
      if (kind == PendingPaymentKind.subscription && mounted) {
        context.read<TariffBloc>().add(const TariffRequested());
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TariffBloc, TariffState>(
      listenWhen: (a, b) {
        final wasPending = a.pending?.status.isPending ?? false;
        final nowResolved =
            wasPending && (b.pending == null || !b.pending!.status.isPending);
        return nowResolved && a.pending != null;
      },
      listener: (context, state) {
        context.read<TariffBloc>().add(const TariffRequested());
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: SellerColors.of(context).background,
          appBar: const _TariffAppBar(),
          body: switch (state.status) {
            TariffStatus.initial || TariffStatus.loading => const Center(
              child: BrandLoadingIndicator(),
            ),
            // Guard on the plan catalogue, not the snapshot — the 30s
            // watchCurrentPlan poll synthesizes a snapshot, which used to
            // swallow load failures into a silently empty body. With cards
            // already on screen a refresh failure keeps the stale catalogue.
            TariffStatus.failure when state.plans.isEmpty => ErrorState(
              message: state.error,
              onRetry: () =>
                  context.read<TariffBloc>().add(const TariffRequested()),
            ),
            // Backend reachable but zero plan rows configured — say so
            // instead of rendering a bare period toggle. Not a network
            // failure, so override ErrorState's default cloud-off icon and
            // "no internet" title with copy/glyph that reads as "nothing
            // configured here yet".
            TariffStatus.ready when state.plans.isEmpty => ErrorState(
              title: tr('tariff.plans_empty_title'),
              message: tr('tariff.plans_empty'),
              icon: Icons.inventory_2_outlined,
              onRetry: () =>
                  context.read<TariffBloc>().add(const TariffRequested()),
            ),
            _ => _TariffBody(state: state),
          },
        );
      },
    );
  }
}

// =============================================================================
// 2. App bar — clean white, bold title, history button on the right
// =============================================================================
class _TariffAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TariffAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return AppBar(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: c.ink,
      leading: IconButton(
        icon: Icon(Iconsax.arrow_left_2_copy, size: 22, color: c.ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        tr('tariff.title'),
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.ink,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          tooltip: tr('tariff.history'),
          icon: Icon(Iconsax.clock, size: 22, color: c.ink),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/seller-tariff-history'),
              builder: (_) => const TariffHistoryScreen(),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// =============================================================================
// 3. Body — pending banner, period toggle, and the four plan cards
// =============================================================================
class _TariffBody extends StatelessWidget {
  const _TariffBody({required this.state});

  final TariffState state;

  Future<void> _onUpgrade(BuildContext context, SubscriptionPlan plan) async {
    final result = await Navigator.of(context).push<TariffPaymentResult>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/seller-tariff-payment'),
        builder: (_) => TariffPaymentScreen(plan: plan, period: state.period),
      ),
    );
    if (!context.mounted) return;
    if (result == TariffPaymentResult.onlineLaunched) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(tr('tariff.online_launched_notice'))),
        );
    }
  }

  /// Free-plan product cap from the live catalog — feeds the trial warning
  /// copy ("faqat eng avval qo'shilgan N ta mahsulot aktiv qoladi").
  int get _freePlanLimit {
    for (final p in state.plans) {
      if (p.code == 'free') return p.maxProducts;
    }
    return TariffPlan.free.maxActiveProducts;
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = state.hasPending;
    final currentPlan = state.currentPlan;
    final currentPlanCode = currentPlan.code;
    final snapshot = state.snapshot;
    // The trial bonus gets its own prominent "Joriy tarif" card listing every
    // limit + the AI-3D quota; paid plans keep the slim expiry banner. Free has
    // neither.
    final onTrial = currentPlan.isTrial;
    final showCurrentBonusCard = snapshot != null && onTrial;
    final showExpiry =
        snapshot != null &&
        snapshot.expiresAt != null &&
        !currentPlan.isFree &&
        !onTrial;

    // The catalogue lists only real, purchasable upgrades: the backend now
    // returns 'trial' too (so we can render its current-plan features), so the
    // app always strips it from the buyable cards — plus Free while on the
    // trial, since dropping to Free is a downgrade, not an upgrade.
    final plans = state.plans
        .where((p) => !p.asEnum.isTrial && !(onTrial && p.code == 'free'))
        .toList(growable: false);

    // The current plan's server row — carries the localized `features_*`
    // bullets the current-plan card renders verbatim (same as upgrade cards).
    SubscriptionPlan? currentPlanData;
    for (final p in state.plans) {
      if (p.code == currentPlanCode) {
        currentPlanData = p;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        if (hasPending) ...[
          _PendingBanner(subscription: state.pending!),
          const SizedBox(height: 18),
        ],
        if (showCurrentBonusCard) ...[
          _CurrentPlanCard(snapshot: snapshot, plan: currentPlanData),
          const SizedBox(height: 18),
        ],
        if (showExpiry) ...[
          _ExpiryBanner(snapshot: snapshot, freePlanLimit: _freePlanLimit),
          const SizedBox(height: 18),
        ],
        if (plans.isNotEmpty) ...[
          if (showCurrentBonusCard) ...[
            Text(
              tr('tariff.upgrades_heading'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: SellerColors.of(context).ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
          ],
          _PeriodToggle(
            period: state.period,
            onChanged: (p) =>
                context.read<TariffBloc>().add(TariffPeriodChanged(p)),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < plans.length; i++) ...[
            _PlanCard(
              plan: plans[i],
              period: state.period,
              isCurrent: plans[i].code == currentPlanCode,
              isPending: hasPending,
              onUpgrade: () => _onUpgrade(context, plans[i]),
            ),
            if (i != plans.length - 1) const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

// =============================================================================
// 4. Pending banner — indigo tint, taps through to pending screen
// =============================================================================
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.subscription});

  final TariffSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final manualReview =
        subscription.paymentScreenshotUrl != null &&
        subscription.paymentScreenshotUrl!.isNotEmpty;
    return Material(
      color: c.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/seller-tariff-pending'),
            builder: (_) => ManualPaymentPendingScreen(
              args: TariffSubscriptionPendingArgs(subscription: subscription),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.onPrimarySoft.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Iconsax.clock, size: 20, color: c.onPrimarySoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(
                        'tariff.pending_banner_title',
                        args: [
                          tr('tariff.plan.${subscription.plan.code}_label'),
                        ],
                      ),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      manualReview
                          ? tr('tariff.pending_banner_subtitle')
                          : tr('tariff.pending_banner_subtitle_online'),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.grey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3_copy,
                size: 18,
                color: c.onPrimarySoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 4b. Expiry banner — active bonus/paid subscription countdown. Indigo gift
//     treatment while there's time; flips to a fixed amber warning inside the
//     last 5 days (mirrors the backend's pre-expiry push window). Like the
//     pending banner it sits on a fixed tint, so the inks stay constant.
// =============================================================================
class _ExpiryBanner extends StatelessWidget {
  const _ExpiryBanner({required this.snapshot, required this.freePlanLimit});

  final TariffSnapshot snapshot;
  final int freePlanLimit;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final plan = snapshot.plan;
    final daysLeft = snapshot.daysUntilExpiry ?? 0;
    final expiresAt = snapshot.expiresAt!.toLocal();
    final dateLabel =
        '${expiresAt.day.toString().padLeft(2, '0')}.'
        '${expiresAt.month.toString().padLeft(2, '0')}.'
        '${expiresAt.year}';
    final warning = snapshot.isExpiringSoon;

    final String title;
    final String subtitle;
    if (warning) {
      title = tr('tariff.expiry_warning_title', args: ['$daysLeft']);
      subtitle = plan.isTrial
          ? tr('tariff.expiry_warning_subtitle_trial', args: ['$freePlanLimit'])
          : tr('tariff.expiry_warning_subtitle_paid');
    } else {
      title = tr(
        'tariff.expiry_active_title',
        args: [tr('tariff.plan.${plan.code}_label')],
      );
      subtitle = tr(
        'tariff.expiry_active_subtitle',
        args: [dateLabel, '$daysLeft'],
      );
    }

    final accent = warning ? c.warning : c.onPrimarySoft;
    return Material(
      color: warning ? c.warningBg : c.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _ExpiryRing(
              fraction: snapshot.remainingFraction,
              accent: accent,
              icon: warning ? Iconsax.warning_2 : Iconsax.gift,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.grey,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4c. Expiry ring — the banner's leading glyph wrapped in a progress ring
//     showing the REMAINING share of the subscription window. Fills once with
//     a short ease-out sweep when the banner appears, then sits still — a
//     deliberately calm alternative to a ticking countdown (a 30-day window
//     has no business updating by the second). Falls back to a plain tinted
//     square when the window bounds aren't known.
// -----------------------------------------------------------------------------
class _ExpiryRing extends StatelessWidget {
  const _ExpiryRing({
    required this.fraction,
    required this.accent,
    required this.icon,
  });

  /// Remaining 0..1 share of the subscription window; null = unknown.
  final double? fraction;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final target = fraction;
    if (target == null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: accent),
      );
    }
    return SizedBox(
      width: 44,
      height: 44,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        child: Icon(icon, size: 18, color: accent),
        builder: (context, value, child) => Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 3.5,
                strokeCap: StrokeCap.round,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.15),
              ),
            ),
            child!,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 4d. Current-plan card — the prominent "Joriy tarif" panel for a seller on the
//     trial bonus. Unlike the slim expiry banner it spells out everything the
//     seller currently has — products, commission, sets, and (the headline of
//     the trial strategy) the AI-3D quota — plus the expiry date + countdown.
//     The feature bullets are the server's localized `features_*` for the trial
//     row, rendered verbatim by the SAME `_FeatureList` the upgrade cards use,
//     so the 3 AI 3D models show exactly as authored. If the
//     plan row is momentarily unavailable it falls back to a synthesized list
//     built from the enum + snapshot.
// =============================================================================
class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.snapshot, this.plan});

  final TariffSnapshot snapshot;

  /// The active plan's server row (`features_*` source). Null only if the
  /// catalogue hasn't loaded it yet — then [_limitLines] supplies a fallback.
  final SubscriptionPlan? plan;

  static String _commissionLabel(double rate) =>
      rate == rate.roundToDouble() ? '${rate.toInt()}' : '$rate';

  List<String> _limitLines() {
    final planEnum = snapshot.plan;
    final cap = plan?.maxProducts ?? snapshot.effectiveMaxProducts;
    final commission = plan?.commissionRate ?? planEnum.commissionRate;
    final allowsSets = plan?.allowsSets ?? planEnum.allowsSets;
    final lines = <String>[
      cap < 0
          ? tr('tariff.current_limit_products_unlimited')
          : tr('tariff.current_limit_products', args: ['$cap']),
      tr(
        'tariff.current_limit_commission',
        args: [_commissionLabel(commission.toDouble())],
      ),
    ];
    if (allowsSets) lines.add(tr('tariff.current_limit_sets'));
    final limit = snapshot.ai3dLimit;
    if (limit != null && limit >= 0) {
      lines.add(
        tr(
          'tariff.current_limit_ai3d',
          args: ['${snapshot.ai3dUsed}', '$limit'],
        ),
      );
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final planEnum = snapshot.plan;
    final expiresAt = snapshot.expiresAt?.toLocal();
    final daysLeft = snapshot.daysUntilExpiry ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.sellerPrimary.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ExpiryRing(
                fraction: snapshot.remainingFraction,
                accent: c.onPrimarySoft,
                icon: Iconsax.gift,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          tr('tariff.plan.${planEnum.code}_label'),
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sellerPrimary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            tr('tariff.current_chip'),
                            style: const TextStyle(
                              fontFamily: AppFonts.seller,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      expiresAt == null
                          ? tr('tariff.current_plan_title')
                          : tr(
                              'tariff.current_expiry',
                              args: [_fmtDate(expiresAt), '$daysLeft'],
                            ),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.grey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: AppColors.sellerPrimary.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 12),
          // Prefer the server's localized features (identical to upgrade cards);
          // fall back to the synthesized limit list only if the row is missing.
          if (plan != null && plan!.featuresForLocale(_lang).isNotEmpty)
            _FeatureList(plan: plan!)
          else
            for (final line in _limitLines()) _FeatureRow(text: line),
        ],
      ),
    );
  }

  String get _lang => AppTranslations.instance.locale.languageCode;

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year}';
}

// =============================================================================
// 5. Period toggle — pill segmented control with indigo active state +
//    "-17%" badge that swaps colour depending on which side is active.
// =============================================================================
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});

  final BillingPeriod period;
  final ValueChanged<BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SellerColors.of(context).fillSoft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          for (final p in BillingPeriod.values)
            Expanded(
              child: _PeriodTab(
                isActive: period == p,
                label: tr('tariff.period_${p.code}'),
                showSavingsBadge: p == BillingPeriod.yearly,
                savingsLabel: tr('tariff.yearly_save'),
                onTap: () => onChanged(p),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.isActive,
    required this.label,
    required this.showSavingsBadge,
    required this.savingsLabel,
    required this.onTap,
  });

  final bool isActive;
  final String label;
  final bool showSavingsBadge;
  final String savingsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.sellerPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.sellerPrimary.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : SellerColors.of(context).grey,
                letterSpacing: -0.1,
              ),
            ),
            if (showSavingsBadge) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.sellerPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  savingsLabel,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 6. Plan card — distinct treatment for free / basic / pro / enterprise.
//    Pro gets the indigo border + "TAVSIYA" ribbon. Enterprise leans on
//    a dark charcoal accent so it reads as the power tier.
// =============================================================================
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.period,
    required this.isCurrent,
    required this.isPending,
    required this.onUpgrade,
  });

  final SubscriptionPlan plan;
  final BillingPeriod period;
  final bool isCurrent;
  final bool isPending;
  final VoidCallback onUpgrade;

  /// Indigo border + ribbon are tied to the DB's `is_recommended` flag
  /// so admins can move the spotlight to any plan without an app release.
  bool get _isRecommended => plan.isRecommended;

  /// Enterprise's dark-charcoal accent is purely cosmetic — keep it pinned
  /// to the top tier (most expensive plan with unlimited products).
  bool get _isEnterprise => plan.hasUnlimitedProducts;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: _isRecommended
                ? Border.all(color: AppColors.sellerPrimary, width: 1.4)
                : Border.all(color: c.outline, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: dark
                      ? (_isRecommended ? 0.34 : 0.28)
                      : (_isRecommended ? 0.08 : 0.05),
                ),
                blurRadius: _isRecommended ? 20 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanHeader(
                plan: plan,
                isCurrent: isCurrent,
                isEnterprise: _isEnterprise,
              ),
              const SizedBox(height: 8),
              _PriceRow(plan: plan, period: period),
              const SizedBox(height: 12),
              _FeatureList(plan: plan),
              const SizedBox(height: 14),
              _PlanCta(
                plan: plan,
                isCurrent: isCurrent,
                isPending: isPending,
                isEnterprise: _isEnterprise,
                onPressed: onUpgrade,
              ),
            ],
          ),
        ),
        if (_isRecommended)
          Positioned(
            top: -10,
            right: 18,
            child: _RecommendedRibbon(label: tr('tariff.recommended_chip')),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 6a. Header — plan name + current/enterprise pill
// -----------------------------------------------------------------------------
class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.plan,
    required this.isCurrent,
    required this.isEnterprise,
  });

  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool isEnterprise;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isEnterprise) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.ink,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Iconsax.crown_1, size: 18, color: c.surface),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            plan.name,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: c.ink,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
        ),
        if (isCurrent)
          _StaticChip(
            label: tr('tariff.current_chip'),
            background: c.fillSoft,
            foreground: c.grey,
            icon: Iconsax.tick_circle,
          ),
      ],
    );
  }
}

class _StaticChip extends StatelessWidget {
  const _StaticChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: foreground,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6b. Recommended ribbon — sits half-overlapping the Pro card top-right
// -----------------------------------------------------------------------------
class _RecommendedRibbon extends StatelessWidget {
  const _RecommendedRibbon({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sellerPrimary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.sellerPrimary.withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.star_1, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6c. Price row — animates between monthly and yearly totals
// -----------------------------------------------------------------------------
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.plan, required this.period});

  final SubscriptionPlan plan;
  final BillingPeriod period;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    if (plan.isFree) {
      return Text(
        tr('tariff.price_free'),
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: c.ink,
          letterSpacing: -0.6,
          height: 1.0,
        ),
      );
    }

    final price = plan.priceFor(period).toInt();
    final suffix = period == BillingPeriod.monthly
        ? '/ ${tr('tariff.month')}'
        : '/ ${tr('tariff.year')}';
    final savings = period == BillingPeriod.yearly ? plan.yearlySavingsUzs : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Row(
            key: ValueKey('${plan.code}.${period.code}'),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPrice(price),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.6,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  "so'm",
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  suffix,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (savings > 0) ...[
          const SizedBox(height: 4),
          Text(
            tr('tariff.yearly_save_amount', args: [_formatPrice(savings)]),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.sellerPrimary,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 6d. Feature list — product cap is always interpolated from live
//     `max_products`; remaining bullets come from `features_{uz,ru,en}`
//     (skipping the server's first product-cap line to avoid a duplicate).
// -----------------------------------------------------------------------------
class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslations.instance.locale.languageCode;

    final productLine = plan.hasUnlimitedProducts
        ? tr('tariff.current_limit_products_unlimited')
        : tr('tariff.current_limit_products', args: ['${plan.maxProducts}']);

    final serverLines = plan.featuresForLocale(lang);
    // Seed authors the product cap as the first bullet — drop it so the
    // interpolated line above is the single source of truth.
    final rest = serverLines.length > 1
        ? serverLines.sublist(1)
        : const <String>[];

    final lines = <String>[productLine, ...rest];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final text in lines) _FeatureRow(text: text)],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle,
              size: 16,
              color: AppColors.sellerPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: SellerColors.of(context).ink,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6e. CTA — "Tanlash" / "Joriy tarif" / "Tasdiqlash kutilmoqda" / Free swap
//     Enterprise gets a dark charcoal fill so it reads distinct from Pro.
// -----------------------------------------------------------------------------
class _PlanCta extends StatelessWidget {
  const _PlanCta({
    required this.plan,
    required this.isCurrent,
    required this.isPending,
    required this.isEnterprise,
    required this.onPressed,
  });

  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool isPending;
  final bool isEnterprise;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final disabled = isCurrent || isPending || plan.isFree;
    final label = isCurrent
        ? tr('tariff.cta_current')
        : (isPending
              ? tr('tariff.cta_pending')
              : (plan.isFree
                    ? tr('tariff.cta_downgrade')
                    : tr('tariff.cta_upgrade')));

    final Color background;
    final Color foreground;
    if (isCurrent) {
      background = c.fillSoft;
      foreground = c.greyMid;
    } else if (isPending) {
      background = c.fillSoft;
      foreground = c.grey;
    } else if (isEnterprise) {
      // Ink fill flips to near-white in dark; the surface colour keeps the
      // label legible against it.
      background = c.ink;
      foreground = c.surface;
    } else {
      background = AppColors.sellerPrimary;
      foreground = Colors.white;
    }

    return SizedBox(
      width: double.infinity,
      height: 42,
      child: FilledButton(
        onPressed: disabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background,
          disabledForegroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: foreground,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 7. Price formatter — `299000` → `299 000` (space-separated, locale-agnostic)
// =============================================================================
String _formatPrice(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  final n = s.length;
  for (var i = 0; i < n; i++) {
    if (i > 0 && (n - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

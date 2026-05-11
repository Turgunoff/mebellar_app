import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/tariff_bloc.dart';
import '../widgets/payment_instructions_sheet.dart';
import 'tariff_history_screen.dart';
import 'tariff_pending_screen.dart';

// Local design tokens. Repeated across the seller surface so each screen
// reads top-to-bottom without theme indirection. Plus Jakarta Sans is
// applied directly via `GoogleFonts.plusJakartaSans` so the M3 surface
// tint never leaks into our white cards.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _outline = Color(0xFFE3E3E3);
const _fillSoft = Color(0xFFF3F3F3);
const _terracottaTint = Color(0x14C27A5F);

class TariffScreen extends StatelessWidget {
  const TariffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TariffBloc(sl<TariffRepository>())
        ..add(const TariffRequested()),
      child: const _TariffView(),
    );
  }
}

// =============================================================================
// 1. View — scaffold + listener that refreshes once admin resolves a pending
//    upgrade so the snapshot reflects the new plan / new history row.
// =============================================================================
class _TariffView extends StatelessWidget {
  const _TariffView();

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
          backgroundColor: AppColors.lightBackground,
          appBar: const _TariffAppBar(),
          body: switch (state.status) {
            TariffStatus.initial ||
            TariffStatus.loading =>
              const Center(
                child: CircularProgressIndicator(color: AppColors.terracotta),
              ),
            TariffStatus.failure when state.snapshot == null => ErrorState(
                message: state.error,
                onRetry: () => context
                    .read<TariffBloc>()
                    .add(const TariffRequested()),
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
    return AppBar(
      backgroundColor: AppColors.lightBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: _ink,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left_2, size: 22, color: _ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        tr('tariff.title'),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          tooltip: tr('tariff.history'),
          icon: const Icon(Iconsax.clock, size: 22, color: _ink),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
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

  Future<void> _onUpgrade(BuildContext context, TariffPlan plan) async {
    final result = await showPaymentInstructionsSheet(
      context,
      plan: plan,
      period: state.period,
    );
    if (result != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TariffPendingScreen(subscription: result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = state.hasPending;
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
        _PeriodToggle(
          period: state.period,
          onChanged: (p) => context
              .read<TariffBloc>()
              .add(TariffPeriodChanged(p)),
        ),
        const SizedBox(height: 20),
        for (final plan in TariffPlan.values) ...[
          _PlanCard(
            plan: plan,
            period: state.period,
            isCurrent: plan == state.currentPlan,
            isPending: hasPending,
            onUpgrade: () => _onUpgrade(context, plan),
          ),
          if (plan != TariffPlan.values.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// =============================================================================
// 4. Pending banner — terracotta tint, taps through to pending screen
// =============================================================================
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.subscription});

  final TariffSubscription subscription;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _terracottaTint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TariffPendingScreen(subscription: subscription),
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
                  color: AppColors.terracotta.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Iconsax.clock,
                  size: 20,
                  color: AppColors.terracotta,
                ),
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
                        args: [tr('tariff.plan.${subscription.plan.code}_label')],
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('tariff.pending_banner_subtitle'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Iconsax.arrow_right_3,
                size: 18,
                color: AppColors.terracotta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. Period toggle — pill segmented control with terracotta active state +
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
        color: _fillSoft,
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
          color: isActive ? AppColors.terracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.terracotta.withValues(alpha: 0.25),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : _grey,
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
                      : AppColors.terracotta,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  savingsLabel,
                  style: GoogleFonts.plusJakartaSans(
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
//    Pro gets the terracotta border + "TAVSIYA" ribbon. Enterprise leans on
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

  final TariffPlan plan;
  final BillingPeriod period;
  final bool isCurrent;
  final bool isPending;
  final VoidCallback onUpgrade;

  bool get _isPro => plan == TariffPlan.pro;
  bool get _isEnterprise => plan == TariffPlan.enterprise;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: _isPro
                ? Border.all(color: AppColors.terracotta, width: 1.4)
                : Border.all(color: _outline, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: _isPro ? 0.08 : 0.05,
                ),
                blurRadius: _isPro ? 20 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanHeader(
                plan: plan,
                isCurrent: isCurrent,
                isEnterprise: _isEnterprise,
              ),
              const SizedBox(height: 12),
              _PriceRow(plan: plan, period: period),
              const SizedBox(height: 16),
              _FeatureList(plan: plan),
              const SizedBox(height: 18),
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
        if (_isPro)
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

  final TariffPlan plan;
  final bool isCurrent;
  final bool isEnterprise;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isEnterprise) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Iconsax.crown_1, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            tr('tariff.plan.${plan.code}_label'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.4,
              height: 1.1,
            ),
          ),
        ),
        if (isCurrent)
          _StaticChip(
            label: tr('tariff.current_chip'),
            background: _fillSoft,
            foreground: _grey,
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
            style: GoogleFonts.plusJakartaSans(
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
        color: AppColors.terracotta,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.terracotta.withValues(alpha: 0.32),
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
            style: GoogleFonts.plusJakartaSans(
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

  final TariffPlan plan;
  final BillingPeriod period;

  @override
  Widget build(BuildContext context) {
    if (plan.isFree) {
      return Text(
        tr('tariff.price_free'),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: _ink,
          letterSpacing: -0.8,
          height: 1.0,
        ),
      );
    }

    final price = plan.priceFor(period);
    final suffix = period == BillingPeriod.monthly
        ? '/ ${tr('tariff.month')}'
        : '/ ${tr('tariff.year')}';

    return AnimatedSwitcher(
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.8,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              "so'm",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              suffix,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6d. Feature list — terracotta tick_circle icons + Jakarta body copy
// -----------------------------------------------------------------------------
class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.plan});

  final TariffPlan plan;

  String _productLimitText() {
    return plan.isUnlimited
        ? tr('tariff.feature_unlimited_products')
        : tr('tariff.feature_products', args: ['${plan.maxActiveProducts}']);
  }

  @override
  Widget build(BuildContext context) {
    final features = <String>[
      _productLimitText(),
      tr('tariff.feature_${plan.code}_1'),
      tr('tariff.feature_${plan.code}_2'),
      if (plan == TariffPlan.pro || plan == TariffPlan.enterprise)
        tr('tariff.feature_${plan.code}_3'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final text in features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Iconsax.tick_circle,
                    size: 18,
                    color: AppColors.terracotta,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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

  final TariffPlan plan;
  final bool isCurrent;
  final bool isPending;
  final bool isEnterprise;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
      background = _fillSoft;
      foreground = _greyMid;
    } else if (isPending) {
      background = _fillSoft;
      foreground = _grey;
    } else if (isEnterprise) {
      background = _ink;
      foreground = Colors.white;
    } else {
      background = AppColors.terracotta;
      foreground = Colors.white;
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: disabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background,
          disabledForegroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
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

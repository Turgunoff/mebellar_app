import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Shared tokens + helpers for the seller dashboard widgets.
///
/// Mirrors the seller-mode convention (hardcoded Uzbek copy, Plus Jakarta Sans
/// inherited from the theme — so `fontFamily` is intentionally omitted in every
/// `TextStyle`). **Every colour is a `const` alias of an [AppColors] seller
/// token** — there are no raw hex literals here, so the seller palette lives in
/// one place. The aliases stay `const` so widgets can keep `const TextStyle(...)`;
/// the light/dark split lives in [SellerColors] and is wired in when dark mode
/// ships (at which point these become brightness-resolved getters).
class DashKit {
  const DashKit._();

  static const Color ink = AppColors.sellerInk;
  static const Color grey = AppColors.sellerGrey;
  static const Color greyFaint = AppColors.sellerGreyFaint;
  static const Color greyMid = AppColors.sellerGreyMid;
  static const Color hairline = AppColors.sellerDivider;

  static const Color indigo = AppColors.sellerPrimary; // #3949AB
  static const Color indigoDeep = AppColors.sellerPrimaryDeep; // #283593
  static const Color indigoTint = AppColors.sellerPrimaryTint; // #E8EAF6
  static const Color indigoBright = AppColors.sellerPrimaryBright; // #4554C4

  static const Color positive = AppColors.sellerPositive;
  static const Color positiveBg = AppColors.sellerPositiveBg;
  static const Color negative = AppColors.sellerNegative;
  static const Color negativeBg = AppColors.sellerNegativeBg;
  static const Color gold = AppColors.sellerGold;
  static const Color goldBright = AppColors.sellerGoldBright;
  static const Color goldBg = AppColors.sellerGoldBg;

  static const Color imageBg = AppColors.sellerImageBg;
  static const Color fillSoft = AppColors.sellerFillSoft;
  static const Color lockedBg = AppColors.sellerLockedBg;
  static const Color ringTrack = AppColors.sellerRingTrack;
  static const Color trackBg = AppColors.sellerTrackBg;

  // Leaderboard medals.
  static const Color silver = AppColors.sellerSilver;
  static const Color silverBg = AppColors.sellerSilverBg;
  static const Color bronze = AppColors.sellerBronze;
  static const Color bronzeBg = AppColors.sellerBronzeBg;

  /// Soft elevation shared by every card on the dashboard.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  /// "9 650 000" — thin-space grouped whole UZS, no decimals.
  static String money(num amount) {
    final s = amount.round().abs().toString();
    final buf = StringBuffer(amount < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// "9.7M" / "812K" / "640" — compact form for tight cells.
  static String compactMoney(num amount) {
    final v = amount.toDouble();
    if (v.abs() >= 1e9) return '${(v / 1e9).toStringAsFixed(1)} mlrd';
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(1)} mln';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(0)} ming';
    return v.round().toString();
  }
}

/// Standard white dashboard card: 20px radius, soft shadow, 16px inset by
/// default. Children override [padding] to bleed charts to the edges.
class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: DashKit.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
      ),
    );
  }
}

/// Bold section heading + optional trailing action (e.g. "Hammasi" link).
class DashSectionHeader extends StatelessWidget {
  const DashSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DashKit.ink,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DashKit.grey,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// "+18.4%" / "-8.0%" / "—" trend pill. Used on the hero card, KPI tiles and
/// leaderboard rows. `lowerIsBetter` flips the colour rule (e.g. for the
/// pending-orders metric, where a drop is good).
class DashTrendChip extends StatelessWidget {
  const DashTrendChip({
    super.key,
    required this.deltaPercent,
    this.lowerIsBetter = false,
    this.compact = false,
  });

  final double? deltaPercent;
  final bool lowerIsBetter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPercent;
    if (delta == null) {
      return _shell(
        bg: const Color(0x14757575),
        fg: DashKit.grey,
        icon: Icons.remove_rounded,
        label: '—',
      );
    }
    final up = delta >= 0;
    final good = lowerIsBetter ? !up : up;
    final fg = good ? DashKit.positive : DashKit.negative;
    final bg = good ? DashKit.positiveBg : DashKit.negativeBg;
    return _shell(
      bg: bg,
      fg: fg,
      icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      label: '${up ? '+' : ''}${delta.toStringAsFixed(1)}%',
    );
  }

  Widget _shell({
    required Color bg,
    required Color fg,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: fg),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: fg,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

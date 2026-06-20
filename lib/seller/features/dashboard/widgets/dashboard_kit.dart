import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Fixed (brightness-independent) tokens + helpers for the seller dashboard.
///
/// Mirrors the seller-mode convention (hardcoded Uzbek copy, Plus Jakarta Sans
/// inherited from the theme — so `fontFamily` is omitted in every `TextStyle`).
///
/// Only colours that read the SAME on light and dark backgrounds live here as
/// `const` aliases of [AppColors] (brand indigo, status intents, gold, medals).
/// **Adaptive** colours (ink, greys, surfaces, dividers, locked/ring/track) are
/// NOT here — widgets read those from `SellerColors.of(context)` so they flip
/// with the theme. Grab `final c = SellerColors.of(context)` at the top of a
/// `build` and use `c.ink` / `c.surface` / `c.divider`.
class DashKit {
  const DashKit._();

  static const Color indigo = AppColors.sellerPrimary; // #3949AB
  static const Color indigoDeep = AppColors.sellerPrimaryDeep; // #283593
  static const Color indigoTint = AppColors.sellerPrimaryTint; // #E8EAF6
  static const Color indigoBright = AppColors.sellerPrimaryBright; // #4554C4

  // Gold reads on both backgrounds, so the achievement accent stays fixed.
  static const Color gold = AppColors.sellerGold;
  static const Color goldBright = AppColors.sellerGoldBright;

  // NOTE: status fills (positive / negative / gold / medal *Bg*) are NOT here —
  // they flip with the theme, so read them off `SellerColors.of(context)`
  // (`c.positiveBg`, `c.goldBg`, `c.silverBg`, …) inside `build`.

  /// Soft elevation shared by every card on the dashboard. A touch stronger in
  /// dark mode so cards still separate from the near-black background.
  static List<BoxShadow> cardShadow([
    Brightness brightness = Brightness.light,
  ]) {
    final dark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.32 : 0.06),
        blurRadius: dark ? 18 : 14,
        offset: const Offset(0, 4),
      ),
    ];
  }

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
    final c = SellerColors.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: DashKit.cardShadow(Theme.of(context).brightness),
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
    final c = SellerColors.of(context);
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.grey,
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
    final c = SellerColors.of(context);
    final delta = deltaPercent;
    if (delta == null) {
      return _shell(
        bg: c.grey.withValues(alpha: 0.10),
        fg: c.grey,
        icon: Icons.remove_rounded,
        label: '—',
      );
    }
    final up = delta >= 0;
    final good = lowerIsBetter ? !up : up;
    final fg = good ? c.positive : c.negative;
    final bg = good ? c.positiveBg : c.negativeBg;
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

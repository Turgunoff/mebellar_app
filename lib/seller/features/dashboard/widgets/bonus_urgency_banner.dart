import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../tariff/screens/tariff_screen.dart';
import 'dashboard_kit.dart';

/// FOMO banner shown ONLY while the seller is on the `trial` bonus plan
/// (`SellerDashboardData.plan.isTrial`). It pairs a countdown to the bonus
/// expiry with the AI-3D quota meter so a fresh seller is nudged to spend their
/// (strictly capped) free 3D models before the window closes — the whole point
/// of the trial-bonus strategy.
///
/// Slim indigo-gradient card to grab attention without dominating the
/// dashboard. Tapping it (or the outline CTA) opens the tariff screen so the
/// seller can see exactly what the bonus unlocks and which plan to buy next.
class BonusUrgencyBanner extends StatelessWidget {
  const BonusUrgencyBanner({
    super.key,
    required this.daysLeft,
    required this.ai3dUsed,
    required this.ai3dLimit,
  });

  /// Whole days until the bonus expires. Null/≤0 is treated as "today".
  final int? daysLeft;

  /// AI 3D models generated so far.
  final int ai3dUsed;

  /// The bonus quota (3 for the trial plan). Falls back to 3 if the server ever
  /// omits it, so the meter never divides by zero.
  final int? ai3dLimit;

  void _openTariff(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => const TariffScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final days = daysLeft ?? 0;
    final limit = (ai3dLimit == null || ai3dLimit! <= 0) ? 3 : ai3dLimit!;
    final used = ai3dUsed < 0 ? 0 : ai3dUsed;
    final fraction = (used / limit).clamp(0.0, 1.0);
    final allUsed = used >= limit;

    final title = days <= 0
        ? tr('dashboard.bonus_banner_title_today')
        : tr('dashboard.bonus_banner_title', namedArgs: {'days': '$days'});

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openTariff(context),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [DashKit.indigoBright, DashKit.indigoDeep],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: DashKit.indigo.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Iconsax.gift,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              // AI-3D quota meter — the financial-cap "{used} / {limit}".
              Row(
                children: [
                  Text(
                    tr('dashboard.bonus_banner_ai3d_label'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    allUsed
                        ? tr('dashboard.bonus_banner_ai3d_done')
                        : tr(
                            'dashboard.bonus_banner_ai3d_value',
                            namedArgs: {'used': '$used', 'limit': '$limit'},
                          ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    allUsed ? DashKit.goldBright : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _OutlineCta(
                label: tr('dashboard.bonus_banner_cta'),
                onTap: () => _openTariff(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineCta extends StatelessWidget {
  const _OutlineCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Iconsax.arrow_right_3_copy, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

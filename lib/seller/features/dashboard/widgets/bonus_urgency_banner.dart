import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../tariff/screens/tariff_screen.dart';
import 'dashboard_kit.dart';

/// Compact FOMO strip for sellers on the `trial` bonus plan — countdown +
/// AI-3D quota in ~72px instead of a tall card with a full-width CTA.
class BonusUrgencyBanner extends StatelessWidget {
  const BonusUrgencyBanner({
    super.key,
    required this.daysLeft,
    required this.ai3dUsed,
    required this.ai3dLimit,
  });

  final int? daysLeft;
  final int ai3dUsed;
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openTariff(context),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [DashKit.indigoBright, DashKit.indigoDeep],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: DashKit.indigo.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Iconsax.gift,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Iconsax.arrow_right_3_copy,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    tr('dashboard.bonus_banner_ai3d_label'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          allUsed ? DashKit.goldBright : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    allUsed
                        ? tr('dashboard.bonus_banner_ai3d_done')
                        : tr(
                            'dashboard.bonus_banner_ai3d_value',
                            namedArgs: {'used': '$used', 'limit': '$limit'},
                          ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

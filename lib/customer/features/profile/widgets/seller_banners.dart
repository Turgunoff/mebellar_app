import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../home/widgets/premium/premium_tokens.dart';

/// Premium "become a seller" call-to-action shown when the user has no seller
/// application on file.
class BecomeSellerBanner extends StatelessWidget {
  const BecomeSellerBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PremiumTokens.accent, PremiumTokens.accentDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumTokens.accentDeep.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Iconsax.shop, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                'Sotuvchi bo\'lish',
                style: PremiumTokens.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Woody'da o'z biznesingizni boshlang",
            style: PremiumTokens.display(
              size: 22,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Mahsulotlaringizni minglab xaridorlarga "
            "yetkazing va sotuvni bugundan boshlang.",
            style: PremiumTokens.body(
              size: 13,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sotuvchi bo'lish",
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: PremiumTokens.accentDeep,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Iconsax.arrow_right_1,
                        size: 16,
                        color: PremiumTokens.accentDeep,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while a seller application is awaiting review.
class SellerPendingBanner extends StatelessWidget {
  const SellerPendingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PremiumTokens.accent.withValues(alpha: 0.3)),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PremiumTokens.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 22,
              color: PremiumTokens.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ko'rib chiqilmoqda",
                  style: PremiumTokens.body(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Arizangiz 24 soat ichida ko'rib chiqiladi.",
                  style: PremiumTokens.body(
                    size: 13,
                    color: pt.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown once the seller application is approved — routes into seller mode.
class SellerApprovedBanner extends StatelessWidget {
  const SellerApprovedBanner({super.key, required this.onOpenDashboard});

  final VoidCallback onOpenDashboard;

  static const Color _accent = Color(0xFF2F9E6E); // emerald
  static const Color _accentDeep = Color(0xFF237955);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent, _accentDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: _accentDeep.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'TASDIQLANDI',
                style: PremiumTokens.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Do'koningiz tasdiqlandi!",
            style: PremiumTokens.display(
              size: 22,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Siz endi Woody platformasida rasmiy sotuvchisiz.",
            style: PremiumTokens.body(
              size: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onOpenDashboard,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sotuvchi paneliga o'tish",
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: _accentDeep,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Iconsax.arrow_right_1,
                        size: 16,
                        color: _accentDeep,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when a seller application was rejected — surfaces the reason and an
/// edit-and-resubmit affordance.
class SellerRejectedBanner extends StatelessWidget {
  const SellerRejectedBanner({
    super.key,
    required this.reason,
    required this.onEdit,
  });

  final String? reason;
  final VoidCallback onEdit;

  static const Color _errorColor = Color(0xFFE05A4A);

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final hasReason = reason != null && reason!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _errorColor.withValues(alpha: 0.4)),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _errorColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 24,
                  color: _errorColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rad etildi',
                      style: PremiumTokens.body(
                        size: 15,
                        weight: FontWeight.w600,
                        color: _errorColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasReason
                          ? reason!.trim()
                          : 'Arizangiz rad etildi. Iltimos, ma\'lumotlarni '
                                'qayta tekshirib, qaytadan yuboring.',
                      style: PremiumTokens.body(
                        size: 13,
                        color: pt.grey,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Arizani tahrirlash'),
              style: FilledButton.styleFrom(
                backgroundColor: _errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

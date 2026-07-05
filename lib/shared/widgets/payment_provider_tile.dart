import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../r.dart';
import '../repositories/payment_repository.dart';

/// Official Payme / Click brand colours and logo-chip backgrounds used across
/// checkout, wallet top-up, tariff purchase, and AR-token purchase.
abstract final class PaymentBrand {
  static const paymeTeal = Color(0xFF00A19A);
  static const clickBlue = Color(0xFF0073FF);
  static const paymeChip = Colors.white;
  static const clickChip = Color(0xFF0A1730);
}

extension PaymentProviderBrand on PaymentProvider {
  Color get brandColor => switch (this) {
    PaymentProvider.payme => PaymentBrand.paymeTeal,
    PaymentProvider.click => PaymentBrand.clickBlue,
  };

  Color get logoChipColor => switch (this) {
    PaymentProvider.payme => PaymentBrand.paymeChip,
    PaymentProvider.click => PaymentBrand.clickChip,
  };

  String get logoAsset => switch (this) {
    PaymentProvider.payme => AssetLogo.payme,
    PaymentProvider.click => AssetLogo.click,
  };
}

/// Visual context for [PaymentProviderTile] — customer checkout vs seller flows.
enum PaymentProviderTileStyle { customer, seller }

/// Trailing affordance on a payment-provider tile.
enum PaymentProviderTileTrailing {
  /// Radio-style selection ring (checkout, wallet, AR-token).
  radio,

  /// Launch arrow / spinner (tariff online pay).
  action,
}

/// Unified Payme / Click tile — the checkout design used everywhere.
class PaymentProviderTile extends StatelessWidget {
  const PaymentProviderTile({
    super.key,
    required this.provider,
    required this.label,
    required this.selected,
    required this.onTap,
    this.style = PaymentProviderTileStyle.customer,
    this.trailing = PaymentProviderTileTrailing.radio,
    this.comingSoon = false,
    this.busy = false,
    this.dimmed = false,
  });

  final PaymentProvider provider;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final PaymentProviderTileStyle style;
  final PaymentProviderTileTrailing trailing;
  final bool comingSoon;
  final bool busy;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final brand = provider.brandColor;
    final disabled = comingSoon || onTap == null;
    final effectiveDimmed = dimmed && !busy;

    final (:fill, :border, :labelColor) = switch (style) {
      PaymentProviderTileStyle.customer => _customerColors(context, brand),
      PaymentProviderTileStyle.seller => _sellerColors(context, brand),
    };

    return Opacity(
      opacity: effectiveDimmed ? 0.45 : (comingSoon ? 0.72 : 1),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected && !comingSoon
                ? brand.withValues(alpha: 0.08)
                : fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected && !comingSoon ? brand : border,
              width: selected && !comingSoon ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 38,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: provider.logoChipColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.asset(
                  provider.logoAsset,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: switch (style) {
                        PaymentProviderTileStyle.customer => PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: labelColor,
                        ),
                        PaymentProviderTileStyle.seller => TextStyle(
                          fontFamily: AppFonts.seller,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: labelColor,
                        ),
                      },
                    ),
                    if (comingSoon) ...[
                      const SizedBox(height: 2),
                      Text(
                        tr('payment.coming_soon_badge'),
                        style: switch (style) {
                          PaymentProviderTileStyle.customer =>
                            PremiumTokens.body(
                              size: 11,
                              weight: FontWeight.w600,
                              color: brand,
                            ),
                          PaymentProviderTileStyle.seller => TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: brand,
                          ),
                        },
                      ),
                    ],
                  ],
                ),
              ),
              _Trailing(
                trailing: trailing,
                brand: brand,
                selected: selected && !comingSoon,
                busy: busy,
                style: style,
                borderColor: border,
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({Color fill, Color border, Color labelColor}) _customerColors(
    BuildContext context,
    Color brand,
  ) {
    final pt = PremiumTokens.of(context);
    return (fill: pt.imageBg, border: Colors.transparent, labelColor: pt.dark);
  }

  ({Color fill, Color border, Color labelColor}) _sellerColors(
    BuildContext context,
    Color brand,
  ) {
    final c = SellerColors.of(context);
    return (fill: c.fillSoft, border: c.divider, labelColor: c.ink);
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.trailing,
    required this.brand,
    required this.selected,
    required this.busy,
    required this.style,
    required this.borderColor,
  });

  final PaymentProviderTileTrailing trailing;
  final Color brand;
  final bool selected;
  final bool busy;
  final PaymentProviderTileStyle style;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return switch (trailing) {
      PaymentProviderTileTrailing.radio => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? brand : Colors.transparent,
          border: Border.all(
            color: selected
                ? brand
                : switch (style) {
                    PaymentProviderTileStyle.customer => PremiumTokens.of(
                      context,
                    ).greyLight,
                    PaymentProviderTileStyle.seller => borderColor,
                  },
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 12, color: Colors.white)
            : null,
      ),
      PaymentProviderTileTrailing.action =>
        busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: brand,
                ),
              )
            : Icon(Iconsax.arrow_right_3, size: 20, color: brand),
    };
  }
}

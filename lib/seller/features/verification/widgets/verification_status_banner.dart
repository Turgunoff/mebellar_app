import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/verification_status.dart';

/// Sticky banner that summarises the current verification state. Shown on
/// the seller dashboard *and* the verification screen so the user always
/// knows where they stand.
class VerificationStatusBanner extends StatelessWidget {
  const VerificationStatusBanner({
    super.key,
    required this.status,
    this.rejectionReason,
    this.onTap,
  });

  final VerificationStatus status;
  final String? rejectionReason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(SellerColors.of(context), status);
    return Material(
      color: palette.bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(_iconFor(status), color: palette.fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('verification.banner.${status.code}_title'),
                      style: TextStyle(
                        color: palette.fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      rejectionReason ??
                          tr('verification.banner.${status.code}_subtitle'),
                      style: TextStyle(color: palette.fg, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Iconsax.arrow_right_3_copy, color: palette.fg),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(VerificationStatus s) {
    return switch (s) {
      VerificationStatus.none => Icons.info_outline,
      VerificationStatus.pending => Icons.schedule_outlined,
      VerificationStatus.inReview => Icons.search_outlined,
      VerificationStatus.approved => Icons.verified_outlined,
      VerificationStatus.rejected => Icons.error_outline,
    };
  }

  ({Color bg, Color fg}) _palette(SellerColors c, VerificationStatus status) {
    return switch (status) {
      VerificationStatus.none => (
          bg: c.neutralBg,
          fg: c.neutralFg,
        ),
      VerificationStatus.pending || VerificationStatus.inReview => (
          bg: c.warningBg,
          fg: c.warning,
        ),
      VerificationStatus.approved => (
          bg: c.positiveBg,
          fg: c.positive,
        ),
      VerificationStatus.rejected => (
          bg: c.negativeBg,
          fg: c.negative,
        ),
    };
  }
}

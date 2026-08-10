import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/premium_tokens.dart';

/// Premium "become a seller" call-to-action shown when the user has no seller
/// application on file.
class BecomeSellerBanner extends StatelessWidget {
  const BecomeSellerBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PremiumTokens.accent, PremiumTokens.accentDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumTokens.accentDeep.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Iconsax.shop,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('profile.become_seller_title'),
                        style: PremiumTokens.body(
                          size: 15.5,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr('profile.become_seller_subtitle'),
                        style: PremiumTokens.body(
                          size: 12.5,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Iconsax.arrow_right_3_copy,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                  tr('profile.seller_pending_title'),
                  style: PremiumTokens.body(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('profile.seller_pending_body'),
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
  const SellerApprovedBanner({
    super.key,
    required this.onOpenDashboard,
    this.unreadCount = 0,
  });

  final VoidCallback onOpenDashboard;

  /// Unread seller-panel notifications. When > 0 a count badge rides the
  /// "Sotuvchi paneliga o'tish" CTA, so an approved seller browsing in customer
  /// mode sees that the seller panel has unseen alerts (new order, product
  /// approved, …) — which are deliberately kept out of the customer bell.
  final int unreadCount;

  static const Color _accent = PremiumTokens.successStrong; // emerald
  static const Color _accentDeep = PremiumTokens.successStrongDeep;

  @override
  Widget build(BuildContext context) {
    // Compact one-row layout: a single "tasdiqlandi" message (no separate
    // eyebrow + heading), the whole card taps through to the seller panel, and
    // the trailing arrow doubles as the CTA — so the card no longer dominates
    // the profile screen the way the old tall block did.
    return Container(
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
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onOpenDashboard,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('profile.seller_approved_title'),
                        style: PremiumTokens.body(
                          size: 15.5,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr('profile.seller_open_panel'),
                        style: PremiumTokens.body(
                          size: 12.5,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Trailing arrow is the CTA; the unread badge floats on its
                // top-right corner (Stack with clipBehavior:none so it isn't
                // clipped by the card edge).
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Iconsax.arrow_right_3_copy,
                        size: 17,
                        color: _accentDeep,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: _SellerPanelBadge(count: unreadCount),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small red count chip for the "Sotuvchi paneliga o'tish" CTA. The white ring
/// lifts it off both the green banner and the white button beneath.
class _SellerPanelBadge extends StatelessWidget {
  const _SellerPanelBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFE05A4A), // alert red (matches inbox accents)
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: PremiumTokens.body(
          size: 9.5,
          weight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Shown when a seller application was rejected — surfaces the moderator's
/// reason, a resubmit CTA, and an X that hides the banner for users who no
/// longer plan to sell (the "become a seller" CTA takes its place, so
/// re-applying later stays one tap away).
class SellerRejectedBanner extends StatelessWidget {
  const SellerRejectedBanner({
    super.key,
    required this.reason,
    required this.onEdit,
    required this.onDismiss,
  });

  final String? reason;
  final VoidCallback onEdit;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final hasReason = reason != null && reason!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: errorColor.withValues(alpha: 0.22)),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(Iconsax.info_circle, size: 22, color: errorColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('profile.seller_rejected_title'),
                        style: PremiumTokens.display(
                          size: 17,
                          letterSpacing: -0.2,
                          color: pt.dark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr('profile.seller_rejected_subtitle'),
                        style: PremiumTokens.body(
                          size: 12.5,
                          color: pt.grey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // X — "I'm not planning to sell": hides the banner, the
              // become-a-seller CTA replaces it.
              Material(
                color: pt.imageBg,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onDismiss,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(Icons.close_rounded, size: 17, color: pt.grey),
                  ),
                ),
              ),
            ],
          ),
          if (hasReason) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: errorColor.withValues(alpha: 0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('profile.seller_rejected_reason_label'),
                    style: PremiumTokens.body(
                      size: 10,
                      weight: FontWeight.w700,
                      color: errorColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    reason!.trim(),
                    style: PremiumTokens.body(
                      size: 13,
                      color: pt.dark,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Iconsax.refresh, size: 17),
              label: Text(tr('profile.seller_resubmit')),
              style: FilledButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: Colors.white,
                textStyle: PremiumTokens.body(
                  size: 14,
                  weight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

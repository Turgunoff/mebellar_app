import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../models/chat.dart';
import '../../models/order_status.dart';

/// Above-the-thread status pill (Variant A: chat stays open, banner
/// reflects the order's lifecycle). Renders different colours and copy
/// per status; for delivered orders it surfaces a "Leave a review" CTA
/// on the *customer* side.
class ChatStatusBanner extends StatelessWidget {
  const ChatStatusBanner({
    super.key,
    required this.chat,
    required this.viewer,
    this.onLeaveReview,
  });

  final Chat chat;
  final ChatSenderRole viewer;

  /// Called when the customer taps "Leave a review" on a delivered
  /// order. Wire this to the existing review composer. The CTA is
  /// hidden when null (e.g. on the seller side).
  final VoidCallback? onLeaveReview;

  @override
  Widget build(BuildContext context) {
    final status = chat.orderStatus;
    if (status == null) return const SizedBox.shrink();
    final spec = _specFor(status, chat.orderCancellationReason);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: spec.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: spec.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(spec.icon, size: 16, color: spec.iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title,
                  style: PremiumTokens.body(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: spec.titleColor,
                  ),
                ),
                if (spec.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    spec.subtitle,
                    style: PremiumTokens.body(
                      size: 12,
                      weight: FontWeight.w500,
                      color: spec.subtitleColor,
                      height: 1.35,
                    ),
                  ),
                ],
                // Delivered + customer side → review CTA. We don't show
                // it for sellers (they don't write reviews of themselves)
                // or for non-delivered statuses.
                if (status == OrderStatus.delivered &&
                    viewer == ChatSenderRole.customer &&
                    onLeaveReview != null) ...[
                  const SizedBox(height: 8),
                  _CtaButton(
                    label: tr('chat.status.delivered_cta'),
                    color: spec.titleColor,
                    onTap: onLeaveReview!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _BannerSpec _specFor(OrderStatus status, String? cancelReason) {
    return switch (status) {
      OrderStatus.delivered => _BannerSpec(
          icon: Iconsax.tick_circle,
          title: tr('chat.status.delivered_title'),
          subtitle: tr('chat.status.delivered_subtitle'),
          background: const Color(0xFFEAF6EE),
          border: const Color(0xFFB7DEC4),
          iconBg: const Color(0xFFCFEAD8),
          iconColor: const Color(0xFF1F6B49),
          titleColor: const Color(0xFF1F6B49),
          subtitleColor: const Color(0xFF1F6B49),
        ),
      OrderStatus.cancelled => _BannerSpec(
          icon: Iconsax.close_circle,
          title: tr('chat.status.cancelled_title'),
          subtitle: tr(
            'chat.status.cancelled_subtitle',
            args: [
              (cancelReason?.trim().isNotEmpty ?? false)
                  ? cancelReason!.trim()
                  : tr('chat.status.cancelled_no_reason'),
            ],
          ),
          background: const Color(0xFFFBECEC),
          border: const Color(0xFFE3B4B4),
          iconBg: const Color(0xFFF1CCCC),
          iconColor: const Color(0xFF993D3D),
          titleColor: const Color(0xFF993D3D),
          subtitleColor: const Color(0xFF7A2E2E),
        ),
      OrderStatus.pending => _BannerSpec(
          icon: Iconsax.clock,
          title: tr('chat.status.pending_title'),
          subtitle: tr('chat.status.pending_subtitle'),
          background: const Color(0xFFFFF6E0),
          border: const Color(0xFFE8CE7E),
          iconBg: const Color(0xFFFCE3A6),
          iconColor: const Color(0xFF7C5D08),
          titleColor: const Color(0xFF7C5D08),
          subtitleColor: const Color(0xFF7C5D08),
        ),
      OrderStatus.confirmed => _BannerSpec(
          icon: Iconsax.tick_square,
          title: tr('chat.status.confirmed_title'),
          subtitle: tr('chat.status.confirmed_subtitle'),
          background: const Color(0xFFEEF3FF),
          border: const Color(0xFFB5C7EF),
          iconBg: const Color(0xFFD5E0FA),
          iconColor: const Color(0xFF274A95),
          titleColor: const Color(0xFF274A95),
          subtitleColor: const Color(0xFF274A95),
        ),
      OrderStatus.preparing => _BannerSpec(
          icon: Iconsax.box,
          title: tr('chat.status.preparing_title'),
          subtitle: tr('chat.status.preparing_subtitle'),
          background: const Color(0xFFEEF3FF),
          border: const Color(0xFFB5C7EF),
          iconBg: const Color(0xFFD5E0FA),
          iconColor: const Color(0xFF274A95),
          titleColor: const Color(0xFF274A95),
          subtitleColor: const Color(0xFF274A95),
        ),
      OrderStatus.shipped => _BannerSpec(
          icon: Iconsax.truck_fast,
          title: tr('chat.status.shipped_title'),
          subtitle: tr('chat.status.shipped_subtitle'),
          background: const Color(0xFFEEF3FF),
          border: const Color(0xFFB5C7EF),
          iconBg: const Color(0xFFD5E0FA),
          iconColor: const Color(0xFF274A95),
          titleColor: const Color(0xFF274A95),
          subtitleColor: const Color(0xFF274A95),
        ),
    };
  }
}

class _BannerSpec {
  const _BannerSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.border,
    required this.iconBg,
    required this.iconColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color border;
  final Color iconBg;
  final Color iconColor;
  final Color titleColor;
  final Color subtitleColor;
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.star_1, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: PremiumTokens.body(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

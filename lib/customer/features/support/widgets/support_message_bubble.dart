import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../models/support_message.dart';
import 'support_audio_player.dart';

/// One support bubble — text, image, or audio — aligned to the customer's side
/// (right) when [message.isMine], the admin's side (left) otherwise. Read
/// receipts (✓✓) show only on the customer's outgoing messages.
class SupportMessageBubble extends StatelessWidget {
  const SupportMessageBubble({
    super.key,
    required this.message,
    this.showTime = true,
  });

  final SupportMessage message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final mine = message.isMine;

    final bg = mine ? Theme.of(context).colorScheme.primary : pt.surface;
    final fg = mine ? Colors.white : pt.dark;
    final timeColor = mine ? Colors.white.withValues(alpha: 0.75) : pt.grey;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: radius,
                  boxShadow: mine ? null : PremiumTokens.softShadow,
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.hasImage)
                        _ImageContent(url: message.fileUrl!),
                      if (message.hasAudio)
                        SupportAudioPlayer(url: message.fileUrl!, mine: mine),
                      if (message.hasText)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            message.hasImage || message.hasAudio ? 8 : 10,
                            14,
                            showTime ? 6 : 10,
                          ),
                          child: Text(
                            message.textContent!,
                            style: PremiumTokens.body(
                              size: 14,
                              color: fg,
                              height: 1.35,
                            ),
                          ),
                        ),
                      if (showTime)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            message.hasText ? 0 : 6,
                            10,
                            8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(message.createdAt),
                                style: PremiumTokens.body(
                                  size: 11,
                                  weight: FontWeight.w500,
                                  color: timeColor,
                                ),
                              ),
                              if (mine) ...[
                                const SizedBox(width: 4),
                                _StatusGlyph(
                                  message: message,
                                  baseColor: timeColor,
                                ),
                              ],
                            ],
                          ),
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

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Outgoing-message status glyph: clock while sending, a warning while failed,
/// then the single/double tick once the server has it (double = read).
class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.message, required this.baseColor});

  final SupportMessage message;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (message.status) {
      SupportMessageStatus.sending => (Iconsax.clock, baseColor),
      SupportMessageStatus.failed => (
        Iconsax.info_circle,
        const Color(0xFFFFC9BC), // soft red — legible on the accent bubble
      ),
      SupportMessageStatus.sent => (
        message.isRead ? Icons.done_all : Icons.check,
        baseColor,
      ),
    };
    return Icon(icon, size: 13, color: color);
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260, minWidth: 180),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: 800,
          placeholder: (_, _) => Container(color: pt.imageBg),
          errorWidget: (_, _, _) => Container(
            color: pt.imageBg,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.gallery_slash, color: pt.grey),
                const SizedBox(height: 4),
                Text(
                  tr('support.image_message'),
                  style: PremiumTokens.body(size: 11, color: pt.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Date separator shown between days in the message list (e.g. "Bugun").
class SupportDateSeparator extends StatelessWidget {
  const SupportDateSeparator({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: pt.imageBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _label(date),
            style: PremiumTokens.body(
              size: 11,
              weight: FontWeight.w600,
              color: pt.grey,
            ),
          ),
        ),
      ),
    );
  }

  static String _label(DateTime date) {
    final local = date.toLocal();
    final today = DateTime.now();
    final isToday = local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    if (isToday) return tr('support.today');
    final yesterday = today.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return tr('support.yesterday');
    }
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}

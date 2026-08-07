import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/premium_tokens.dart';
import '../../models/chat.dart';
import '../../models/chat_message.dart';

/// One chat bubble — text, image, or both — aligned to the side of the
/// conversation matching the [viewer]. Read receipts (✓✓) show only on
/// outgoing messages because a receiver doesn't need to know they read
/// their own.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.viewer,
    this.showTime = true,
  });

  final ChatMessage message;
  final ChatSenderRole viewer;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final mine = message.isMine(viewer);

    // The outgoing-bubble fill is the active theme's primary, so the shared
    // chat adopts terracotta in customer mode and Deep Indigo in seller mode
    // instead of a hardcoded customer accent.
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
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
                        _ImageContent(url: message.attachmentUrl!),
                      if (message.hasText)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            message.hasImage ? 8 : 10,
                            14,
                            showTime ? 6 : 10,
                          ),
                          child: Text(
                            message.body!,
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
    // Timestamps arrive in UTC (Postgres timestamptz) — render in the device
    // zone (UTC+5 in UZ) so the stamp matches the user's wall clock.
    // Locale-independent HH:mm — chat time stamps live next to the
    // message, the date headers handle the relative-day context.
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Outgoing-message status glyph: clock while sending, a warning while
/// failed, then the single/double tick once the server has it (double =
/// read). Sized to sit inline with the timestamp.
class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.message, required this.baseColor});

  final ChatMessage message;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (message.status) {
      ChatMessageStatus.sending => (Iconsax.clock, baseColor),
      ChatMessageStatus.failed => (
        Iconsax.info_circle,
        const Color(0xFFFFC9BC), // soft red — legible on the accent bubble
      ),
      // Telegram standard: a single check once the server has the message
      // (read_at still null), a double check once the recipient has read it.
      ChatMessageStatus.sent => (
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
                  tr('chat.image_message'),
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
class MessageDateSeparator extends StatelessWidget {
  const MessageDateSeparator({super.key, required this.date});

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
    // Compare against the device's local calendar — `date` is UTC, so a
    // message just after local midnight must still read "Bugun".
    final local = date.toLocal();
    final today = DateTime.now();
    final isToday =
        local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    if (isToday) return tr('chat.today');
    final yesterday = today.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return tr('chat.yesterday');
    }
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}

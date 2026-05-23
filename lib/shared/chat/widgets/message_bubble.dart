import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../../customer/features/home/widgets/premium/premium_tokens.dart';
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

    final bg = mine ? PremiumTokens.accent : pt.surface;
    final fg = mine ? Colors.white : pt.dark;
    final timeColor = mine
        ? Colors.white.withValues(alpha: 0.75)
        : pt.grey;

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
                                Icon(
                                  message.isRead
                                      ? Iconsax.tick_circle
                                      : Iconsax.tick_square,
                                  size: 12,
                                  color: timeColor,
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
    // Locale-independent HH:mm — chat time stamps live next to the
    // message, the date headers handle the relative-day context.
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 260,
        minWidth: 180,
      ),
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
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    if (isToday) return tr('chat.today');
    final yesterday = today.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return tr('chat.yesterday');
    }
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

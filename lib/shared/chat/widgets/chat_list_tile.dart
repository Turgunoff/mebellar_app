import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../models/chat.dart';
import 'chat_avatar.dart';

/// One row in the chats list — avatar, name, last-message preview,
/// timestamp and unread badge. Tapping opens the thread.
class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    required this.viewer,
    required this.onTap,
  });

  final Chat chat;
  final ChatSenderRole viewer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final unread = chat.unreadFor(viewer);
    final name = chat.displayNameFor(viewer);
    final preview = chat.lastMessagePreview ?? '';
    // Read receipt rides next to the timestamp, but only for an outgoing
    // last message — Telegram never shows a tick on a message you received.
    final showReceipt = chat.lastMessageAt != null && chat.lastMessageIsMine(viewer);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ChatAvatar(
                name: name,
                imageUrl: chat.avatarFor(viewer),
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PremiumTokens.body(
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: pt.dark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (showReceipt) ...[
                          _ReadReceipt(read: chat.lastMessageRead),
                          const SizedBox(width: 4),
                        ],
                        if (chat.lastMessageAt != null)
                          Text(
                            _formatTime(chat.lastMessageAt!),
                            style: PremiumTokens.body(
                              size: 11,
                              weight: FontWeight.w500,
                              color: unread > 0
                                  ? Theme.of(context).colorScheme.primary
                                  : pt.grey,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview.isEmpty
                                ? '${tr('chat.order_label')} #${_shortId(chat.orderId)}'
                                : preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PremiumTokens.body(
                              size: 13,
                              weight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color:
                                  unread > 0 ? pt.dark : pt.grey,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          _UnreadBadge(count: unread),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortId(String id) =>
      id.length <= 8 ? id : id.substring(0, 8).toUpperCase();

  static String _formatTime(DateTime dt) {
    // `last_message_at` is UTC (timestamptz) — render in the device zone so
    // the list time matches the thread and the user's wall clock.
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return tr('chat.yesterday');
    }
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
  }
}

/// Telegram-style delivery tick for the viewer's own last message: a single
/// check once it's stored (delivered) and a filled double-check once the
/// other party has read it. The read state uses the active theme's primary —
/// terracotta in customer mode, Deep Indigo in seller mode — rather than a
/// hardcoded customer accent, per the theming rules.
class _ReadReceipt extends StatelessWidget {
  const _ReadReceipt({required this.read});
  final bool read;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Icon(
      read ? Icons.done_all : Icons.check,
      size: 15,
      color: read ? Theme.of(context).colorScheme.primary : pt.grey,
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      constraints: const BoxConstraints(minWidth: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Follows the active theme so the unread pill turns Deep Indigo in
        // seller mode instead of the customer terracotta.
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: PremiumTokens.body(
          size: 11,
          weight: FontWeight.w800,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

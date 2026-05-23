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
                        if (chat.lastMessageAt != null)
                          Text(
                            _formatTime(chat.lastMessageAt!),
                            style: PremiumTokens.body(
                              size: 11,
                              weight: FontWeight.w500,
                              color: unread > 0
                                  ? PremiumTokens.accent
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
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return tr('chat.yesterday');
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
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
      decoration: const BoxDecoration(
        color: PremiumTokens.accent,
        borderRadius: BorderRadius.all(Radius.circular(12)),
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

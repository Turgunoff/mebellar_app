import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../shared/chat/widgets/unread_count_badge.dart';
import '../../../../core/theme/premium_tokens.dart';

/// One row in the [MenuListCard].
class MenuEntry {
  const MenuEntry({
    required this.icon,
    required this.label,
    this.onTap,
    this.onLongPress,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Optional unread count shown as a red pill before the chevron (e.g. the
  /// "Suhbatlar" row). Hidden when zero.
  final int badgeCount;
}

/// Card grouping the settings / help / about navigation rows.
class MenuListCard extends StatelessWidget {
  const MenuListCard({super.key, required this.items});

  final List<MenuEntry> items;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _MenuRow(entry: items[i]),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Divider(height: 1, color: pt.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry});

  final MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: entry.onTap,
        onLongPress: entry.onLongPress,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: pt.imageBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(entry.icon, size: 18, color: pt.dark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  entry.label,
                  style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
                ),
              ),
              if (entry.badgeCount > 0) ...[
                UnreadCountBadge(count: entry.badgeCount),
                const SizedBox(width: 8),
              ],
              Icon(Iconsax.arrow_right_3_copy, size: 20, color: pt.greyLight),
            ],
          ),
        ),
      ),
    );
  }
}

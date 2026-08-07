import 'package:flutter/material.dart';

import '../../core/theme/premium_tokens.dart';

/// One slot in [GlassBottomNav]. The [iconBuilder] receives the active state so
/// callers can swap outlined/filled glyphs, recolor, or wrap in a badge
/// (e.g. cart count from a Bloc, unread chats from a stream). [label] is always
/// rendered under the icon.
class GlassNavItem {
  const GlassNavItem({required this.iconBuilder, required this.label});

  final Widget Function(BuildContext context, bool isActive) iconBuilder;
  final String label;
}

/// Flush, edge-to-edge bottom navigation bar in the Ozon/Uzum idiom: a solid
/// surface that sits against the bottom edge (no floating margin), a hairline
/// top divider, and always-visible text labels. The active item is terracotta
/// ([PremiumTokens.accent]) for both icon and label; inactive items are grey.
///
/// Drop into `Scaffold.bottomNavigationBar` with **`extendBody: false`** (the
/// default) so the body lays out directly above the bar — the bar reserves its
/// own footprint, so scrollable bodies need no extra bottom padding for it.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Content height, excluding the device bottom safe-area inset (added by the
  /// internal [SafeArea]).
  static const double height = 60;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pt.surface,
        border: Border(top: BorderSide(color: pt.divider, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: List.generate(items.length, (i) {
              return Expanded(
                child: _NavSlot(
                  item: items[i],
                  isActive: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Semantics(
      label: item.label,
      button: true,
      selected: isActive,
      child: InkResponse(
        onTap: onTap,
        radius: 56,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            item.iconBuilder(context, isActive),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: PremiumTokens.body(
                size: 11,
                weight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? PremiumTokens.accent : pt.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

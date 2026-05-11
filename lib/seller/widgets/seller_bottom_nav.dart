import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Flat, business-tool style bottom navigation for the seller shell.
///
/// Why a custom widget instead of `NavigationBar` / `BottomNavigationBar`:
/// - The customer side uses a floating glass nav. Sellers spend hours in
///   data-heavy screens; an opaque, ground-anchored bar reads as "tool"
///   rather than "consumer app" and avoids covering analytics tables.
/// - Material 3's `NavigationBar` ships with a pill indicator behind the
///   active icon. We want the active state to be communicated by color +
///   weight only, matching the rest of the seller premium aesthetic.
/// - We hardcode [AppColors.terracotta] for the active color so the nav
///   stays on-brand even if the seller theme seed is changed independently.
///
/// Typography note: the label `TextStyle` deliberately omits `fontFamily`
/// — the seller theme pins everything to Plus Jakarta Sans, and we want the
/// nav to follow along without a hardcoded family override.
class SellerBottomNav extends StatelessWidget {
  const SellerBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<SellerNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.lightDivider),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavTile(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single destination descriptor — one outline icon for inactive, an
/// optional filled icon for the selected state, and the i18n-resolved label.
@immutable
class SellerNavItem {
  const SellerNavItem({
    required this.icon,
    required this.label,
    IconData? activeIcon,
  }) : activeIcon = activeIcon ?? icon;

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SellerNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.terracotta : AppColors.lightTextSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.0,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

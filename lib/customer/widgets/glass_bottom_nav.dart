import 'dart:ui';

import 'package:flutter/material.dart';

import '../features/home/widgets/premium/premium_tokens.dart';

/// One slot in [GlassBottomNav]. The [iconBuilder] receives the active state so
/// callers can swap outlined/filled glyphs, recolor, or wrap in a badge
/// (e.g. cart count from a Bloc, unread notifications from a stream).
class GlassNavItem {
  const GlassNavItem({required this.iconBuilder, required this.label});

  final Widget Function(BuildContext context, bool isActive) iconBuilder;
  final String label;
}

/// Floating, frosted-glass bottom navigation bar. Drop into
/// `Scaffold.bottomNavigationBar` and set `extendBody: true` on the Scaffold so
/// the body content scrolls behind it.
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

  static const double height = 68;
  static const double horizontalMargin = 16;
  static const double bottomMargin = 24;

  /// Total vertical space the bar occupies, including its bottom margin and
  /// the device's bottom safe-area inset. Use this to pad scrollable bodies so
  /// their last item is not hidden behind the bar.
  static double reservedHeight(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return height + bottomMargin + inset;
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin,
        0,
        horizontalMargin,
        inset > 0 ? inset + 8 : bottomMargin,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 32,
              offset: const Offset(0, 14),
              spreadRadius: -8,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xB31E1E1E) : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
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
    return Semantics(
      label: item.label,
      button: true,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            item.iconBuilder(context, isActive),
            const SizedBox(height: 6),
            SizedBox(
              height: 5,
              width: 5,
              child: AnimatedScale(
                scale: isActive ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: PremiumTokens.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

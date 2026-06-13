import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../features/home/widgets/premium/premium_tokens.dart';

/// Feed layout the user picks via the header toggle. Shared by the home feed and
/// the per-category product list so both surfaces switch between a grid and a
/// full-width list with one widget. Ephemeral UI state — callers hold it in a
/// [ValueNotifier]; it resets on cold restart, which is fine for a presentation
/// preference.
enum ProductViewMode { grid, list }

/// Two-segment grid/list switch. The active segment lifts onto a surface chip;
/// tapping the inactive one fires [onChanged].
class ViewModeToggle extends StatelessWidget {
  const ViewModeToggle({
    super.key,
    required this.viewMode,
    required this.onChanged,
  });

  final ProductViewMode viewMode;
  final ValueChanged<ProductViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: pt.imageBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            pt,
            ProductViewMode.grid,
            Icons.grid_view_rounded,
            tr('home.view_grid'),
          ),
          _segment(
            pt,
            ProductViewMode.list,
            Icons.view_agenda_rounded,
            tr('home.view_list'),
          ),
        ],
      ),
    );
  }

  Widget _segment(
    PremiumTokens pt,
    ProductViewMode mode,
    IconData icon,
    String tooltip,
  ) {
    final selected = viewMode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(mode),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 32,
          decoration: BoxDecoration(
            color: selected ? pt.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected ? PremiumTokens.softShadow : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? PremiumTokens.accent : pt.grey,
          ),
        ),
      ),
    );
  }
}

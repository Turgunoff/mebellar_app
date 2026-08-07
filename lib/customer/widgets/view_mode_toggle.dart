import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../../core/storage/app_settings.dart';
import '../../core/theme/premium_tokens.dart';

/// Feed layout the user picks via the header toggle. Shared by the home feed and
/// the per-category product list so both surfaces switch between a grid and a
/// full-width list with one widget. The live choice lives in the single
/// app-wide [ProductViewModeController] (backed by [AppSettings]), so a toggle
/// on any surface applies everywhere immediately — including a tab kept alive in
/// the shell — and survives navigation + cold restart.
enum ProductViewMode { grid, list }

/// Single source of truth for the grid/list preference across the home feed and
/// every category list. Registered as a DI singleton and seeded from
/// [AppSettings] (defaulting to [ProductViewMode.grid] when never toggled);
/// every screen listens to the *same* instance, so toggling on a pushed
/// category screen updates the already-mounted home tab the moment the user
/// pops back — no per-screen copy to drift out of sync.
class ProductViewModeController extends ValueNotifier<ProductViewMode> {
  ProductViewModeController(this._settings) : super(_seed(_settings));

  final AppSettings _settings;

  static ProductViewMode _seed(AppSettings settings) {
    final name = settings.productViewModeName;
    return ProductViewMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ProductViewMode.grid,
    );
  }

  /// Switch the active mode and persist it. A no-op (no notify, no write) when
  /// the mode is unchanged, so re-tapping the active segment is free.
  void set(ProductViewMode mode) {
    if (mode == value) return;
    value = mode;
    _settings.setProductViewModeName(mode.name);
  }
}

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

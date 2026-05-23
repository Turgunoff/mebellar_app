import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/constants/product_colors.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/repositories/supabase_category_repository.dart';
import '../../../../shared/repositories/supabase_product_data_source.dart';
import '../../home/widgets/premium/premium_tokens.dart';

/// Shows the search filter sheet. Resolves to the new [ProductSearchFilter]
/// when the user taps "Apply", `null` when they dismiss or back-out — the
/// caller treats `null` as "no change", which lets dismissing the sheet
/// behave like a cancel rather than a destructive reset.
///
/// Pass [showCategories] = `false` when the screen is already pinned to a
/// single category (e.g. the in-category product list) — the multi-category
/// picker is redundant there and would let the user pick conflicting
/// categories. Search keeps it on so the same sheet works for global search.
///
/// [availability] tells the sheet which facets to surface (and which to
/// hide as a dead-end). Always falls back to the full palette when `null`
/// (e.g. when the caller hasn't loaded results yet).
Future<ProductSearchFilter?> showSearchFilterSheet(
  BuildContext context, {
  required ProductSearchFilter initial,
  required int currentResultCount,
  bool showCategories = true,
  FilterAvailability? availability,
}) {
  return showModalBottomSheet<ProductSearchFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    useSafeArea: true,
    builder: (_) => _SearchFilterSheet(
      initial: initial,
      currentResultCount: currentResultCount,
      showCategories: showCategories,
      availability: availability ?? const FilterAvailability.unrestricted(),
    ),
  );
}

/// Snapshot of which filter facets are actually present in the data the
/// caller is showing right now. Drives "hide dead-end options" UX so the
/// customer never picks a facet that would return zero products.
///
/// A currently-active facet should still be rendered (the user must be
/// able to undo their own choice), so call sites typically `_or` this
/// against the existing filter before passing it in.
class FilterAvailability {
  const FilterAvailability({
    required this.colorSlugs,
    required this.hasDiscounted,
    required this.hasDelivery,
  });

  /// "Show everything" — used as the safe default when the caller hasn't
  /// loaded results yet, so the sheet behaves like the unfiltered palette.
  const FilterAvailability.unrestricted()
      : colorSlugs = const _UnrestrictedColorSet(),
        hasDiscounted = true,
        hasDelivery = true;

  final Set<String> colorSlugs;
  final bool hasDiscounted;
  final bool hasDelivery;
}

/// Sentinel "matches every slug" set — lets [FilterAvailability.unrestricted]
/// be a const constructor without baking the full palette into the file.
class _UnrestrictedColorSet implements Set<String> {
  const _UnrestrictedColorSet();
  @override
  bool contains(Object? element) => true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({
    required this.initial,
    required this.currentResultCount,
    required this.showCategories,
    required this.availability,
  });

  final ProductSearchFilter initial;
  final int currentResultCount;
  final bool showCategories;
  final FilterAvailability availability;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late ProductSearchFilter _draft;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  Future<List<CategoryModel>>? _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _minCtrl = TextEditingController(
      text: widget.initial.minPrice?.toString() ?? '',
    );
    _maxCtrl = TextEditingController(
      text: widget.initial.maxPrice?.toString() ?? '',
    );
    // Only fetch categories when the section will actually render — saves a
    // round-trip on the in-category product list where the picker is hidden.
    if (widget.showCategories) {
      _categoriesFuture = sl<CategoryDataSource>().list();
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _patch(ProductSearchFilter Function(ProductSearchFilter) f) {
    setState(() => _draft = f(_draft));
  }

  /// Palette entries to render: keep only those that exist in the current
  /// scope (per [FilterAvailability.colorSlugs]) and any the user has
  /// already ticked — so a selection made before the scope narrowed can
  /// always be unticked even if no products carry it now.
  List<ProductColorOption> get _visibleColors {
    final available = widget.availability.colorSlugs;
    return kProductColors
        .where((c) => available.contains(c.slug) || _draft.colors.contains(c.slug))
        .toList(growable: false);
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _draft = const ProductSearchFilter();
      _minCtrl.clear();
      _maxCtrl.clear();
    });
  }

  void _apply() {
    final min = int.tryParse(_minCtrl.text.trim().replaceAll(' ', ''));
    final max = int.tryParse(_maxCtrl.text.trim().replaceAll(' ', ''));
    final next = _draft.copyWith(
      minPrice: min,
      maxPrice: max,
      clearMinPrice: min == null,
      clearMaxPrice: max == null,
    );
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: pt.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              _Handle(color: pt.greyLight),
              _Header(
                onReset: _draft.isNotEmpty ? _reset : null,
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    mq.padding.bottom + 96,
                  ),
                  children: [
                    _SortSection(
                      value: _draft.sort,
                      onChanged: (v) => _patch((f) => f.copyWith(sort: v)),
                    ),
                    const SizedBox(height: 20),
                    _PriceSection(
                      minCtrl: _minCtrl,
                      maxCtrl: _maxCtrl,
                    ),
                    if (widget.showCategories &&
                        _categoriesFuture != null) ...[
                      const SizedBox(height: 20),
                      _CategoriesSection(
                        future: _categoriesFuture!,
                        selected: _draft.categoryIds,
                        onChanged: (ids) =>
                            _patch((f) => f.copyWith(categoryIds: ids)),
                      ),
                    ],
                    if (_visibleColors.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _ColorsSection(
                        options: _visibleColors,
                        selected: _draft.colors,
                        onChanged: (colors) =>
                            _patch((f) => f.copyWith(colors: colors)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _OptionsSection(
                      inStockOnly: _draft.inStockOnly,
                      discountedOnly: _draft.discountedOnly,
                      deliveryOnly: _draft.deliveryOnly,
                      showDiscounted: widget.availability.hasDiscounted ||
                          _draft.discountedOnly,
                      showDelivery: widget.availability.hasDelivery ||
                          _draft.deliveryOnly,
                      onInStockChanged: (v) =>
                          _patch((f) => f.copyWith(inStockOnly: v)),
                      onDiscountedChanged: (v) =>
                          _patch((f) => f.copyWith(discountedOnly: v)),
                      onDeliveryChanged: (v) =>
                          _patch((f) => f.copyWith(deliveryOnly: v)),
                    ),
                  ],
                ),
              ),
              _ApplyBar(
                resultCount: widget.currentResultCount,
                activeCount: _draft.activeCount,
                onApply: _apply,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Handle ────────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  const _Handle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({this.onReset});
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr('search.filter.title'),
              style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: onReset == null
                ? const SizedBox(key: ValueKey('off'))
                : TextButton.icon(
                    key: const ValueKey('on'),
                    onPressed: onReset,
                    icon: const Icon(Iconsax.refresh, size: 16),
                    label: Text(tr('search.filter.reset_all')),
                    style: TextButton.styleFrom(
                      foregroundColor: PremiumTokens.accent,
                      textStyle: PremiumTokens.body(
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          IconButton(
            icon: Icon(Iconsax.close_circle, color: pt.grey, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ── Sort ──────────────────────────────────────────────────────────────────

class _SortSection extends StatelessWidget {
  const _SortSection({required this.value, required this.onChanged});

  final ProductSearchSort value;
  final ValueChanged<ProductSearchSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Iconsax.sort,
      title: tr('search.filter.sort'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in ProductSearchSort.values)
            _Chip(
              label: _label(s),
              selected: value == s,
              onTap: () => onChanged(s),
            ),
        ],
      ),
    );
  }

  String _label(ProductSearchSort s) => switch (s) {
        ProductSearchSort.newest => tr('search.filter.sort_newest'),
        ProductSearchSort.priceAsc => tr('search.filter.sort_price_asc'),
        ProductSearchSort.priceDesc => tr('search.filter.sort_price_desc'),
      };
}

// ── Price ─────────────────────────────────────────────────────────────────

class _PriceSection extends StatelessWidget {
  const _PriceSection({required this.minCtrl, required this.maxCtrl});

  final TextEditingController minCtrl;
  final TextEditingController maxCtrl;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Iconsax.money_4,
      title: tr('search.filter.price'),
      child: Row(
        children: [
          Expanded(
            child: _PriceField(
              controller: minCtrl,
              hint: tr('search.filter.price_from'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PriceField(
              controller: maxCtrl,
              hint: tr('search.filter.price_to'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        cursorColor: PremiumTokens.accent,
        style: PremiumTokens.body(
          size: 15,
          weight: FontWeight.w600,
          color: pt.dark,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: PremiumTokens.body(size: 14, color: pt.grey),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          suffixText: 'UZS',
          suffixStyle: PremiumTokens.body(
            size: 12,
            weight: FontWeight.w500,
            color: pt.grey,
          ),
        ),
      ),
    );
  }
}

// ── Categories ────────────────────────────────────────────────────────────

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({
    required this.future,
    required this.selected,
    required this.onChanged,
  });

  final Future<List<CategoryModel>> future;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Iconsax.category,
      title: tr('search.filter.categories'),
      child: FutureBuilder<List<CategoryModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _CategoriesSkeleton();
          }
          final cats = snap.data ?? const [];
          if (cats.isEmpty) return const SizedBox.shrink();
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                _Chip(
                  label: c.name,
                  selected: selected.contains(c.id),
                  onTap: () {
                    final next = Set<String>.from(selected);
                    if (!next.add(c.id)) next.remove(c.id);
                    onChanged(next);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        5,
        (i) => Container(
          width: 80 + (i % 3) * 24.0,
          height: 36,
          decoration: BoxDecoration(
            color: pt.imageBg,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Colors ────────────────────────────────────────────────────────────────

class _ColorsSection extends StatelessWidget {
  const _ColorsSection({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<ProductColorOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Iconsax.color_swatch,
      title: tr('search.filter.colors'),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final c in options)
            _ColorSwatch(
              option: c,
              selected: selected.contains(c.slug),
              onTap: () {
                final next = Set<String>.from(selected);
                if (!next.add(c.slug)) next.remove(c.slug);
                onChanged(next);
              },
            ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ProductColorOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    // White swatch needs a soft outline to remain visible on white surfaces.
    final isLight = option.swatch.computeLuminance() > 0.85;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: option.swatch,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? PremiumTokens.accent
                    : (isLight ? pt.divider : Colors.transparent),
                width: selected ? 2.5 : 1.2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: PremiumTokens.accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : PremiumTokens.softShadow,
            ),
            child: selected
                ? Icon(
                    Iconsax.tick_circle,
                    size: 18,
                    color: isLight ? pt.dark : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 56,
            child: Text(
              option.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PremiumTokens.body(
                size: 11,
                weight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? pt.dark : pt.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Options ───────────────────────────────────────────────────────────────

class _OptionsSection extends StatelessWidget {
  const _OptionsSection({
    required this.inStockOnly,
    required this.discountedOnly,
    required this.deliveryOnly,
    required this.showDiscounted,
    required this.showDelivery,
    required this.onInStockChanged,
    required this.onDiscountedChanged,
    required this.onDeliveryChanged,
  });

  final bool inStockOnly;
  final bool discountedOnly;
  final bool deliveryOnly;

  /// `in_stock` is universal — every product has a stock count — so its
  /// row is always rendered. The other two depend on optional product
  /// fields and are hidden when no product in scope offers them, unless
  /// the user has already enabled the toggle (the callers OR-in the
  /// active-filter case before passing).
  final bool showDiscounted;
  final bool showDelivery;

  final ValueChanged<bool> onInStockChanged;
  final ValueChanged<bool> onDiscountedChanged;
  final ValueChanged<bool> onDeliveryChanged;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _OptionRow(
        icon: Iconsax.box_tick,
        label: tr('search.filter.in_stock'),
        value: inStockOnly,
        onChanged: onInStockChanged,
      ),
      if (showDiscounted)
        _OptionRow(
          icon: Iconsax.discount_shape,
          label: tr('search.filter.discounted'),
          value: discountedOnly,
          onChanged: onDiscountedChanged,
        ),
      if (showDelivery)
        _OptionRow(
          icon: Iconsax.truck_fast,
          label: tr('search.filter.delivery'),
          value: deliveryOnly,
          onChanged: onDeliveryChanged,
        ),
    ];
    // The last visible row shouldn't draw a trailing divider — strip the
    // bottom border by rebuilding it without `divider: true`. Keeps the
    // section's bottom edge clean regardless of which rows got hidden.
    final lastRow = rows.removeLast() as _OptionRow;
    rows.add(_OptionRow(
      icon: lastRow.icon,
      label: lastRow.label,
      value: lastRow.value,
      onChanged: lastRow.onChanged,
      divider: false,
    ));
    return _Section(
      icon: Iconsax.setting_4,
      title: tr('search.filter.options'),
      child: Column(children: rows),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.divider = true,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: pt.divider, width: 0.6))
            : null,
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value
                    ? PremiumTokens.accent.withValues(alpha: 0.12)
                    : pt.imageBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: value ? PremiumTokens.accent : pt.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: PremiumTokens.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: pt.dark,
                ),
              ),
            ),
          ],
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: PremiumTokens.accent,
      ),
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? PremiumTokens.accent.withValues(alpha: 0.10)
                : pt.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? PremiumTokens.accent
                  : pt.divider,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Iconsax.tick_circle,
                  size: 14,
                  color: PremiumTokens.accent,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: PremiumTokens.body(
                  size: 13,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? PremiumTokens.accent : pt.dark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: pt.grey),
              const SizedBox(width: 7),
            ],
            Text(
              title,
              style: PremiumTokens.body(
                size: 13,
                weight: FontWeight.w700,
                color: pt.dark,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ── Apply bar ─────────────────────────────────────────────────────────────

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({
    required this.resultCount,
    required this.activeCount,
    required this.onApply,
  });

  final int resultCount;
  final int activeCount;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: pt.surface,
        border: Border(top: BorderSide(color: pt.divider, width: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTokens.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: PremiumTokens.body(
                    size: 15,
                    weight: FontWeight.w700,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tr('search.filter.apply')),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$activeCount',
                          style: PremiumTokens.body(
                            size: 12,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/constants/product_colors.dart';
import '../../../shared/repositories/supabase_product_data_source.dart';
import '../../features/home/widgets/premium/premium_tokens.dart';

/// Horizontal strip of removable chips showing every active facet of
/// [filter]. Rendered above the results grid on both Search and the
/// in-category Product List so the user can see at a glance what's
/// narrowing the view and undo any single facet with one tap.
///
/// Tapping a chip strips that facet from the filter and invokes
/// [onChanged] with the result. The trailing circular button clears all
/// facets at once (but preserves the current sort — sort isn't shown as
/// a chip).
class ActiveFiltersBar extends StatelessWidget {
  const ActiveFiltersBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final ProductSearchFilter filter;
  final ValueChanged<ProductSearchFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final chips = <_ChipData>[];

    if (filter.minPrice != null || filter.maxPrice != null) {
      chips.add(
        _ChipData(
          icon: Iconsax.money_4,
          label: _formatPriceRange(filter.minPrice, filter.maxPrice),
          onRemove: () => onChanged(
            filter.copyWith(clearMinPrice: true, clearMaxPrice: true),
          ),
        ),
      );
    }
    for (final colorSlug in filter.colors) {
      final option = productColorBySlug(colorSlug);
      if (option == null) continue;
      chips.add(
        _ChipData(
          swatch: option.swatch,
          label: option.label,
          onRemove: () => onChanged(
            filter.copyWith(
              colors: Set<String>.from(filter.colors)..remove(colorSlug),
            ),
          ),
        ),
      );
    }
    if (filter.categoryIds.isNotEmpty) {
      chips.add(
        _ChipData(
          icon: Iconsax.category,
          label: tr('search.filter.categories'),
          counter: filter.categoryIds.length,
          onRemove: () => onChanged(filter.copyWith(categoryIds: const {})),
        ),
      );
    }
    if (filter.inStockOnly) {
      chips.add(
        _ChipData(
          icon: Iconsax.box_tick,
          label: tr('search.filter.in_stock'),
          onRemove: () => onChanged(filter.copyWith(inStockOnly: false)),
        ),
      );
    }
    if (filter.discountedOnly) {
      chips.add(
        _ChipData(
          icon: Iconsax.discount_shape,
          label: tr('search.filter.discounted'),
          onRemove: () => onChanged(filter.copyWith(discountedOnly: false)),
        ),
      );
    }
    if (filter.deliveryOnly) {
      chips.add(
        _ChipData(
          icon: Iconsax.truck_fast,
          label: tr('search.filter.delivery'),
          onRemove: () => onChanged(filter.copyWith(deliveryOnly: false)),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: chips.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          if (i == chips.length) {
            return _ClearAllButton(
              onTap: () => onChanged(
                ProductSearchFilter(sort: filter.sort),
              ),
            );
          }
          return _ActiveFilterChip(data: chips[i], foreground: pt.dark);
        },
      ),
    );
  }

  static String _formatPriceRange(int? min, int? max) {
    String fmt(int v) => NumberFormat('#,##0', 'en_US').format(v);
    if (min != null && max != null) return '${fmt(min)} – ${fmt(max)} UZS';
    if (min != null) return '≥ ${fmt(min)} UZS';
    if (max != null) return '≤ ${fmt(max)} UZS';
    return '';
  }
}

class _ChipData {
  _ChipData({
    required this.label,
    required this.onRemove,
    this.icon,
    this.swatch,
    this.counter,
  });

  final IconData? icon;
  final Color? swatch;
  final String label;
  final int? counter;
  final VoidCallback onRemove;
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.data, required this.foreground});

  final _ChipData data;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final label = data.counter != null
        ? '${data.label} · ${data.counter}'
        : data.label;
    return Material(
      color: PremiumTokens.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: data.onRemove,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.swatch != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: data.swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: pt.divider, width: 0.6),
                  ),
                ),
                const SizedBox(width: 7),
              ] else if (data.icon != null) ...[
                Icon(data.icon, size: 13, color: PremiumTokens.accent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: PremiumTokens.body(
                  size: 11.5,
                  weight: FontWeight.w700,
                  color: foreground,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 11,
                  color: PremiumTokens.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearAllButton extends StatelessWidget {
  const _ClearAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('search.filter.reset_all'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: PremiumTokens.accent.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: PremiumTokens.accent,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../shared/repositories/product_repository.dart';

Future<ProductFilter?> showCatalogFilterSheet(
  BuildContext context,
  ProductFilter current,
) {
  return showModalBottomSheet<ProductFilter>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final ProductFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late ProductSort _sort;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(
      text: widget.initial.minPrice?.toString() ?? '',
    );
    _maxCtrl = TextEditingController(
      text: widget.initial.maxPrice?.toString() ?? '',
    );
    _sort = widget.initial.sort;
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            tr('catalog.filter'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(tr('catalog.price_range')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('catalog.from'),
                    suffixText: 'so\'m',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('catalog.to'),
                    suffixText: 'so\'m',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(tr('catalog.sort')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ProductSort.values.map((s) {
              return ChoiceChip(
                label: Text(_sortLabel(s)),
                selected: _sort == s,
                onSelected: (_) => setState(() => _sort = s),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      ProductFilter(
                        categorySlug: widget.initial.categorySlug,
                        shopSlug: widget.initial.shopSlug,
                        search: widget.initial.search,
                        sort: ProductSort.createdAt,
                      ),
                    );
                  },
                  child: Text(tr('catalog.reset')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    final min = int.tryParse(_minCtrl.text.trim());
                    final max = int.tryParse(_maxCtrl.text.trim());
                    Navigator.of(context).pop(widget.initial.copyWith(
                      sort: _sort,
                      minPrice: min,
                      maxPrice: max,
                      clearMinPrice: min == null,
                      clearMaxPrice: max == null,
                    ));
                  },
                  child: Text(tr('catalog.apply')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sortLabel(ProductSort sort) {
    return switch (sort) {
      ProductSort.createdAt => tr('catalog.sort_newest'),
      ProductSort.priceAsc => tr('catalog.sort_price_asc'),
      ProductSort.priceDesc => tr('catalog.sort_price_desc'),
      ProductSort.popular => tr('catalog.sort_popular'),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/supabase_category_repository.dart';
import '../../../../shared/repositories/supabase_product_data_source.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../widgets/filter/active_filters_bar.dart';
import '../../../widgets/filter/filter_button.dart';
import '../../favorites/bloc/favorites_bloc.dart';
import '../../home/widgets/premium/premium_product_card.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../bloc/search_bloc.dart';
import '../widgets/search_filter_sheet.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchBloc(
        source: sl<SupabaseProductDataSource>(),
        cacheBox: sl<Box>(instanceName: HiveBoxes.cache),
      ),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _openFilter(BuildContext context) async {
    final bloc = context.read<SearchBloc>();
    final state = bloc.state;
    _focus.unfocus();
    final next = await showSearchFilterSheet(
      context,
      initial: state.filter,
      currentResultCount: state.results.length,
      availability: FilterAvailability(
        colorSlugs: state.results.expand((p) => p.colors).toSet(),
        hasDiscounted: state.results.any((p) => p.hasDiscount),
        hasDelivery: state.results.any((p) => p.hasDelivery),
      ),
    );
    if (next != null && next != state.filter) {
      bloc.add(SearchFilterChanged(next));
    }
  }

  void _setQuery(String value) {
    _ctrl.text = value;
    _ctrl.selection = TextSelection.collapsed(offset: value.length);
    context.read<SearchBloc>().add(SearchQueryChanged(value));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      appBar: AppBar(
        backgroundColor: pt.background,
        foregroundColor: pt.dark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: pt.dark,
          ),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: _SearchField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: (v) {
            context.read<SearchBloc>().add(SearchQueryChanged(v));
            setState(() {});
          },
          onSubmitted: (v) =>
              context.read<SearchBloc>().add(SearchSubmitted(v)),
          onClear: () {
            _ctrl.clear();
            context.read<SearchBloc>().add(const SearchQueryChanged(''));
            setState(() {});
          },
        ),
        actions: [
          BlocSelector<SearchBloc, SearchState, int>(
            selector: (s) => s.filter.activeCount,
            builder: (context, count) => FilterButton(
              count: count,
              onTap: () => _openFilter(context),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          return Column(
            children: [
              if (state.filter.isNotEmpty)
                ActiveFiltersBar(
                  filter: state.filter,
                  onChanged: (next) =>
                      context.read<SearchBloc>().add(SearchFilterChanged(next)),
                ),
              if (state.hasInput && state.status == SearchStatus.ready)
                _ResultsHeader(
                  count: state.results.length,
                  sort: state.filter.sort,
                  onChangeSort: (s) => context.read<SearchBloc>().add(
                        SearchFilterChanged(state.filter.copyWith(sort: s)),
                      ),
                ),
              Expanded(
                child: _Body(
                  state: state,
                  onRecentTap: _setQuery,
                  onClearRecent: () => context
                      .read<SearchBloc>()
                      .add(const SearchHistoryCleared()),
                  onProductTap: (p) {
                    context
                        .read<SearchBloc>()
                        .add(SearchSubmitted(state.query));
                    context.push('/product-detail/${p.id}', extra: p);
                  },
                  onRetry: () => context
                      .read<SearchBloc>()
                      .add(SearchQueryChanged(state.query)),
                  onOpenFilter: () => _openFilter(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      height: 42,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Iconsax.search_normal_1, color: pt.grey, size: 17),
          const SizedBox(width: 10),
          Expanded(
            // The app's global `inputDecorationTheme` (see customer_theme.dart)
            // forces every TextField into a filled OutlineInputBorder with a
            // terracotta focused ring. That looks correct inside forms but
            // double-borders this field, which already lives in its own pill
            // container. Neutralising the inherited theme for *just* this
            // subtree keeps the form fields elsewhere untouched.
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                cursorColor: PremiumTokens.accent,
                cursorWidth: 1.6,
                style: PremiumTokens.body(
                  size: 14.5,
                  weight: FontWeight.w500,
                  color: pt.dark,
                ),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: tr('search.hint'),
                  hintStyle: PremiumTokens.body(size: 14, color: pt.grey),
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pt.imageBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: pt.grey,
                    size: 12,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Results header (count + sort) ─────────────────────────────────────────

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.sort,
    required this.onChangeSort,
  });

  final int count;
  final ProductSearchSort sort;
  final ValueChanged<ProductSearchSort> onChangeSort;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: PremiumTokens.body(size: 12.5, color: pt.grey),
                children: [
                  TextSpan(
                    text: '$count',
                    style: PremiumTokens.body(
                      size: 13,
                      weight: FontWeight.w800,
                      color: pt.dark,
                    ),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(text: tr('search.results').toLowerCase()),
                ],
              ),
            ),
          ),
          PopupMenuButton<ProductSearchSort>(
            tooltip: tr('search.filter.sort'),
            position: PopupMenuPosition.under,
            offset: const Offset(0, 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: pt.surface,
            elevation: 8,
            onSelected: onChangeSort,
            itemBuilder: (context) => [
              for (final s in ProductSearchSort.values)
                PopupMenuItem(
                  value: s,
                  height: 40,
                  child: Row(
                    children: [
                      Icon(
                        sort == s
                            ? Iconsax.tick_circle
                            : Iconsax.arrow_right_3,
                        size: 15,
                        color: sort == s
                            ? PremiumTokens.accent
                            : pt.grey,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _label(s),
                        style: PremiumTokens.body(
                          size: 13,
                          weight: sort == s
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: pt.dark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.sort,
                    size: 14,
                    color: PremiumTokens.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _label(sort),
                    style: PremiumTokens.body(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: pt.dark,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Iconsax.arrow_down_1, size: 12, color: pt.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _label(ProductSearchSort s) => switch (s) {
        ProductSearchSort.newest => tr('search.filter.sort_newest'),
        ProductSearchSort.priceAsc => tr('search.filter.sort_price_asc'),
        ProductSearchSort.priceDesc => tr('search.filter.sort_price_desc'),
      };
}

// ── Body switcher ─────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.onRecentTap,
    required this.onClearRecent,
    required this.onProductTap,
    required this.onRetry,
    required this.onOpenFilter,
  });

  final SearchState state;
  final ValueChanged<String> onRecentTap;
  final VoidCallback onClearRecent;
  final ValueChanged<SupabaseProductModel> onProductTap;
  final VoidCallback onRetry;
  final VoidCallback onOpenFilter;

  @override
  Widget build(BuildContext context) {
    if (!state.hasInput) {
      return _IdleView(
        recent: state.recent,
        onRecentTap: onRecentTap,
        onClearRecent: onClearRecent,
      );
    }
    return switch (state.status) {
      SearchStatus.idle ||
      SearchStatus.loading =>
        const _SearchSkeleton(),
      SearchStatus.failure => ErrorState(
          message: state.error,
          onRetry: onRetry,
        ),
      SearchStatus.ready => state.results.isEmpty
          ? _NoResultsView(
              hasFilters: state.filter.isNotEmpty,
              onOpenFilter: onOpenFilter,
            )
          : _ResultsGrid(
              results: state.results,
              onItemTap: onProductTap,
            ),
    };
  }
}

// ── Idle (recent + popular) ───────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.recent,
    required this.onRecentTap,
    required this.onClearRecent,
  });

  final List<String> recent;
  final ValueChanged<String> onRecentTap;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        if (recent.isEmpty)
          const _EmptyHero()
        else
          _RecentList(
            recent: recent,
            onTap: onRecentTap,
            onClear: onClearRecent,
          ),
        const SizedBox(height: 24),
        const _PopularCategoriesSection(),
      ],
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: PremiumTokens.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.search_normal_1,
              size: 38,
              color: PremiumTokens.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('search.no_recent'),
            textAlign: TextAlign.center,
            style: PremiumTokens.display(
              size: 18,
              weight: FontWeight.w700,
              color: pt.dark,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              tr('search.hint'),
              textAlign: TextAlign.center,
              style: PremiumTokens.body(size: 13, color: pt.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.recent,
    required this.onTap,
    required this.onClear,
  });

  final List<String> recent;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            children: [
              Icon(Iconsax.clock, size: 16, color: pt.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr('search.recent'),
                  style: PremiumTokens.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: pt.dark,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    tr('search.clear'),
                    style: PremiumTokens.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: PremiumTokens.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in recent)
              _RecentChip(label: term, onTap: () => onTap(term)),
          ],
        ),
      ],
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: pt.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: PremiumTokens.softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.clock, size: 14, color: pt.grey),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTokens.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: pt.dark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Popular categories tile grid ──────────────────────────────────────────

class _PopularCategoriesSection extends StatefulWidget {
  const _PopularCategoriesSection();

  @override
  State<_PopularCategoriesSection> createState() =>
      _PopularCategoriesSectionState();
}

class _PopularCategoriesSectionState extends State<_PopularCategoriesSection> {
  late final Future<List<CategoryModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<CategoryDataSource>().list();
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              Icon(Iconsax.category, size: 16, color: pt.grey),
              const SizedBox(width: 6),
              Text(
                tr('search.popular'),
                style: PremiumTokens.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: pt.dark,
                ),
              ),
            ],
          ),
        ),
        FutureBuilder<List<CategoryModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _PopularSkeleton(color: pt.imageBg);
            }
            final cats = (snap.data ?? const []).take(6).toList();
            if (cats.isEmpty) return const SizedBox.shrink();
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in cats)
                  _PopularCategoryChip(
                    category: c,
                    onTap: () => context
                        .read<SearchBloc>()
                        .add(SearchFilterChanged(
                          ProductSearchFilter(
                            categoryIds: {c.id},
                            sort: context
                                .read<SearchBloc>()
                                .state
                                .filter
                                .sort,
                          ),
                        )),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PopularCategoryChip extends StatelessWidget {
  const _PopularCategoryChip({required this.category, required this.onTap});

  final CategoryModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: pt.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: PremiumTokens.softShadow,
            border: Border.all(color: pt.divider, width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Iconsax.category_2,
                  size: 14,
                  color: PremiumTokens.accent,
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTokens.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: pt.dark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularSkeleton extends StatelessWidget {
  const _PopularSkeleton({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        6,
        (i) => Container(
          width: 120 + (i % 3) * 24.0,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── No results ────────────────────────────────────────────────────────────

class _NoResultsView extends StatelessWidget {
  const _NoResultsView({required this.hasFilters, required this.onOpenFilter});

  final bool hasFilters;
  final VoidCallback onOpenFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: EmptyState(
            icon: Iconsax.search_status,
            title: tr('search.no_results'),
            message: tr('search.no_results_hint'),
          ),
        ),
        if (hasFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onOpenFilter,
                icon: const Icon(Iconsax.setting_4, size: 18),
                label: Text(tr('search.filter.title')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PremiumTokens.accent,
                  side: const BorderSide(color: PremiumTokens.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: PremiumTokens.body(
                    size: 14,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Results grid ──────────────────────────────────────────────────────────

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({required this.results, required this.onItemTap});

  final List<SupabaseProductModel> results;
  final ValueChanged<SupabaseProductModel> onItemTap;

  static String _formatPrice(double price) {
    final formatted = NumberFormat('#,##0', 'en_US').format(price);
    return '$formatted UZS';
  }

  static Product _toProduct(SupabaseProductModel m) => Product(
        id: m.id,
        slug: m.id,
        name: MultilingualText(uz: m.name, ru: m.name, en: m.name),
        price: m.effectivePrice,
        oldPrice: m.hasDiscount ? m.price : null,
        images: m.images,
        primaryImage: m.thumbnail,
        attributes: m.attributes,
        stock: m.stock,
      );

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final p = results[i];
        return BlocSelector<FavoritesBloc, FavoritesState, bool>(
          selector: (s) => s.isFavorite(p.id),
          builder: (context, isFav) => PremiumProductCard(
            imageUrl: p.thumbnail ?? '',
            name: p.name,
            shop: p.description ?? '',
            price: _formatPrice(p.effectivePrice),
            discountPercent: p.discountPercent,
            isFavorite: isFav,
            onTap: () => onItemTap(p),
            onFavoriteToggle: () => context.read<FavoritesBloc>().add(
                  FavoriteToggled(_toProduct(p)),
                ),
          ),
        );
      },
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: pt.imageBg,
        highlightColor: pt.surface,
        child: Container(
          decoration: BoxDecoration(
            color: pt.imageBg,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

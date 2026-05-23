import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../features/favorites/bloc/favorites_bloc.dart';
import '../../../widgets/filter/active_filters_bar.dart';
import '../../../widgets/filter/filter_button.dart';
import '../../../widgets/glass_bottom_nav.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../../search/widgets/search_filter_sheet.dart';
import '../cubit/product_list_cubit.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({
    super.key,
    required this.categoryId,
    this.subcategoryId,
    required this.categoryName,
  });

  final String categoryId;
  final String? subcategoryId;
  final String categoryName;

  Future<void> _openFilter(
    BuildContext context,
    ProductListState state,
  ) async {
    final cubit = context.read<ProductListCubit>();
    final next = await showSearchFilterSheet(
      context,
      initial: state.filter,
      currentResultCount: state.products.length,
      // Already scoped to one category — the multi-category picker would
      // either be a no-op (when the chosen category matches) or contradict
      // the current scope. Hiding it keeps the sheet focused.
      showCategories: false,
      availability: _availabilityFor(state),
    );
    if (next != null) await cubit.applyFilter(next);
  }

  /// Distil the currently visible products into "which facets are worth
  /// showing in the filter sheet". The user shouldn't be offered a colour
  /// or option that would guarantee zero results.
  FilterAvailability _availabilityFor(ProductListState state) {
    final products = state.products;
    return FilterAvailability(
      colorSlugs: products.expand((p) => p.colors).toSet(),
      hasDiscounted: products.any((p) => p.hasDiscount),
      hasDelivery: products.any((p) => p.hasDelivery),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);

    return Scaffold(
      backgroundColor: pt.background,
      body: BlocBuilder<ProductListCubit, ProductListState>(
        builder: (context, state) {
          if (state.status == ProductListStatus.failure) {
            return _ErrorView(
              message: state.error ?? '',
              onRetry: () => context.read<ProductListCubit>().load(
                categoryId: categoryId,
                subcategoryId: subcategoryId,
              ),
            );
          }

          final isLoading =
              state.status == ProductListStatus.initial ||
              state.status == ProductListStatus.loading;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _AppBar(
                title: categoryName,
                filterCount: state.filter.activeCount,
                onFilterTap: () => _openFilter(context, state),
              ),
              if (state.subcategories.isNotEmpty)
                SliverToBoxAdapter(
                  child: _SubcategoryChipsBar(
                    subcategories: state.subcategories,
                    selectedId: state.selectedSubcategoryId,
                    onSelect: (id) =>
                        context.read<ProductListCubit>().selectSubcategory(id),
                  ),
                ),
              if (state.filter.isNotEmpty)
                SliverToBoxAdapter(
                  child: ActiveFiltersBar(
                    filter: state.filter,
                    onChanged: (next) =>
                        context.read<ProductListCubit>().applyFilter(next),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  GlassBottomNav.reservedHeight(context) + 24,
                ),
                sliver: isLoading
                    ? const _SkeletonGrid()
                    : state.products.isEmpty
                    ? const _EmptySliver()
                    : _ProductGrid(products: state.products),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App bar
// ---------------------------------------------------------------------------

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.title,
    required this.filterCount,
    required this.onFilterTap,
  });

  final String title;
  final int filterCount;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SliverAppBar(
      backgroundColor: pt.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: pt.dark,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: pt.dark),
        onPressed: () => context.pop(),
      ),
      title: Text(
        title,
        style: PremiumTokens.display(size: 22, letterSpacing: -0.4),
      ),
      actions: [
        FilterButton(count: filterCount, onTap: onFilterTap),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Subcategory chips
// ---------------------------------------------------------------------------

class _SubcategoryChipsBar extends StatefulWidget {
  const _SubcategoryChipsBar({
    required this.subcategories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SubcategoryModel> subcategories;

  /// `null` means the "All" pseudo-chip is active.
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  State<_SubcategoryChipsBar> createState() => _SubcategoryChipsBarState();
}

class _SubcategoryChipsBarState extends State<_SubcategoryChipsBar> {
  final _scroll = ScrollController();
  // Build a stable key per chip up front so [didUpdateWidget] can ask each
  // chip for its current geometry via [RenderBox] and we can scroll the
  // active one into view after the bloc swaps the selection.
  late List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.subcategories.length + 1, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant _SubcategoryChipsBar old) {
    super.didUpdateWidget(old);
    if (widget.subcategories.length != old.subcategories.length) {
      _keys =
          List.generate(widget.subcategories.length + 1, (_) => GlobalKey());
    }
    if (widget.selectedId != old.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    if (!_scroll.hasClients) return;
    final selectedIndex = widget.selectedId == null
        ? 0
        : widget.subcategories.indexWhere((s) => s.id == widget.selectedId) + 1;
    if (selectedIndex < 0 || selectedIndex >= _keys.length) return;
    final ctx = _keys[selectedIndex].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.2,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedId;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: widget.subcategories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _SubcategoryChip(
              key: _keys[0],
              label: tr('common.all'),
              selected: selected == null,
              onTap: () => widget.onSelect(null),
            );
          }
          final sub = widget.subcategories[i - 1];
          return _SubcategoryChip(
            key: _keys[i],
            label: sub.name,
            selected: selected == sub.id,
            onTap: () => widget.onSelect(sub.id),
          );
        },
      ),
    );
  }
}

class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({
    super.key,
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? PremiumTokens.accent : pt.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: PremiumTokens.accent.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : PremiumTokens.softShadow,
          ),
          child: Center(
            child: Text(
              label,
              style: PremiumTokens.body(
                size: 13,
                weight: FontWeight.w700,
                color: selected ? Colors.white : pt.dark,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Product grid
// ---------------------------------------------------------------------------

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<SupabaseProductModel> products;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: products.length,
      itemBuilder: (context, i) => _ProductCard(product: products[i]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final SupabaseProductModel product;

  static String _formatPrice(double price) {
    final formatted = NumberFormat('#,##0', 'en_US').format(price);
    return '$formatted UZS';
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);

    return GestureDetector(
      onTap: () =>
          context.push('/product-detail/${product.id}', extra: product),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: PremiumTokens.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (product.thumbnail != null)
                      CachedNetworkImage(
                        imageUrl: product.thumbnail!,
                        // ROADMAP B.7 — 2-column grid product card.
                        memCacheWidth: 600,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Shimmer.fromColors(
                          baseColor: pt.imageBg,
                          highlightColor: pt.background,
                          child: Container(color: pt.imageBg),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: pt.imageBg,
                          child: Icon(
                            Iconsax.gallery,
                            color: pt.greyLight,
                            size: 28,
                          ),
                        ),
                      )
                    else
                      Container(color: pt.imageBg),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _FavHeart(product: product),
                    ),
                    if (product.hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC0392B),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '-${product.discountPercent}%',
                            style: PremiumTokens.body(
                              size: 10.5,
                              weight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTokens.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: pt.dark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatPrice(product.effectivePrice),
                      style: PremiumTokens.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: PremiumTokens.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Favorite heart button
// ---------------------------------------------------------------------------

class _FavHeart extends StatelessWidget {
  const _FavHeart({required this.product});

  final SupabaseProductModel product;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FavoritesBloc, FavoritesState, bool>(
      selector: (state) => state.isFavorite(product.id),
      builder: (context, isFav) {
        return GestureDetector(
          onTap: () => context.read<FavoritesBloc>().add(
            FavoriteToggled(_toProduct(product)),
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  isFav ? Iconsax.heart_copy : Iconsax.heart,
                  size: 16,
                  color: isFav ? PremiumTokens.accent : Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Product _toProduct(SupabaseProductModel m) => Product(
  id: m.id,
  slug: m.id,
  name: MultilingualText(uz: m.name, ru: m.name, en: m.name),
  price: m.effectivePrice,
  oldPrice: m.hasDiscount ? m.price : null,
  images: m.images,
  attributes: m.attributes,
  stock: m.stock,
);

// ---------------------------------------------------------------------------
// Skeleton + empty + error
// ---------------------------------------------------------------------------

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (context, _) => Shimmer.fromColors(
        baseColor: pt.imageBg,
        highlightColor: pt.surface,
        child: Container(
          decoration: BoxDecoration(
            color: pt.imageBg,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _EmptySliver extends StatelessWidget {
  const _EmptySliver();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.box, size: 48, color: pt.greyLight),
            const SizedBox(height: 16),
            Text(
              tr('product.list_empty'),
              style: PremiumTokens.body(
                size: 16,
                weight: FontWeight.w600,
                color: pt.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.warning_2, size: 48, color: pt.greyLight),
            const SizedBox(height: 16),
            Text(
              tr('product.list_error_title'),
              style: PremiumTokens.body(
                size: 16,
                weight: FontWeight.w600,
                color: pt.dark,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: PremiumTokens.body(size: 13, color: pt.grey),
              ),
            ],
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(tr('product.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

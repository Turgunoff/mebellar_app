import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/repositories/category_data_source.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/product_ar_badge.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../features/favorites/bloc/favorites_bloc.dart';
import '../../../widgets/filter/active_filters_bar.dart';
import '../../../widgets/filter/filter_button.dart';
import '../../../widgets/network_error_gate.dart';
import '../../../widgets/price_format.dart';
import '../../../widgets/view_mode_toggle.dart';
import '../../home/widgets/premium/premium_product_list_card.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../search/widgets/search_filter_sheet.dart';
import '../cubit/product_list_cubit.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    super.key,
    required this.categoryId,
    this.subcategoryId,
    required this.categoryName,
  });

  final String categoryId;
  final String? subcategoryId;
  final String categoryName;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  // Shared, app-wide grid/list preference (see ProductViewModeController) so the
  // choice stays in lock-step with the home feed and survives navigation +
  // restart. Not disposed here — it's a DI singleton owned by the locator, not
  // this screen.
  final ProductViewModeController _viewMode = sl<ProductViewModeController>();

  Future<void> _openFilter(BuildContext context, ProductListState state) async {
    final cubit = context.read<ProductListCubit>();
    final next = await showSearchFilterSheet(
      context,
      initial: state.filter,
      currentResultCount: state.products.length,
      categorySource: sl<CategoryDataSource>(),
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
      body: NetworkErrorGate<ProductListCubit, ProductListState>(
        onRetry: (cubit) => cubit.load(
          categoryId: widget.categoryId,
          subcategoryId: widget.subcategoryId,
        ),
        child: BlocBuilder<ProductListCubit, ProductListState>(
          builder: (context, state) {
            if (state.status == ProductListStatus.failure) {
              return ErrorState(
                title: tr('product.list_error_title'),
                message: state.error,
                onRetry: () => context.read<ProductListCubit>().load(
                  categoryId: widget.categoryId,
                  subcategoryId: widget.subcategoryId,
                ),
              );
            }

            final isLoading =
                state.status == ProductListStatus.initial ||
                state.status == ProductListStatus.loading;

            return ValueListenableBuilder<ProductViewMode>(
              valueListenable: _viewMode,
              builder: (context, viewMode, _) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _AppBar(
                      title: widget.categoryName,
                      filterCount: state.filter.activeCount,
                      onFilterTap: () => _openFilter(context, state),
                      viewMode: viewMode,
                      onViewModeChanged: _viewMode.set,
                    ),
                    if (state.subcategories.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _SubcategoryChipsBar(
                          subcategories: state.subcategories,
                          selectedId: state.selectedSubcategoryId,
                          onSelect: (id) => context
                              .read<ProductListCubit>()
                              .selectSubcategory(id),
                        ),
                      ),
                    if (state.filter.isNotEmpty)
                      SliverToBoxAdapter(
                        child: ActiveFiltersBar(
                          filter: state.filter,
                          onChanged: (next) => context
                              .read<ProductListCubit>()
                              .applyFilter(next),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: isLoading
                          ? (viewMode == ProductViewMode.grid
                                ? const _SkeletonGrid()
                                : const _SkeletonList())
                          : state.products.isEmpty
                          ? const _EmptySliver()
                          : (viewMode == ProductViewMode.grid
                                ? _ProductGrid(
                                    products: state.products,
                                    onIndexBuilt: (i) =>
                                        _maybeLoadMore(context, state, i),
                                  )
                                : _ProductListView(
                                    products: state.products,
                                    onIndexBuilt: (i) =>
                                        _maybeLoadMore(context, state, i),
                                  )),
                    ),
                    SliverToBoxAdapter(
                      child: _LoadMoreFooter(
                        loadingMore: state.loadingMore,
                        // Pushed full-screen route (no bottom nav) — clear only
                        // the device safe-area inset.
                        bottomInset:
                            MediaQuery.viewPaddingOf(context).bottom + 24,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
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
    required this.viewMode,
    required this.onViewModeChanged,
  });

  final String title;
  final int filterCount;
  final VoidCallback onFilterTap;
  final ProductViewMode viewMode;
  final ValueChanged<ProductViewMode> onViewModeChanged;

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
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Iconsax.arrow_left_2_copy, size: 20, color: pt.dark),
        // The category list is reached by `push` from the Categories tab, so a
        // plain pop drops the user right back onto it (the home shell keeps that
        // tab alive). The fallback only fires when there's nothing to pop — a
        // cold deep-link straight into a category — and routes to the Categories
        // tab so Back never dead-ends on Home or a half-built stack.
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/?tab=categories'),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PremiumTokens.display(size: 22, letterSpacing: -0.4),
      ),
      actions: [
        ViewModeToggle(viewMode: viewMode, onChanged: onViewModeChanged),
        const SizedBox(width: 8),
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
      _keys = List.generate(
        widget.subcategories.length + 1,
        (_) => GlobalKey(),
      );
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
  const _ProductGrid({required this.products, required this.onIndexBuilt});

  final List<ProductModel> products;

  /// Invoked with each item index as it builds, so the parent can arm the
  /// next-page fetch as the user nears the end of the loaded window.
  final ValueChanged<int> onIndexBuilt;

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
      itemBuilder: (context, i) {
        onIndexBuilt(i);
        return _ProductCard(product: products[i]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Product list (full-width rows) — the "list" view-mode counterpart of the
// grid. Reuses the shared [PremiumProductListCard] so a category list row reads
// identically to the home feed's list mode.
// ---------------------------------------------------------------------------

class _ProductListView extends StatelessWidget {
  const _ProductListView({required this.products, required this.onIndexBuilt});

  final List<ProductModel> products;

  /// Invoked with each item index as it builds, so the parent can arm the
  /// next-page fetch as the user nears the end of the loaded window.
  final ValueChanged<int> onIndexBuilt;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        onIndexBuilt(i);
        final product = products[i];
        return BlocSelector<FavoritesBloc, FavoritesState, bool>(
          selector: (state) => state.isFavorite(product.id),
          builder: (context, isFav) => PremiumProductListCard(
            imageUrl: product.thumbnail ?? '',
            name: product.name,
            subtitle: product.description ?? '',
            price: formatUzsPrice(product.effectivePrice),
            oldPrice: product.hasDiscount
                ? formatUzsPrice(product.price)
                : null,
            discountPercent: product.discountPercent,
            isFavorite: isFav,
            hasAr: product.hasAr,
            onTap: () =>
                context.push('/product-detail/${product.id}', extra: product),
            onFavoriteToggle: () => context.read<FavoritesBloc>().add(
              FavoriteToggled(Product.fromModel(product)),
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final ProductModel product;

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
                        placeholder: (_, _) => const ShimmerBox(
                          borderRadius: 0,
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
                            color: Theme.of(context).colorScheme.error,
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
                    if (product.hasAr)
                      const Positioned(
                        bottom: 8,
                        left: 8,
                        child: ProductArBadge(),
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
                      formatUzsPrice(product.effectivePrice),
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

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FavoritesBloc, FavoritesState, bool>(
      selector: (state) => state.isFavorite(product.id),
      builder: (context, isFav) {
        return GestureDetector(
          onTap: () => context.read<FavoritesBloc>().add(
            FavoriteToggled(Product.fromModel(product)),
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

// ---------------------------------------------------------------------------
// Infinite-scroll trigger + footer
// ---------------------------------------------------------------------------

/// Smart pre-fetch: as the user nears the end of the loaded page (within the
/// last 5 items — i.e. the 10th of a 15-item batch), enqueue the next page so a
/// spinner rarely appears. The cubit guards `hasMore` / `loadingMore` and flips
/// `loadingMore` synchronously, so calling this for every trailing item on each
/// build collapses to a single fetch per batch.
void _maybeLoadMore(BuildContext context, ProductListState state, int index) {
  if (state.hasMore &&
      !state.loadingMore &&
      index >= state.products.length - 5) {
    context.read<ProductListCubit>().loadMore();
  }
}

/// Footer below the grid/list: a centred spinner while the next page appends,
/// collapsing to a hairline gap when idle. Always reserves [bottomInset] so the
/// final row clears the floating bottom nav.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.loadingMore, required this.bottomInset});

  final bool loadingMore;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: loadingMore
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: PremiumTokens.accent,
                  ),
                ),
              ),
            )
          : const SizedBox(height: 4),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton + empty + error
// ---------------------------------------------------------------------------

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (context, _) => const ShimmerBox(borderRadius: 16),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, _) => const ShimmerBox(
        // The strict-square card rests at its 120px thumbnail height for the
        // common row, so the shimmer matches it — real rows replace the
        // placeholders without the list jumping.
        height: 120,
        borderRadius: 20,
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

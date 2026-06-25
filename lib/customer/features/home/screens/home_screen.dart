import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/repositories/product_data_source.dart';
import '../../../customer_app.dart';
import '../../../widgets/network_error_gate.dart';
import '../../../widgets/network_error_view.dart';
import '../../../widgets/price_format.dart';
import '../../../widgets/view_mode_toggle.dart';
import '../../categories/bloc/categories_bloc.dart';
import '../../favorites/bloc/favorites_bloc.dart';
import '../../notifications/cubit/notifications_cubit.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../../ai_designer/widgets/ai_chat_fab.dart';
import '../bloc/home_bloc.dart';
import '../widgets/premium/glass_banner.dart';
import '../widgets/premium/premium_product_card.dart';
import '../widgets/premium/premium_product_list_card.dart';
import '../widgets/premium/premium_tokens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Shared, app-wide grid/list preference (see ProductViewModeController) so a
  // toggle here or on any category list applies everywhere — including this tab
  // when it's kept alive in the shell. Not disposed: it's a DI singleton.
  final ProductViewModeController _viewMode = sl<ProductViewModeController>();

  /// Pull-to-refresh handler shared by the error and content scroll views.
  /// [CupertinoSliverRefreshControl] holds its spinner up until this future
  /// settles, so we fire a full refresh and wait for the feed to land (or
  /// fail). The timeout sits just past the bloc's own 5s load ceiling so an
  /// unchanged-payload refetch — which Bloc de-dupes and never re-emits —
  /// can't pin the spinner open forever.
  Future<void> _handleRefresh(BuildContext context) async {
    final bloc = context.read<HomeBloc>();
    bloc.add(const HomeRequested(refresh: true));
    await bloc.stream
        .firstWhere(
          (s) => s.status == HomeStatus.ready || s.status == HomeStatus.failure,
        )
        .timeout(const Duration(seconds: 6), onTimeout: () => bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    // .value here is critical — using `create` would spawn a fresh cubit
    // per HomeScreen mount, defeating the singleton (the bell badge would
    // diverge from the inbox screen). The DI singleton owns the Realtime
    // channel; we just hand the same instance down the tree.
    return BlocProvider<NotificationsCubit>.value(
      value: sl<NotificationsCubit>(),
      // Transparent Scaffold layered over the home feed so the animated AI FAB
      // floats bottom-right above the shell's bottom nav without disturbing the
      // existing feed layout.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: const AiChatFab(),
        body: ColoredBox(
          color: pt.background,
          child: NetworkErrorGate<HomeBloc, HomeState>(
            isActive: (ctx) => CustomerShellScope.of(ctx).index == 0,
            onRetry: (bloc) => bloc.add(const HomeRequested(refresh: true)),
            backgroundError: (s) =>
                s.status == HomeStatus.ready && s.error != null
                ? s.error
                : null,
            child: BlocBuilder<HomeBloc, HomeState>(
              buildWhen: (a, b) => a.status != b.status,
              builder: (context, state) {
                final showError =
                    state.status == HomeStatus.failure &&
                    state.banners.isEmpty &&
                    state.recommended.isEmpty;

                if (showError) {
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      const _HomeAppBar(),
                      CupertinoSliverRefreshControl(
                        onRefresh: () => _handleRefresh(context),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                          child: const _PremiumSearchBar(),
                        ),
                      ),
                      SliverFillRemaining(
                        child: NetworkErrorView(
                          onRetry: () => context.read<HomeBloc>().add(
                            const HomeRequested(refresh: true),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Rebuild the scroll view when the view mode flips so the feed
                // sliver swaps between masonry grid and full-width list. Toggling
                // is rare; banners/categories ride their own cached BlocBuilders,
                // so the rebuild is cheap.
                return ValueListenableBuilder<ProductViewMode>(
                  valueListenable: _viewMode,
                  builder: (context, viewMode, _) {
                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        const _HomeAppBar(),
                        CupertinoSliverRefreshControl(
                          onRefresh: () => _handleRefresh(context),
                        ),
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              const _PremiumSearchBar(),
                              const SizedBox(height: 12),
                              BlocBuilder<HomeBloc, HomeState>(
                                buildWhen: (prev, curr) =>
                                    prev.status != curr.status ||
                                    prev.banners != curr.banners,
                                builder: (context, s) {
                                  if (s.status == HomeStatus.loading ||
                                      s.status == HomeStatus.initial) {
                                    return const GlassBannerShimmer();
                                  }
                                  // Editorial banners are DB-driven only — no
                                  // static fallback. The injected seller-promo
                                  // slide rides ahead of them, EXCEPT for an
                                  // approved seller — they already run a shop,
                                  // so the "Sotuvchi bo'ling" CTA is noise.
                                  // GlassBanner collapses to nothing if the
                                  // list ends up empty.
                                  final isApprovedSeller = context
                                      .select<ProfileCubit, bool>(
                                        (c) => c.state.isSellerApproved,
                                      );
                                  return GlassBanner(
                                    banners: [
                                      if (!isApprovedSeller)
                                        GlassBanner.sellerPromoBanner,
                                      ...s.banners,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _SectionHeader(
                                title: tr('home.categories'),
                                actionLabel: tr('home.see_all'),
                                onAction: () =>
                                    CustomerShellScope.of(context).goToTab(1),
                              ),
                              const SizedBox(height: 16),
                              const _CategoriesRow(),
                              const SizedBox(height: 32),
                              _RecommendedHeader(
                                viewMode: viewMode,
                                onViewModeChanged: _viewMode.set,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        _RecommendedFeed(viewMode: viewMode),
                        const _RecommendedFeedFooter(),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── App bar ───────────────────────────

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SliverAppBar(
      pinned: true,
      expandedHeight: 130.0,
      backgroundColor: pt.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: const _NotificationBell(),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        expandedTitleScale: 1.6,
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
        title: Text(
          tr('home.discover_title'),
          style: PremiumTokens.display(size: 20, letterSpacing: -0.4),
        ),
        background: Container(
          color: pt.surface,
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.only(left: 20, bottom: 52),
          child: Text(
            tr('home.discover_eyebrow'),
            style: PremiumTokens.body(
              size: 12,
              weight: FontWeight.w600,
              color: PremiumTokens.accent,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/customer/notifications'),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: pt.surface,
          shape: BoxShape.circle,
          boxShadow: PremiumTokens.softShadow,
        ),
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          // Customer surface only — seller-panel alerts are counted on the
          // profile's seller-panel badge, never in the buyer's bell.
          buildWhen: (a, b) => a.customerUnreadCount != b.customerUnreadCount,
          builder: (context, state) {
            final count = state.customerUnreadCount;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(Iconsax.notification_copy, color: pt.dark, size: 22),
                if (count > 0)
                  Positioned(
                    top: 8,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: PremiumTokens.accent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: pt.surface, width: 1.5),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: PremiumTokens.body(
                          size: 9,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────── Search bar (read-only) ───────────────────────────

class _PremiumSearchBar extends StatelessWidget {
  const _PremiumSearchBar();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/search'),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: pt.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 18),
              Icon(Iconsax.search_normal_1_copy, color: pt.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('home.search_hint'),
                  style: PremiumTokens.body(size: 14, color: pt.grey),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.setting_4,
                  color: PremiumTokens.accent,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Section header ───────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  actionLabel!,
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
    );
  }
}

// ─────────────────────────── Categories ───────────────────────────

class _CategoriesRow extends StatefulWidget {
  const _CategoriesRow();

  @override
  State<_CategoriesRow> createState() => _CategoriesRowState();
}

class _CategoriesRowState extends State<_CategoriesRow> {
  // Index into the row of pills, including the leading synthetic "All" chip
  // at position 0. Defaults to "All" so the first paint signals "no filter,
  // showing everything" — matches what the home shelf actually displays.
  // Lives in widget state only; resets on cold restart / mode swap, which is
  // fine for a navigational hint.
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoriesBloc, CategoriesState>(
      buildWhen: (a, b) => a.status != b.status || a.categories != b.categories,
      builder: (context, state) {
        final isLoading =
            state.status == CategoriesStatus.loading ||
            state.status == CategoriesStatus.initial;
        if (isLoading) return const _CategoriesRowSkeleton();
        if (state.categories.isEmpty) {
          return const SizedBox.shrink();
        }
        // Top-N cap keeps the home shelf scannable; the section header's
        // "Barchasi" link is the escape hatch into the full categories grid.
        final visibleCount = state.categories.length.clamp(0, 4);
        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            // +1 for the leading "All" chip at index 0.
            itemCount: visibleCount + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _CategoryPill(
                  label: tr('home.see_all'),
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                );
              }
              final cat = state.categories[i - 1];
              return _CategoryPill(
                label: cat.name,
                isSelected: _selectedIndex == i,
                onTap: () async {
                  setState(() => _selectedIndex = i);
                  // `push` returns when the pushed route is popped. Reset to
                  // "Barchasi" so the chip row reflects the home shelf's
                  // actual state (unfiltered) when the user comes back.
                  await context.push<void>(
                    '/product-list'
                    '?categoryId=${Uri.encodeComponent(cat.id)}'
                    '&categoryName=${Uri.encodeComponent(cat.name)}',
                  );
                  if (mounted) {
                    setState(() => _selectedIndex = 0);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;

  /// When true, renders the filled accent variant (white text on terracotta
  /// fill, no border). Otherwise: surface fill, dark text, hairline border.
  final bool isSelected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final bgColor = isSelected ? PremiumTokens.accent : pt.surface;
    final textColor = isSelected ? Colors.white : pt.dark;
    final borderColor = isSelected
        ? Colors.transparent
        : pt.dark.withValues(alpha: 0.08);

    return Center(
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: isSelected
              ? Colors.white.withValues(alpha: 0.15)
              : PremiumTokens.accent.withValues(alpha: 0.10),
          highlightColor: isSelected
              ? Colors.white.withValues(alpha: 0.06)
              : PremiumTokens.accent.withValues(alpha: 0.04),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                label,
                style: PremiumTokens.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriesRowSkeleton extends StatelessWidget {
  const _CategoriesRowSkeleton();

  // Varied widths so the loading state hints at a row of pills with
  // different label lengths. Count matches the top-4 cap in `_CategoriesRow`.
  static const _pillWidths = <double>[140, 192, 156, 170];

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _pillWidths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => Center(
          child: Shimmer.fromColors(
            baseColor: pt.imageBg,
            highlightColor: pt.surface,
            child: Container(
              width: _pillWidths[i],
              height: 40,
              decoration: BoxDecoration(
                color: pt.imageBg,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Recommended grid ───────────────────────────

/// Section header for "Siz uchun tavsiya" — title + sort trigger + grid/list
/// toggle. The toggle writes the parent's [ValueNotifier]; the sort trigger
/// opens a bottom sheet that dispatches [HomeSortChanged].
class _RecommendedHeader extends StatelessWidget {
  const _RecommendedHeader({
    required this.viewMode,
    required this.onViewModeChanged,
  });

  final ProductViewMode viewMode;
  final ValueChanged<ProductViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr('home.recommended'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(width: 8),
          const _SortButton(),
          const SizedBox(width: 8),
          ViewModeToggle(viewMode: viewMode, onChanged: onViewModeChanged),
        ],
      ),
    );
  }
}

/// Subtle icon trigger that opens the sort bottom sheet. Shows a spinner in
/// place of the icon while the feed is being re-sorted.
class _SortButton extends StatelessWidget {
  const _SortButton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return BlocSelector<HomeBloc, HomeState, (HomeFeedSort, bool)>(
      selector: (s) => (s.sort, s.feedReloading),
      builder: (context, data) {
        final (sort, reloading) = data;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openSortSheet(context, sort),
          child: Container(
            width: 40,
            height: 38,
            decoration: BoxDecoration(
              color: pt.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pt.dark.withValues(alpha: 0.08)),
            ),
            child: Center(
              child: reloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PremiumTokens.accent,
                      ),
                    )
                  : Icon(Icons.sort_rounded, size: 20, color: pt.dark),
            ),
          ),
        );
      },
    );
  }
}

/// The recommended feed — masonry grid or full-width list depending on
/// [viewMode]. Both layouts share the favourite wiring, the detail-tap, and the
/// near-end load-more trigger; only the card widget + sliver differ.
class _RecommendedFeed extends StatelessWidget {
  const _RecommendedFeed({required this.viewMode});

  final ProductViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (a, b) =>
          a.status != b.status || a.recommended != b.recommended,
      builder: (context, state) {
        final isLoading =
            state.status == HomeStatus.loading ||
            state.status == HomeStatus.initial;
        if (isLoading) {
          return const SliverToBoxAdapter(child: _RecommendedGridSkeleton());
        }
        if (state.recommended.isEmpty) {
          return const SliverToBoxAdapter(child: _RecommendedEmpty());
        }
        return viewMode == ProductViewMode.grid ? _grid(state) : _list(state);
      },
    );
  }

  Widget _grid(HomeState state) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childCount: state.recommended.length,
        itemBuilder: (context, i) {
          _maybeLoadMore(context, state, i);
          final p = state.recommended[i];
          return BlocSelector<FavoritesBloc, FavoritesState, bool>(
            selector: (s) => s.isFavorite(p.id),
            builder: (context, isFav) => PremiumProductCard(
              imageUrl: p.thumbnail ?? '',
              name: p.name,
              subtitle: p.description ?? '',
              price: formatUzsPrice(p.effectivePrice),
              oldPrice: p.hasDiscount ? formatUzsPrice(p.price) : null,
              discountPercent: p.discountPercent,
              isFavorite: isFav,
              hasAr: p.hasAr,
              customImageHeight: i.isEven ? 180.0 : 240.0,
              onTap: () => context.push('/product-detail/${p.id}', extra: p),
              onFavoriteToggle: () => context.read<FavoritesBloc>().add(
                FavoriteToggled(Product.fromModel(p)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _list(HomeState state) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      sliver: SliverList.separated(
        itemCount: state.recommended.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          _maybeLoadMore(context, state, i);
          final p = state.recommended[i];
          return BlocSelector<FavoritesBloc, FavoritesState, bool>(
            selector: (s) => s.isFavorite(p.id),
            builder: (context, isFav) => PremiumProductListCard(
              imageUrl: p.thumbnail ?? '',
              name: p.name,
              subtitle: p.description ?? '',
              price: formatUzsPrice(p.effectivePrice),
              oldPrice: p.hasDiscount ? formatUzsPrice(p.price) : null,
              discountPercent: p.discountPercent,
              isFavorite: isFav,
              hasAr: p.hasAr,
              onTap: () => context.push('/product-detail/${p.id}', extra: p),
              onFavoriteToggle: () => context.read<FavoritesBloc>().add(
                FavoriteToggled(Product.fromModel(p)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Spinner shown under the feed while the next page appends. Collapses to a
/// hairline gap when idle.
class _RecommendedFeedFooter extends StatelessWidget {
  const _RecommendedFeedFooter();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: BlocSelector<HomeBloc, HomeState, bool>(
        selector: (s) => s.loadingMore,
        builder: (context, loadingMore) {
          if (!loadingMore) return const SizedBox(height: 4);
          return const Padding(
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
          );
        },
      ),
    );
  }
}

/// Smart pre-fetch: as the user nears the end of the loaded page (within the
/// last 5 items), enqueue the next page so a spinner rarely appears. The bloc
/// guards `hasMore` / `loadingMore`, and the droppable transformer collapses the
/// repeated triggers a fast scroll fires, so calling this every build is safe.
void _maybeLoadMore(BuildContext context, HomeState state, int index) {
  if (state.hasMore &&
      !state.loadingMore &&
      index >= state.recommended.length - 5) {
    context.read<HomeBloc>().add(const HomeLoadMoreProducts());
  }
}

String _sortLabel(HomeFeedSort sort) => switch (sort) {
  HomeFeedSort.recommended => tr('home.sort_recommended'),
  HomeFeedSort.popular => tr('home.sort_popular'),
  HomeFeedSort.discount => tr('home.sort_discount'),
  HomeFeedSort.newest => tr('home.sort_newest'),
};

Future<void> _openSortSheet(BuildContext context, HomeFeedSort current) async {
  final pt = PremiumTokens.of(context);
  final bloc = context.read<HomeBloc>();
  final selected = await showModalBottomSheet<HomeFeedSort>(
    context: context,
    backgroundColor: pt.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SortSheet(current: current),
  );
  if (selected != null && selected != current) {
    bloc.add(HomeSortChanged(selected));
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final HomeFeedSort current;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: pt.greyLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr('home.sort_title'),
                style: PremiumTokens.display(size: 18, letterSpacing: -0.2),
              ),
            ),
          ),
          for (final option in HomeFeedSort.values)
            _SortOption(
              label: _sortLabel(option),
              selected: option == current,
              onTap: () => Navigator.of(context).pop(option),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: PremiumTokens.body(
                  size: 15,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? PremiumTokens.accent : pt.dark,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: PremiumTokens.accent,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedGridSkeleton extends StatelessWidget {
  const _RecommendedGridSkeleton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: 4,
      itemBuilder: (_, i) => Shimmer.fromColors(
        baseColor: pt.imageBg,
        highlightColor: pt.surface,
        child: Container(
          height: i.isEven ? 265.0 : 325.0,
          decoration: BoxDecoration(
            color: pt.imageBg,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _RecommendedEmpty extends StatelessWidget {
  const _RecommendedEmpty();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: PremiumTokens.softShadow,
        ),
        child: Row(
          children: [
            Icon(Iconsax.box, size: 28, color: pt.greyLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('home.recommended_empty'),
                style: PremiumTokens.body(size: 13, color: pt.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Top Brands (commented out for MVP) ───────────────────
// The widgets and mock data below are kept in cold storage so we can light the
// section back up in a follow-up sprint.
//
// const _mockBrands = <({String name, String logoUrl})>[
//   (
//     name: 'Mebel House',
//     logoUrl:
//         'https://images.unsplash.com/photo-1486312338219-ce68d2c6f44d?w=200&q=80',
//   ),
//   (
//     name: 'Nordic Home',
//     logoUrl:
//         'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80',
//   ),
//   (
//     name: 'Casa Luxe',
//     logoUrl:
//         'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&q=80',
//   ),
//   (
//     name: 'Studio Living',
//     logoUrl:
//         'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&q=80',
//   ),
// ];
//
// class _BrandsRow extends StatelessWidget {
//   const _BrandsRow({required this.brands});
//
//   final List<({String name, String logoUrl})> brands;
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 110,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 20),
//         itemCount: brands.length,
//         separatorBuilder: (_, _) => const SizedBox(width: 18),
//         itemBuilder: (_, i) {
//           final b = brands[i];
//           return _BrandAvatar(name: b.name, logoUrl: b.logoUrl);
//         },
//       ),
//     );
//   }
// }
//
// class _BrandAvatar extends StatelessWidget {
//   const _BrandAvatar({required this.name, required this.logoUrl});
//
//   final String name;
//   final String logoUrl;
//
//   @override
//   Widget build(BuildContext context) {
//     final pt = PremiumTokens.of(context);
//     return SizedBox(
//       width: 76,
//       child: Column(
//         children: [
//           Container(
//             width: 72,
//             height: 72,
//             padding: const EdgeInsets.all(2.5),
//             decoration: const BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [
//                   PremiumTokens.accent,
//                   Color(0xFFE8B79C),
//                   PremiumTokens.accentDeep,
//                 ],
//               ),
//             ),
//             child: Container(
//               padding: const EdgeInsets.all(3),
//               decoration: BoxDecoration(
//                 color: pt.background,
//                 shape: BoxShape.circle,
//               ),
//               child: ClipOval(
//                 child: CachedNetworkImage(
//                   imageUrl: logoUrl,
//                   fit: BoxFit.cover,
//                   placeholder: (_, _) => Shimmer.fromColors(
//                     baseColor: pt.imageBg,
//                     highlightColor: const Color(0xFFFAFAFA),
//                     child: Container(color: Colors.white),
//                   ),
//                   errorWidget: (_, _, _) => Container(
//                     color: pt.imageBg,
//                     child: Icon(Iconsax.shop, color: pt.greyLight),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             name,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: PremiumTokens.body(
//               size: 12,
//               weight: FontWeight.w600,
//               color: pt.dark,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

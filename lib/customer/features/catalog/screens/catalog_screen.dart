import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/repositories/product_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../shared/widgets/product_card_skeleton.dart';
import '../../favorites/bloc/favorites_bloc.dart';
import '../bloc/catalog_bloc.dart';
import '../widgets/filter_sheet.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, this.categorySlug, this.search});

  final String? categorySlug;
  final String? search;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CatalogBloc(
        sl<ProductRepository>(),
        initialFilter: ProductFilter(
          categorySlug: categorySlug,
          search: search,
        ),
      )..add(const CatalogRequested()),
      child: const _CatalogView(),
    );
  }
}

class _CatalogView extends StatefulWidget {
  const _CatalogView();

  @override
  State<_CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<_CatalogView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final remaining = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining < 600) {
      context.read<CatalogBloc>().add(const CatalogNextPageRequested());
    }
  }

  Future<void> _openFilter(BuildContext context) async {
    final bloc = context.read<CatalogBloc>();
    final next = await showCatalogFilterSheet(context, bloc.state.filter);
    if (next != null) bloc.add(CatalogFilterChanged(next));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogBloc, CatalogState>(
      listenWhen: (prev, curr) =>
          curr.error != null && prev.error != curr.error,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error ?? tr('error.unknown'))),
        );
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.filter.search != null
                  ? '${tr('search.results')}: "${state.filter.search}"'
                  : tr('catalog.title'),
            ),
            actions: [
              IconButton(
                tooltip: tr('catalog.search'),
                icon: const Icon(Icons.search),
                onPressed: () => context.push('/search'),
              ),
              IconButton(
                tooltip: tr('catalog.filter'),
                icon: const Icon(Icons.tune),
                onPressed: () => _openFilter(context),
              ),
            ],
          ),
          body: switch (state.status) {
            CatalogStatus.initial ||
            CatalogStatus.loading =>
              const _CatalogSkeleton(),
            CatalogStatus.failure => ErrorState(
                message: state.error,
                onRetry: () =>
                    context.read<CatalogBloc>().add(const CatalogRequested()),
              ),
            CatalogStatus.ready ||
            CatalogStatus.loadingMore =>
              state.products.isEmpty
                  ? EmptyState(
                      title: tr('catalog.empty'),
                      message: tr('catalog.empty_hint'),
                      icon: Icons.search_off,
                    )
                  : _CatalogGrid(
                      controller: _scrollController,
                      state: state,
                    ),
          },
        );
      },
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.controller, required this.state});

  final ScrollController controller;
  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    return BrandRefreshIndicator(
      onRefresh: () async {
        context.read<CatalogBloc>().add(const CatalogRequested());
      },
      child: GridView.builder(
        controller: controller,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.62,
        ),
        itemCount: state.products.length +
            (state.status == CatalogStatus.loadingMore ? 2 : 0),
        itemBuilder: (context, i) {
          if (i >= state.products.length) {
            return const ProductCardSkeleton();
          }
          final p = state.products[i];
          return BlocSelector<FavoritesBloc, FavoritesState, bool>(
            selector: (s) => s.isFavorite(p.id),
            builder: (context, isFav) {
              return ProductCard(
                product: p.copyWith(isFavorite: isFav),
                onTap: () => context.push('/products/${p.slug}'),
                onFavoriteToggle: () =>
                    context.read<FavoritesBloc>().add(FavoriteToggled(p)),
              );
            },
          );
        },
      ),
    );
  }
}

class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const ProductCardSkeleton(),
    );
  }
}

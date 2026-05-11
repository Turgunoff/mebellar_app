import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/supabase_product_data_source.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../favorites/bloc/favorites_bloc.dart';
import '../../home/widgets/premium/premium_product_card.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../bloc/search_bloc.dart';

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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: pt.dark),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: pt.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: PremiumTokens.softShadow,
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Iconsax.search_normal_1, color: pt.grey, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  cursorColor: PremiumTokens.accent,
                  style: PremiumTokens.body(size: 14, color: pt.dark),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: tr('search.hint'),
                    hintStyle:
                        PremiumTokens.body(size: 14, color: pt.grey),
                  ),
                  onChanged: (v) {
                    context.read<SearchBloc>().add(SearchQueryChanged(v));
                    setState(() {});
                  },
                  onSubmitted: (v) =>
                      context.read<SearchBloc>().add(SearchSubmitted(v)),
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                IconButton(
                  splashRadius: 18,
                  icon: Icon(Iconsax.close_circle, color: pt.grey, size: 18),
                  onPressed: () {
                    _ctrl.clear();
                    context
                        .read<SearchBloc>()
                        .add(const SearchQueryChanged(''));
                    setState(() {});
                  },
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          if (state.query.isEmpty) {
            return _RecentList(
              recent: state.recent,
              onTap: (term) {
                _ctrl.text = term;
                _ctrl.selection = TextSelection.collapsed(offset: term.length);
                context.read<SearchBloc>().add(SearchQueryChanged(term));
                setState(() {});
              },
              onClear: () =>
                  context.read<SearchBloc>().add(const SearchHistoryCleared()),
            );
          }
          return switch (state.status) {
            SearchStatus.idle ||
            SearchStatus.loading => const _SearchSkeleton(),
            SearchStatus.failure => ErrorState(
              message: state.error,
              onRetry: () => context
                  .read<SearchBloc>()
                  .add(SearchQueryChanged(state.query)),
            ),
            SearchStatus.ready => state.results.isEmpty
                ? EmptyState(
                    icon: Iconsax.search_status,
                    title: tr('search.no_results'),
                    message: tr('search.no_results_hint'),
                  )
                : _ResultsGrid(
                    results: state.results,
                    onItemTap: (p) {
                      context
                          .read<SearchBloc>()
                          .add(SearchSubmitted(state.query));
                      context.push('/product-detail/${p.id}', extra: p);
                    },
                  ),
          };
        },
      ),
    );
  }
}

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
    price: m.price,
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
            price: _formatPrice(p.price),
            isFavorite: isFav,
            onTap: () => onItemTap(p),
            onFavoriteToggle: () => context
                .read<FavoritesBloc>()
                .add(FavoriteToggled(_toProduct(p))),
          ),
        );
      },
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
    if (recent.isEmpty) {
      return EmptyState(
        icon: Iconsax.search_normal_1,
        title: tr('search.no_recent'),
        message: tr('search.hint'),
      );
    }
    final pt = PremiumTokens.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            children: [
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
        ...recent.map(
          (term) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: pt.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: PremiumTokens.softShadow,
            ),
            child: ListTile(
              leading: Icon(Iconsax.clock, color: pt.grey, size: 20),
              title: Text(
                term,
                style: PremiumTokens.body(
                  size: 14,
                  weight: FontWeight.w500,
                  color: pt.dark,
                ),
              ),
              trailing: Icon(Iconsax.arrow_up_3, color: pt.greyLight, size: 18),
              onTap: () => onTap(term),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
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

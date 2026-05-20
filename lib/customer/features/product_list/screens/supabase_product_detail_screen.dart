import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/supabase_product_data_source.dart';
import '../../../features/cart/bloc/cart_bloc.dart';
import '../../../features/favorites/bloc/favorites_bloc.dart';
import '../../home/widgets/premium/premium_product_card.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../../product_detail/widgets/product_image_gallery.dart';

class SupabaseProductDetailScreen extends StatelessWidget {
  const SupabaseProductDetailScreen({super.key, required this.product});

  final SupabaseProductModel product;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);

    return Scaffold(
      backgroundColor: pt.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 420.0,
                stretch: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                foregroundColor: pt.dark,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: _GlassIconButton(
                  onTap: () => context.pop(),
                  icon: Icons.arrow_back_ios_new_rounded,
                  pt: pt,
                ),
                actions: [
                  _GlassIconButton(
                    onTap: () {},
                    icon: Iconsax.share,
                    pt: pt,
                  ),
                  const SizedBox(width: 8),
                ],
                title: Text(
                  product.name,
                  style: PremiumTokens.body(
                    size: 15,
                    weight: FontWeight.w600,
                    color: pt.dark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: product.images.isNotEmpty
                      ? ProductImageGallery(
                          images: product.images,
                          heroTag: 'product-${product.id}',
                        )
                      : Container(
                          color: pt.imageBg,
                          alignment: Alignment.center,
                          child: Icon(
                            Iconsax.gallery,
                            size: 48,
                            color: pt.greyLight,
                          ),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PriceRow(product: product),
                      const SizedBox(height: 10),
                      Text(
                        product.name,
                        style: PremiumTokens.display(
                            size: 26, letterSpacing: -0.4),
                      ),
                      if (product.description != null) ...[
                        const SizedBox(height: 24),
                        Divider(color: pt.divider, height: 1),
                        const SizedBox(height: 20),
                        Text(
                          tr('product.description'),
                          style: PremiumTokens.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: pt.dark,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          product.description!,
                          style: PremiumTokens.body(
                            size: 14,
                            color: pt.grey,
                            height: 1.65,
                          ),
                        ),
                      ],
                      if (product.attributes != null &&
                          product.attributes!.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Divider(color: pt.divider, height: 1),
                        const SizedBox(height: 20),
                        Text(
                          tr('product.attributes'),
                          style: PremiumTokens.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: pt.dark,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _AttributesTable(
                            attributes: product.attributes!, pt: pt),
                      ],
                      const SizedBox(height: 20),
                      _StockIndicator(product: product),
                      const SizedBox(height: 32),
                      Divider(color: pt.divider, height: 1),
                      const SizedBox(height: 24),
                      Text(
                        tr('product.you_might_like'),
                        style: PremiumTokens.display(
                            size: 22, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _SimilarProductsSliver(
                categoryId: product.categoryId,
                excludeId: product.id,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(product: product),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Similar products sliver
// ---------------------------------------------------------------------------

class _SimilarProductsSliver extends StatefulWidget {
  const _SimilarProductsSliver({
    required this.categoryId,
    required this.excludeId,
  });

  final String categoryId;
  final String excludeId;

  @override
  State<_SimilarProductsSliver> createState() => _SimilarProductsSliverState();
}

class _SimilarProductsSliverState extends State<_SimilarProductsSliver> {
  late final Future<List<SupabaseProductModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<SupabaseProductDataSource>()
        .listByCategory(categoryId: widget.categoryId)
        .then(
          (list) => list
              .where((p) => p.id != widget.excludeId)
              .take(10)
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SliverToBoxAdapter(
      child: FutureBuilder<List<SupabaseProductModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _SimilarSkeleton(pt: pt);
          }
          final products = snap.data ?? [];
          if (products.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MasonryGridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              itemBuilder: (ctx, i) {
                final p = products[i];
                return BlocSelector<FavoritesBloc, FavoritesState, bool>(
                  selector: (state) => state.isFavorite(p.id),
                  builder: (ctx, isFav) => PremiumProductCard(
                    imageUrl: p.thumbnail ?? '',
                    name: p.name,
                    shop: '',
                    price:
                        '${NumberFormat('#,##0', 'en_US').format(p.price)} UZS',
                    isFavorite: isFav,
                    customImageHeight: i.isEven ? 180.0 : 240.0,
                    onTap: () =>
                        context.push('/product-detail/${p.id}', extra: p),
                    onFavoriteToggle: () =>
                        context.read<FavoritesBloc>().add(
                              FavoriteToggled(_toProduct(p)),
                            ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SimilarSkeleton extends StatelessWidget {
  const _SimilarSkeleton({required this.pt});

  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (_, i) => Shimmer.fromColors(
          baseColor: pt.imageBg,
          highlightColor: pt.surface,
          child: Container(
            height: i.isEven ? 240.0 : 300.0,
            decoration: BoxDecoration(
              color: pt.imageBg,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Price row
// ---------------------------------------------------------------------------

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});

  final SupabaseProductModel product;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${NumberFormat('#,##0', 'en_US').format(product.price)} UZS',
      style: PremiumTokens.display(
        size: 28,
        color: PremiumTokens.accent,
        letterSpacing: -0.5,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attributes table
// ---------------------------------------------------------------------------

class _AttributesTable extends StatelessWidget {
  const _AttributesTable({required this.attributes, required this.pt});

  final Map<String, dynamic> attributes;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final entries = attributes.entries.toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++)
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Text(
                        entries[i].key,
                        style: PremiumTokens.body(size: 13, color: pt.grey),
                      ),
                      const Spacer(),
                      Text(
                        entries[i].value.toString(),
                        style: PremiumTokens.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: pt.dark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < entries.length - 1)
                  Divider(height: 1, color: pt.divider),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock indicator
// ---------------------------------------------------------------------------

class _StockIndicator extends StatelessWidget {
  const _StockIndicator({required this.product});

  final SupabaseProductModel product;

  @override
  Widget build(BuildContext context) {
    // Mebellar is made-to-order — there's no warehouse count to surface.
    const color = Color(0xFF4CAF50);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          tr('product.made_to_order'),
          style: PremiumTokens.body(size: 12, color: color),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.product});

  final SupabaseProductModel product;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: BoxDecoration(
        color: pt.surface,
        border: Border(top: BorderSide(color: pt.divider)),
      ),
      child: Row(
        children: [
          BlocSelector<FavoritesBloc, FavoritesState, bool>(
            selector: (state) => state.isFavorite(product.id),
            builder: (context, isFav) {
              return GestureDetector(
                onTap: () => context.read<FavoritesBloc>().add(
                      FavoriteToggled(_toProduct(product)),
                    ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isFav
                        ? PremiumTokens.accent.withValues(alpha: 0.12)
                        : pt.imageBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFav
                          ? PremiumTokens.accent.withValues(alpha: 0.4)
                          : pt.divider,
                    ),
                  ),
                  child: Icon(
                    isFav ? Iconsax.heart_copy : Iconsax.heart,
                    size: 22,
                    color: isFav ? PremiumTokens.accent : pt.grey,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => _addToCart(context, product),
              style: FilledButton.styleFrom(
                backgroundColor: PremiumTokens.accent,
                disabledBackgroundColor: pt.imageBg,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Iconsax.shopping_bag,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('cart.add'),
                    style: PremiumTokens.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass icon button for app bar
// ---------------------------------------------------------------------------

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.onTap,
    required this.icon,
    required this.pt,
  });

  final VoidCallback onTap;
  final IconData icon;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, size: 18, color: pt.dark),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Product _toProduct(SupabaseProductModel m) => Product(
      id: m.id,
      slug: m.id,
      name: MultilingualText(uz: m.name, ru: m.name, en: m.name),
      price: m.price,
      images: m.images,
      attributes: m.attributes,
      stock: m.stock,
    );

void _addToCart(BuildContext context, SupabaseProductModel product) {
  context.read<CartBloc>().add(AddToCart(product));
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(tr('cart.item_added')),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

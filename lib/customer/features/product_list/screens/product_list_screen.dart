import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../features/favorites/bloc/favorites_bloc.dart';
import '../../../widgets/glass_bottom_nav.dart';
import '../../home/widgets/premium/premium_tokens.dart';
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

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);

    return ColoredBox(
      color: pt.background,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<ProductListCubit, ProductListState>(
          builder: (context, state) {
            if (state.status == ProductListStatus.failure) {
              return _ErrorView(
                message: state.error ?? '',
                onRetry: () => context
                    .read<ProductListCubit>()
                    .load(categoryId: categoryId, subcategoryId: subcategoryId),
              );
            }

            final isLoading = state.status == ProductListStatus.initial ||
                state.status == ProductListStatus.loading;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _AppBar(title: categoryName),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App bar
// ---------------------------------------------------------------------------

class _AppBar extends StatelessWidget {
  const _AppBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SliverAppBar(
      backgroundColor: pt.background,
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
                      _formatPrice(product.price),
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
      price: m.price,
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

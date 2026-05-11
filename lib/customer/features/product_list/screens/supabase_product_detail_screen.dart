import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../features/cart/bloc/cart_bloc.dart';
import '../../../features/favorites/bloc/favorites_bloc.dart';
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 380,
              child: product.images.isNotEmpty
                  ? ProductImageGallery(
                      images: product.images,
                      heroTag: 'product-${product.id}',
                    )
                  : Container(
                      color: pt.imageBg,
                      alignment: Alignment.center,
                      child: Icon(Iconsax.gallery, size: 48, color: pt.greyLight),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _PriceRow(product: product),
                const SizedBox(height: 10),
                Text(
                  product.name,
                  style: PremiumTokens.display(size: 26, letterSpacing: -0.4),
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
                  _AttributesTable(attributes: product.attributes!, pt: pt),
                ],
                const SizedBox(height: 20),
                _StockIndicator(product: product),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(product: product),
    );
  }
}

// ---------------------------------------------------------------------------
// Price row
// ---------------------------------------------------------------------------

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});

  final SupabaseProductModel product;

  static String _fmt(double price) {
    return '${NumberFormat('#,##0', 'en_US').format(price)} UZS';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _fmt(product.price),
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
                if (i < entries.length - 1) Divider(height: 1, color: pt.divider),
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
    final color =
        product.inStock ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final label = product.inStock
        ? tr('product.in_stock').replaceAll('{}', '${product.stock}')
        : tr('product.out_of_stock');
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
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
              onPressed: product.inStock
                  ? () => _addToCart(context, product)
                  : null,
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
                  Icon(
                    Iconsax.shopping_bag,
                    size: 18,
                    color: product.inStock ? Colors.white : pt.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    product.inStock
                        ? tr('cart.add')
                        : tr('product.out_of_stock'),
                    style: PremiumTokens.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: product.inStock ? Colors.white : pt.grey,
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, size: 18, color: pt.dark),
            ),
          ),
        ),
      ),
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

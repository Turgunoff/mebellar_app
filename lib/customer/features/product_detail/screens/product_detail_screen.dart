import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
// SystemUiOverlayStyle / SystemUiOverlayStyle.dark live in services.dart;
// material re-exports the type elsewhere but not as a usable type-argument
// here, so the explicit import is required.
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/product_repository.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/quantity_stepper.dart';
import '../../../../shared/widgets/shop_card.dart';
import '../../../../shared/widgets/shop_services_block.dart';
import '../../cart/bloc/cart_bloc.dart';
import '../../favorites/bloc/favorites_bloc.dart';
import '../bloc/product_detail_bloc.dart';
import '../widgets/attributes_block.dart';
import '../widgets/expandable_description.dart';
import '../widgets/product_image_gallery.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductDetailBloc(sl<ProductRepository>())
        ..add(ProductDetailRequested(slug)),
      child: _ProductDetailView(slug: slug),
    );
  }
}

class _ProductDetailView extends StatefulWidget {
  const _ProductDetailView({required this.slug});
  final String slug;

  @override
  State<_ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<_ProductDetailView> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductDetailBloc, ProductDetailState>(
      listenWhen: (prev, next) => prev.product?.id != next.product?.id,
      listener: (context, state) {
        // Sync the favorite flag from FavoritesBloc as soon as the product
        // arrives вЂ” server may not include the user's favorite state yet.
        final p = state.product;
        if (p == null) return;
        final favs = context.read<FavoritesBloc>().state.ids;
        if (favs.contains(p.id) != p.isFavorite) {
          context.read<ProductDetailBloc>().add(
                ProductDetailFavoriteSyncRequested(
                  isFavorite: favs.contains(p.id),
                ),
              );
        }
      },
      builder: (context, state) {
        if (state.status == ProductDetailStatus.loading ||
            state.status == ProductDetailStatus.initial) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == ProductDetailStatus.failure ||
            state.product == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorState(
              message: state.error,
              onRetry: () => context
                  .read<ProductDetailBloc>()
                  .add(ProductDetailRequested(widget.slug)),
            ),
          );
        }
        return _DetailBody(
          product: state.product!,
          quantity: _qty,
          onQuantityChanged: (q) => setState(() => _qty = q),
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  void _addToCart(BuildContext context, {bool buyNow = false}) {
    context.read<CartBloc>().add(
          AddToCart(_toSupabaseModel(product), quantity: quantity),
        );
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr('cart.item_added')),
        action: buyNow
            ? null
            : SnackBarAction(
                label: tr('cart.title'),
                onPressed: () => context.go('/cart'),
              ),
        duration: const Duration(seconds: 2),
      ),
    );
    if (buyNow) {
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (context.mounted) context.go('/cart');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final priceFormat = NumberFormat('#,###', lang);
    final outOfStock = !product.inStock;
    final productName = product.name.get(lang);
    // Light backgrounds need dark status-bar glyphs; otherwise the time and
    // battery icons render white-on-white and disappear. Scoped via
    // AnnotatedRegion so it applies only while this route is on top.
    final overlayStyle = SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );
    const expandedHeight = 400.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: expandedHeight,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: overlayStyle,
            iconTheme: IconThemeData(color: scheme.onSurface),
            actions: [
              BlocBuilder<FavoritesBloc, FavoritesState>(
                buildWhen: (a, b) =>
                    a.isFavorite(product.id) != b.isFavorite(product.id),
                builder: (context, favState) {
                  final isFav = favState.isFavorite(product.id);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? scheme.error : null,
                    ),
                    onPressed: () => context
                        .read<FavoritesBloc>()
                        .add(FavoriteToggled(product)),
                  );
                },
              ),
            ],
            // The collapsed-state title is computed in a LayoutBuilder so it
            // fades in only as the bar approaches its toolbar size — keeping
            // the expanded gallery free of overlaid text.
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final topPadding = MediaQuery.of(context).padding.top;
                final collapsedHeight = kToolbarHeight + topPadding;
                final current = constraints.biggest.height;
                final t = ((expandedHeight - current) /
                        (expandedHeight - collapsedHeight))
                    .clamp(0.0, 1.0);
                return FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 56,
                    bottom: 16,
                    end: 56,
                  ),
                  title: Opacity(
                    opacity: t,
                    child: Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  background: ProductImageGallery(
                    images: product.images,
                    heroTag: 'product-${product.id}',
                    fillParent: true,
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    product.name.get(lang),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  // Price + old price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${priceFormat.format(product.price)} so\'m',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      if (product.isOnSale) ...[
                        const SizedBox(width: 10),
                        Text(
                          '${priceFormat.format(product.oldPrice)} so\'m',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: scheme.outline,
                                  ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${(((product.oldPrice! - product.price) / product.oldPrice!) * 100).round()}%',
                            style: TextStyle(
                              color: scheme.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        outOfStock
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline,
                        size: 18,
                        color: outOfStock ? scheme.error : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        outOfStock
                            ? tr('product.out_of_stock')
                            : tr('product.in_stock', args: ['${product.stock}']),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: outOfStock ? scheme.error : Colors.green,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Shop card
                  if (product.shop != null)
                    ShopCard(
                      shop: product.shop!,
                      onTap: () =>
                          context.push('/shops/${product.shop!.slug}'),
                    ),
                  const SizedBox(height: 20),
                  // Shop services
                  if (product.shopServices.isNotEmpty) ...[
                    ShopServicesBlock(services: product.shopServices),
                    const SizedBox(height: 20),
                  ],
                  // Description
                  if (product.description != null &&
                      product.description!.get(lang).isNotEmpty) ...[
                    Text(
                      tr('product.description'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ExpandableDescription(
                      text: product.description!.get(lang),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Attributes
                  if (product.attributes != null &&
                      product.attributes!.isNotEmpty)
                    AttributesBlock(attributes: product.attributes!),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        tr('product.quantity'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      QuantityStepper(
                        value: quantity,
                        onChanged: onQuantityChanged,
                        max: product.stock <= 0 ? 99 : product.stock,
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: outOfStock ? null : () => _addToCart(context),
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(tr('cart.add')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      outOfStock ? null : () => _addToCart(context, buyNow: true),
                  icon: const Icon(Icons.flash_on_outlined),
                  label: Text(tr('product.buy_now')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Bridge the legacy [Product] graph (multilingual, with shop) into the
/// snapshot-friendly [SupabaseProductModel] used by the new cart pipeline.
/// Multilingual fields collapse to the Uzbek string since the snapshot is
/// only used for cart-row display.
SupabaseProductModel _toSupabaseModel(Product p) {
  return SupabaseProductModel(
    id: p.id,
    categoryId: p.categorySlug ?? '',
    shopId: p.shop?.id,
    name: p.name.get('uz'),
    description: p.description?.get('uz'),
    price: p.price.toDouble(),
    images: p.images.isNotEmpty
        ? p.images
        : (p.primaryImage != null ? [p.primaryImage!] : const []),
    attributes: p.attributes,
    stock: p.stock,
    createdAt: DateTime.now(),
  );
}

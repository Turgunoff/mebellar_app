part of 'catalog_product_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Similar products
// ═══════════════════════════════════════════════════════════════════════════

class _SimilarSection extends StatefulWidget {
  const _SimilarSection({required this.productId});

  final String productId;

  @override
  State<_SimilarSection> createState() => _SimilarSectionState();
}

class _SimilarSectionState extends State<_SimilarSection> {
  late final Future<List<ProductModel>> _future;
  // Synchronous cache peek so a re-visit paints the carousel at 0 ms;
  // `_future` still runs to refresh stock/price for the rail.
  late final List<ProductModel>? _cached;

  @override
  void initState() {
    super.initState();
    final source = sl<ProductDataSource>();
    _cached = source.peekSimilar(widget.productId);
    // Server-ranked recommendations — see `get_similar_products`.
    _future = source.listSimilar(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return FutureBuilder<List<ProductModel>>(
      future: _future,
      initialData: _cached,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done && snap.data == null) {
          return Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sizga yoqishi mumkin',
                  style: _ts(
                    size: 16,
                    weight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: pt.dark,
                  ),
                ),
                const SizedBox(height: 16),
                const _SimilarSkeleton(),
              ],
            ),
          );
        }
        final products = snap.data ?? const [];
        if (products.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sizga yoqishi mumkin',
                style: _ts(
                  size: 16,
                  weight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: pt.dark,
                ),
              ),
              const SizedBox(height: 16),
              // Horizontal carousel — `clipBehavior: none` keeps each card's
              // soft shadow from being clipped at the rail's top/bottom edge.
              SizedBox(
                height: _kSimilarCardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  physics: const BouncingScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (ctx, i) {
                    final p = products[i];
                    return SizedBox(
                      width: _kSimilarCardWidth,
                      child: BlocSelector<FavoritesBloc, FavoritesState, bool>(
                        selector: (state) => state.isFavorite(p.id),
                        builder: (ctx, isFav) => PremiumProductCard(
                          imageUrl: p.thumbnail ?? '',
                          name: p.name,
                          shop: '',
                          price: '${_money(p.effectivePrice)} UZS',
                          discountPercent: p.discountPercent,
                          isFavorite: isFav,
                          customImageHeight: _kSimilarImageHeight,
                          onTap: () =>
                              context.push('/product-detail/${p.id}', extra: p),
                          onFavoriteToggle: () => context
                              .read<FavoritesBloc>()
                              .add(FavoriteToggled(Product.fromModel(p))),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Carousel card geometry — shared by the loaded rail and its skeleton so
// both reserve exactly the same height.
const double _kSimilarCardWidth = 160;
const double _kSimilarImageHeight = 150;
const double _kSimilarCardHeight = 240;

class _SimilarSkeleton extends StatelessWidget {
  const _SimilarSkeleton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SizedBox(
      height: _kSimilarCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => Shimmer.fromColors(
          baseColor: pt.imageBg,
          highlightColor: Colors.white,
          child: Container(
            width: _kSimilarCardWidth,
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

// ═══════════════════════════════════════════════════════════════════════════
// Bottom action bar — smart add-to-cart CTA
// ═══════════════════════════════════════════════════════════════════════════

/// Cart-aware bottom bar. While the product is not in the cart it shows the
/// primary "add" CTA; once a line exists it morphs into a quantity stepper +
/// "go to cart" pair so repeat adds never leave the screen. The favourite
/// toggle lives in the app bar, not here.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.product, required this.onAddToCart});

  final ProductModel product;
  final VoidCallback onAddToCart;

  int _quantityOf(CartState state) {
    for (final item in state.items) {
      if (item.productId == product.id) return item.quantity;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      decoration: BoxDecoration(
        color: pt.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: BlocBuilder<CartBloc, CartState>(
        buildWhen: (prev, curr) => _quantityOf(prev) != _quantityOf(curr),
        builder: (context, state) {
          final quantity = _quantityOf(state);
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: quantity == 0
                ? _AddToCartCta(
                    key: const ValueKey('cta-add'),
                    onPressed: onAddToCart,
                  )
                : _InCartControls(
                    key: const ValueKey('cta-in-cart'),
                    productId: product.id,
                    quantity: quantity,
                  ),
          );
        },
      ),
    );
  }
}

class _AddToCartCta extends StatelessWidget {
  const _AddToCartCta({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.terracotta,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.shopping_bag, size: 19, color: Colors.white),
          const SizedBox(width: 9),
          Text(
            tr('cart.add'),
            style: _ts(size: 15, weight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Post-add state: `[− qty +]` stepper + "go to cart". Decrementing at
/// quantity 1 removes the line (the bloc maps `newQuantity ≤ 0` to a
/// remove), which animates the bar back to the add CTA.
class _InCartControls extends StatelessWidget {
  const _InCartControls({
    super.key,
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final int quantity;

  void _setQuantity(BuildContext context, int next) {
    context.read<CartBloc>().add(
      UpdateQuantity(productId: productId, newQuantity: next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Row(
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: pt.imageBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: pt.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyButton(
                icon: quantity == 1 ? Iconsax.trash : Iconsax.minus,
                onTap: () => _setQuantity(context, quantity - 1),
              ),
              SizedBox(
                width: 34,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '$quantity',
                    key: ValueKey(quantity),
                    textAlign: TextAlign.center,
                    style: _ts(
                      size: 16,
                      weight: FontWeight.w800,
                      color: pt.dark,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              _QtyButton(
                icon: Iconsax.add,
                onTap: quantity >= 99
                    ? null
                    : () => _setQuantity(context, quantity + 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            // Tab deep-link, not push — see _handleAddToCart's toast action.
            onPressed: () => context.go('/?tab=cart'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              minimumSize: const Size.fromHeight(54),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.bag_tick, size: 19, color: Colors.white),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    tr('cart.go_to_cart'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final disabled = onTap == null;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 54,
        child: Icon(icon, size: 18, color: disabled ? pt.greyLight : pt.dark),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

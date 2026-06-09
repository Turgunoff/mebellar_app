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
    return SizedBox(
      height: _kSimilarCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => Shimmer.fromColors(
          baseColor: kImageBg,
          highlightColor: Colors.white,
          child: Container(
            width: _kSimilarCardWidth,
            decoration: BoxDecoration(
              color: kImageBg,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom action bar — customer (favourite + add to cart)
// ═══════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.product, required this.onAddToCart});

  final ProductModel product;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          BlocSelector<FavoritesBloc, FavoritesState, bool>(
            selector: (state) => state.isFavorite(product.id),
            builder: (context, isFav) {
              return GestureDetector(
                onTap: () => context.read<FavoritesBloc>().add(
                  FavoriteToggled(Product.fromModel(product)),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isFav
                        ? AppColors.terracotta.withValues(alpha: 0.12)
                        : kImageBg,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isFav
                          ? AppColors.terracotta.withValues(alpha: 0.4)
                          : kOutline,
                    ),
                  ),
                  child: Icon(
                    isFav ? Iconsax.heart_copy : Iconsax.heart,
                    size: 23,
                    color: isFav ? AppColors.terracotta : kGrey,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onAddToCart,
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
                  const Icon(
                    Iconsax.shopping_bag,
                    size: 19,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    tr('cart.add'),
                    style: _ts(
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

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════


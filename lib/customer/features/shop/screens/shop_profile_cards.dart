part of 'shop_profile_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Product card — reuses the home/favorites PremiumProductCard, favorites-wired
// ═══════════════════════════════════════════════════════════════════════════

class _ShopProductCard extends StatelessWidget {
  const _ShopProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FavoritesBloc, FavoritesState, bool>(
      selector: (state) => state.isFavorite(product.id),
      builder: (context, isFav) => PremiumProductCard(
        imageUrl: product.thumbnail ?? '',
        name: product.name,
        shop: '',
        price: '${_money(product.effectivePrice)} UZS',
        discountPercent: product.discountPercent,
        isFavorite: isFav,
        onTap: () =>
            context.push('/product-detail/${product.id}', extra: product),
        onFavoriteToggle: () => context.read<FavoritesBloc>().add(
          FavoriteToggled(Product.fromModel(product)),
        ),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Iconsax.box, size: 34, color: pt.greyLight),
              const SizedBox(height: 10),
              Text(
                'Hozircha mahsulot yo\'q',
                style: _ts(size: 13.5, weight: FontWeight.w600, color: pt.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Loading / error / back button
// ═══════════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Shimmer.fromColors(
          baseColor: pt.imageBg,
          highlightColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 168 + topPad, color: pt.imageBg),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 180,
                      height: 22,
                      decoration: BoxDecoration(
                        color: pt.imageBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 120,
                      height: 13,
                      decoration: BoxDecoration(
                        color: pt.imageBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      height: 84,
                      decoration: BoxDecoration(
                        color: pt.imageBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

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
            Icon(Iconsax.shop, size: 46, color: pt.greyLight),
            const SizedBox(height: 16),
            Text(
              'Do\'kon ma\'lumotlarini yuklab bo\'lmadi',
              textAlign: TextAlign.center,
              style: _ts(size: 15, weight: FontWeight.w700, color: pt.dark),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                'Qayta urinish',
                style: _ts(
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned top bar over the scrolling content. Transparent (back button only)
/// while the header is expanded, fading to a white bar with the shop-name
/// title as [collapse] goes 0 → 1.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.name, required this.collapse});

  final String name;
  final double collapse;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final c = collapse.clamp(0.0, 1.0);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: topPad + 60,
        child: Stack(
          children: [
            // Background + title — non-interactive so scroll gestures starting
            // on the bar still reach the list underneath.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: c),
                    boxShadow: c > 0.3
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05 * c),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  padding: EdgeInsets.only(top: topPad, left: 64, right: 16),
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: c,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(
                        size: 16.5,
                        weight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: PremiumTokens.of(context).dark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: topPad + 12, left: 12, child: const _BackCircle()),
          ],
        ),
      ),
    );
  }
}

/// Static back button for the non-scrolling loading / error states.
class _FloatingBackButton extends StatelessWidget {
  const _FloatingBackButton();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Positioned(top: topPad + 10, left: 12, child: const _BackCircle());
  }
}

/// White circular back affordance — pops the route (or falls back to home when
/// there is no back stack, e.g. a cold deep-link).
class _BackCircle extends StatelessWidget {
  const _BackCircle();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.canPop() ? context.pop() : context.go('/'),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Iconsax.arrow_left_2,
            size: 20,
            color: PremiumTokens.of(context).dark,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

/// Parses a `#RRGGBB` brand colour, falling back to the customer terracotta
/// when null/blank/unparseable so the header always has a sane accent.
Color _brandColor(String? hex) {
  final raw = (hex ?? '').trim().replaceFirst('#', '');
  if (raw.length == 6) {
    final value = int.tryParse(raw, radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  return AppColors.terracotta;
}

/// True when [now] falls inside the shop's window for the current weekday.
/// Handles overnight windows (close ≤ open, e.g. 20:00–02:00).
bool _isOpenNow(WeeklyHours hours, DateTime now) {
  final today = DayOfWeek.values[now.weekday - 1];
  final d = hours[today];
  if (d.closed || d.open == null || d.close == null) return false;
  if (d.isOpen24h) return true;
  final open = _minutes(d.open!);
  final close = _minutes(d.close!);
  if (open == null || close == null) return false;
  final mins = now.hour * 60 + now.minute;
  if (close <= open) return mins >= open || mins < close;
  return mins >= open && mins < close;
}

int? _minutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// Bridges [ProductModel] → [Product] so the favourites bloc (which speaks the
/// richer [Product] type) can toggle a card from this screen. Mirrors the
/// helper on the product detail page.

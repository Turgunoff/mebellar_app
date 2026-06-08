import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/shop_profile.dart';
import '../../../../shared/models/working_hours.dart';
import '../../../../shared/repositories/shop_repository.dart';
// Reuse the seller product-preview kit so this screen is a pixel-consistent
// continuation of the product detail page it's opened from (same SectionCard,
// tokens, and Uzbek-only copy — see catalog_product_detail_screen.dart).
import '../../../../seller/features/products/widgets/product_preview/product_preview_kit.dart';
import '../../home/widgets/premium/premium_product_card.dart';
import '../../favorites/bloc/favorites_bloc.dart';
import '../cubit/shop_profile_cubit.dart';

/// Telegram brand blue — used for the Telegram quick-contact button.
const Color _kTelegram = Color(0xFF229ED9);
const Color _kVerified = Color(0xFF1F6B49);

TextStyle _ts({
  required double size,
  FontWeight weight = FontWeight.w500,
  Color color = kInk,
  double height = 1.3,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: AppFonts.seller,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

String _money(num value) => NumberFormat('#,###', 'uz').format(value);

/// Public seller/shop profile, pushed at `/shop/:id` from the product detail
/// page's seller card.
class ShopProfileScreen extends StatelessWidget {
  const ShopProfileScreen({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShopProfileCubit(sl<ShopRepository>())..load(shopId),
      child: _ShopProfileView(shopId: shopId),
    );
  }
}

class _ShopProfileView extends StatelessWidget {
  const _ShopProfileView({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: BlocBuilder<ShopProfileCubit, ShopProfileState>(
        builder: (context, state) {
          // The ready screen owns its own scroll-aware top bar (so the shop
          // name can pin on scroll); loading/error just need a static back
          // button over a non-scrolling body.
          return switch (state.status) {
            ShopProfileStatus.ready => _ReadyContent(
              shop: state.shop!,
              products: state.products,
            ),
            ShopProfileStatus.loading => const Stack(
              children: [
                Positioned.fill(child: _LoadingState()),
                _FloatingBackButton(),
              ],
            ),
            ShopProfileStatus.error => Stack(
              children: [
                Positioned.fill(
                  child: _ErrorState(
                    onRetry: () =>
                        context.read<ShopProfileCubit>().load(shopId),
                  ),
                ),
                const _FloatingBackButton(),
              ],
            ),
          };
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Ready content
// ═══════════════════════════════════════════════════════════════════════════

class _ReadyContent extends StatefulWidget {
  const _ReadyContent({required this.shop, required this.products});

  final ShopProfile shop;
  final List<ProductModel> products;

  @override
  State<_ReadyContent> createState() => _ReadyContentState();
}

class _ReadyContentState extends State<_ReadyContent> {
  final ScrollController _scrollController = ScrollController();

  /// 0 → header fully expanded (transparent bar); 1 → collapsed (white bar +
  /// shop-name title). Driven by the scroll offset against the cover height.
  double _collapse = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    // Fade the bar in over the last stretch of the cover collapse, so the
    // title lands just as the in-header name scrolls under the bar.
    const fadeEnd = _ShopHeader._coverH + 8;
    const fadeStart = fadeEnd - 70;
    final offset = _scrollController.offset;
    final double next;
    if (offset <= fadeStart) {
      next = 0;
    } else if (offset >= fadeEnd) {
      next = 1;
    } else {
      next = (offset - fadeStart) / (fadeEnd - fadeStart);
    }
    if ((next - _collapse).abs() > 0.02) {
      setState(() => _collapse = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final products = widget.products;
    final cards = <Widget>[
      _StatsCard(shop: shop),
      if (shop.hasPhone || shop.hasTelegram) _ContactCard(shop: shop),
      if ((shop.description ?? '').isNotEmpty)
        _AboutCard(text: shop.description!),
      if (shop.hasAddress || shop.hasLocation) _LocationCard(shop: shop),
      if (shop.workingHours.hasAnyOpenDay) _HoursCard(hours: shop.workingHours),
    ];

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _ShopHeader(shop: shop)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final card in cards) ...[
                      card,
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Mahsulotlar',
                          style: _ts(
                            size: 17,
                            weight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (products.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.terracotta.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${products.length}',
                              style: _ts(
                                size: 12.5,
                                weight: FontWeight.w800,
                                color: AppColors.terracotta,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            if (products.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _EmptyProducts(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    // 0.65 matches the favourites/search grids — the value
                    // PremiumProductCard's fixed layout needs to avoid overflow.
                    childAspectRatio: 0.65,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, i) =>
                      _ShopProductCard(product: products[i]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
        _TopBar(name: shop.name, collapse: _collapse),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Header — cover, logo, name, verified/join subtitle
// ═══════════════════════════════════════════════════════════════════════════

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.shop});

  final ShopProfile shop;

  static const double _coverH = 168;
  static const double _logoD = 92;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final brand = _brandColor(shop.brandColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _coverH + topPad,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              _cover(brand),
              // Bottom scrim keeps the hanging logo + any light cover legible.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x22000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -_logoD / 2,
                child: _Logo(shop: shop, brand: brand, size: _logoD),
              ),
            ],
          ),
        ),
        SizedBox(height: _logoD / 2 + 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop.name,
                style: _ts(
                  size: 22,
                  weight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              _SubtitleLine(shop: shop),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cover(Color brand) {
    if (shop.coverUrl != null) {
      return CachedNetworkImage(
        imageUrl: shop.coverUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 1080,
        placeholder: (_, _) => Container(color: brand.withValues(alpha: 0.18)),
        errorWidget: (_, _, _) => _gradient(brand),
      );
    }
    return _gradient(brand);
  }

  Widget _gradient(Color brand) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brand.withValues(alpha: 0.85),
            brand.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Iconsax.shop,
          size: 56,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _SubtitleLine extends StatelessWidget {
  const _SubtitleLine({required this.shop});

  final ShopProfile shop;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (shop.isVerified) 'Tasdiqlangan sotuvchi',
      if (shop.createdAt != null) '${shop.createdAt!.year}-yildan beri',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        if (shop.isVerified) ...[
          const Icon(Iconsax.verify, size: 15, color: _kVerified),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            parts.join(' · '),
            style: _ts(
              size: 12.5,
              weight: FontWeight.w600,
              color: shop.isVerified ? _kVerified : kGrey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.shop, required this.brand, required this.size});

  final ShopProfile shop;
  final Color brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: shop.logoUrl != null
            ? CachedNetworkImage(
                imageUrl: shop.logoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 240,
                placeholder: (_, _) =>
                    Container(color: brand.withValues(alpha: 0.12)),
                errorWidget: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: brand.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(Iconsax.shop, size: size * 0.4, color: brand),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stats card — product count · rating · review count
// ═══════════════════════════════════════════════════════════════════════════

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.shop});

  final ShopProfile shop;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          _Stat(
            value: '${shop.productCount}',
            label: 'Mahsulot',
            icon: Iconsax.box,
          ),
          const _StatDivider(),
          _Stat(
            value: shop.hasRating ? shop.rating!.toStringAsFixed(1) : '—',
            label: 'Reyting',
            icon: Iconsax.star_1,
            accent: shop.hasRating ? const Color(0xFFE8A33D) : null,
          ),
          const _StatDivider(),
          _Stat(
            value: '${shop.reviewCount}',
            label: 'Sharh',
            icon: Iconsax.message_text_1,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    this.accent,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: accent ?? AppColors.terracotta),
          const SizedBox(height: 7),
          Text(
            value,
            style: _ts(size: 18, weight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 2),
          Text(label, style: _ts(size: 11.5, color: kGrey)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 38, color: kDivider);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Contact card — call + Telegram
// ═══════════════════════════════════════════════════════════════════════════

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.shop});

  final ShopProfile shop;

  Future<void> _call(BuildContext context) async {
    final phone = shop.contactPhone;
    if (phone == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: phone));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Raqam nusxalandi: $phone'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _telegram(BuildContext context) async {
    final username = shop.telegramUsername;
    if (username == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final handle = username.replaceFirst(RegExp(r'^@'), '');
    final ok = await launchUrl(
      Uri.parse('https://t.me/$handle'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Telegramni ochib bo\'lmadi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          if (shop.hasPhone)
            Expanded(
              child: _ContactButton(
                icon: Iconsax.call,
                label: 'Qo\'ng\'iroq',
                color: AppColors.terracotta,
                onTap: () => _call(context),
              ),
            ),
          if (shop.hasPhone && shop.hasTelegram) const SizedBox(width: 10),
          if (shop.hasTelegram)
            Expanded(
              child: _ContactButton(
                icon: Iconsax.send_2,
                label: 'Telegram',
                color: _kTelegram,
                onTap: () => _telegram(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: _ts(size: 14, weight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// About card
// ═══════════════════════════════════════════════════════════════════════════

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Do\'kon haqida'),
          const SizedBox(height: 12),
          Text(text, style: _ts(size: 13.5, color: kInk, height: 1.5)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Location card
// ═══════════════════════════════════════════════════════════════════════════

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.shop});

  final ShopProfile shop;

  Future<void> _openMap(BuildContext context) async {
    final lat = shop.latitude, lon = shop.longitude;
    if (lat == null || lon == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final label = shop.name.isNotEmpty
        ? ' (${Uri.encodeComponent(shop.name)})'
        : '';
    final geo = Uri.parse('geo:$lat,$lon?q=$lat,$lon$label');
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo, mode: LaunchMode.externalApplication);
      return;
    }
    final web = Uri.parse(
      'https://yandex.com/maps/?ll=$lon,$lat&z=16&pt=$lon,$lat',
    );
    final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Xaritani ochib bo\'lmadi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Manzil'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Iconsax.location,
                size: 18,
                color: AppColors.terracotta,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shop.hasAddress ? shop.address! : 'Xaritada belgilangan',
                  style: _ts(size: 13.5, color: kInk, height: 1.4),
                ),
              ),
            ],
          ),
          if (shop.hasLocation) ...[
            const SizedBox(height: 14),
            Material(
              color: kSurfaceMuted,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _openMap(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.map_1, size: 17, color: kInk),
                      const SizedBox(width: 8),
                      Text(
                        'Xaritada ko\'rish',
                        style: _ts(size: 13.5, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Working hours card
// ═══════════════════════════════════════════════════════════════════════════

const Map<DayOfWeek, String> _dayNamesUz = {
  DayOfWeek.monday: 'Dushanba',
  DayOfWeek.tuesday: 'Seshanba',
  DayOfWeek.wednesday: 'Chorshanba',
  DayOfWeek.thursday: 'Payshanba',
  DayOfWeek.friday: 'Juma',
  DayOfWeek.saturday: 'Shanba',
  DayOfWeek.sunday: 'Yakshanba',
};

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.hours});

  final WeeklyHours hours;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DayOfWeek.values[now.weekday - 1];
    final openNow = _isOpenNow(hours, now);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionTitle(text: 'Ish vaqti'),
              const Spacer(),
              _OpenPill(openNow: openNow),
            ],
          ),
          const SizedBox(height: 12),
          for (final day in DayOfWeek.values) ...[
            _HoursRow(
              name: _dayNamesUz[day]!,
              hours: hours[day],
              isToday: day == today,
            ),
            if (day != DayOfWeek.sunday)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Divider(height: 1, thickness: 1, color: kDivider),
              ),
          ],
        ],
      ),
    );
  }
}

class _OpenPill extends StatelessWidget {
  const _OpenPill({required this.openNow});

  final bool openNow;

  @override
  Widget build(BuildContext context) {
    final color = openNow ? _kVerified : const Color(0xFFC0392B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            openNow ? 'Hozir ochiq' : 'Hozir yopiq',
            style: _ts(size: 11.5, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({
    required this.name,
    required this.hours,
    required this.isToday,
  });

  final String name;
  final DayHours hours;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final String value;
    if (hours.closed || hours.open == null || hours.close == null) {
      value = 'Dam olish kuni';
    } else if (hours.isOpen24h) {
      value = '24 soat';
    } else {
      value = '${hours.open} – ${hours.close}';
    }
    final weight = isToday ? FontWeight.w700 : FontWeight.w500;
    final color = (hours.closed || hours.open == null) ? kGreySoft : kInk;
    return Row(
      children: [
        if (isToday) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.terracotta,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          name,
          style: _ts(
            size: 13,
            weight: weight,
            color: isToday ? AppColors.terracotta : kInk,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: _ts(size: 13, weight: weight, color: color),
        ),
      ],
    );
  }
}

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
          FavoriteToggled(_toProduct(product)),
        ),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Iconsax.box, size: 34, color: kGreyMid),
              const SizedBox(height: 10),
              Text(
                'Hozircha mahsulot yo\'q',
                style: _ts(size: 13.5, weight: FontWeight.w600, color: kGrey),
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
    final topPad = MediaQuery.paddingOf(context).top;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Shimmer.fromColors(
          baseColor: kImageBg,
          highlightColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 168 + topPad, color: kImageBg),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 180,
                      height: 22,
                      decoration: BoxDecoration(
                        color: kImageBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 120,
                      height: 13,
                      decoration: BoxDecoration(
                        color: kImageBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      height: 84,
                      decoration: BoxDecoration(
                        color: kImageBg,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.shop, size: 46, color: kGreyMid),
            const SizedBox(height: 16),
            Text(
              'Do\'kon ma\'lumotlarini yuklab bo\'lmadi',
              textAlign: TextAlign.center,
              style: _ts(size: 15, weight: FontWeight.w700),
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
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Iconsax.arrow_left_2, size: 20, color: kInk),
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
Product _toProduct(ProductModel m) => Product(
  id: m.id,
  slug: m.id,
  name: MultilingualText(uz: m.name, ru: m.name, en: m.name),
  price: m.effectivePrice,
  oldPrice: m.hasDiscount ? m.price : null,
  images: m.images,
  attributes: m.attributes,
  stock: m.stock,
);

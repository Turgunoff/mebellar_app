import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/banner.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/supabase_notifications_repository.dart';
import '../../../widgets/glass_bottom_nav.dart';
import '../../categories/bloc/categories_bloc.dart';
import '../../favorites/bloc/favorites_bloc.dart';
import '../../notifications/cubit/notifications_cubit.dart';
import '../bloc/home_bloc.dart';
import '../widgets/premium/glass_banner.dart';
import '../widgets/premium/premium_product_card.dart';
import '../widgets/premium/premium_tokens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return BlocProvider<NotificationsCubit>(
      create: (_) =>
          NotificationsCubit(sl<NotificationDataSource>())..load(),
      child: ColoredBox(
        color: pt.background,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.only(
              bottom: GlassBottomNav.reservedHeight(context) + 16,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              const _DiscoverAppBar(),
              const SizedBox(height: 20),
              const _PremiumSearchBar(),
              const SizedBox(height: 28),
              BlocBuilder<HomeBloc, HomeState>(
                buildWhen: (prev, curr) =>
                    prev.status != curr.status || prev.banners != curr.banners,
                builder: (context, state) {
                  if (state.status == HomeStatus.loading ||
                      state.status == HomeStatus.initial) {
                    return const GlassBannerShimmer();
                  }
                  final banners = state.banners.isNotEmpty
                      ? state.banners
                      : _fallbackBanners;
                  return GlassBanner(banners: banners);
                },
              ),
              const SizedBox(height: 32),
              _SectionHeader(
                title: tr('home.categories'),
                actionLabel: tr('home.see_all'),
                onAction: () => context.push('/categories'),
              ),
              const SizedBox(height: 16),
              const _CategoriesRow(),
              const SizedBox(height: 32),

              // ───────────────────── Top Brands (hidden for MVP) ───────────────
              // The Top Brands rail is intentionally commented out until we
              // ship a real Brands table + admin UI. Keep the dead code in
              // place so we can light it back up without re-deriving the UX.
              //
              // _SectionHeader(title: 'Top Brands', onAction: () {}),
              // const SizedBox(height: 16),
              // _BrandsRow(brands: _mockBrands),
              // const SizedBox(height: 32),
              // ─────────────────────────────────────────────────────────────────

              _SectionHeader(
                title: tr('home.recommended'),
                actionLabel: tr('home.see_all'),
                onAction: () => context.push('/categories'),
              ),
              const SizedBox(height: 16),
              const _RecommendedGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── App bar ───────────────────────────

class _DiscoverAppBar extends StatelessWidget {
  const _DiscoverAppBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('home.discover_eyebrow'),
                  style: PremiumTokens.body(
                    size: 12,
                    weight: FontWeight.w600,
                    color: PremiumTokens.accent,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('home.discover_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTokens.display(size: 26, letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _NotificationBell(),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/customer/notifications'),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: pt.surface,
          shape: BoxShape.circle,
          boxShadow: PremiumTokens.softShadow,
        ),
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          buildWhen: (a, b) => a.unreadCount != b.unreadCount,
          builder: (context, state) {
            final count = state.unreadCount;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(Iconsax.notification, color: pt.dark, size: 22),
                if (count > 0)
                  Positioned(
                    top: 8,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: PremiumTokens.accent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: pt.surface, width: 1.5),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: PremiumTokens.body(
                          size: 9,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────── Search bar (read-only) ───────────────────────────

class _PremiumSearchBar extends StatelessWidget {
  const _PremiumSearchBar();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/search'),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 18),
              Icon(Iconsax.search_normal_1, color: pt.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('home.search_hint'),
                  style: PremiumTokens.body(size: 14, color: pt.grey),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.setting_4,
                  color: PremiumTokens.accent,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Section header ───────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: Text(
                  actionLabel!,
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
    );
  }
}

// ─────────────────────────── Categories ───────────────────────────

class _CategoriesRow extends StatelessWidget {
  const _CategoriesRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoriesBloc, CategoriesState>(
      buildWhen: (a, b) =>
          a.status != b.status || a.categories != b.categories,
      builder: (context, state) {
        final isLoading = state.status == CategoriesStatus.loading ||
            state.status == CategoriesStatus.initial;
        if (isLoading) return const _CategoriesRowSkeleton();
        if (state.categories.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: state.categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) =>
                _PremiumCategoryItem(category: state.categories[i]),
          ),
        );
      },
    );
  }
}

class _PremiumCategoryItem extends StatelessWidget {
  const _PremiumCategoryItem({required this.category});

  final CategoryModel category;

  static IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sofa') || lower.contains('armchair')) {
      return Iconsax.home_2;
    }
    if (lower.contains('table') || lower.contains('desk')) {
      return Iconsax.coffee;
    }
    if (lower.contains('bed') || lower.contains('bedroom')) {
      return Iconsax.moon;
    }
    if (lower.contains('chair') || lower.contains('seat')) {
      return Iconsax.user_octagon;
    }
    if (lower.contains('light') || lower.contains('lamp')) {
      return Iconsax.lamp_charge;
    }
    if (lower.contains('storage') || lower.contains('wardrobe')) {
      return Iconsax.box;
    }
    if (lower.contains('decor') || lower.contains('accent')) {
      return Iconsax.magic_star;
    }
    if (lower.contains('outdoor') || lower.contains('garden')) {
      return Iconsax.tree;
    }
    return Iconsax.shop;
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(
        '/product-list'
        '?categoryId=${Uri.encodeComponent(category.id)}'
        '&categoryName=${Uri.encodeComponent(category.name)}',
      ),
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: PremiumTokens.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PremiumTokens.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _iconFor(category.name),
                color: PremiumTokens.accent,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PremiumTokens.body(
                size: 12,
                weight: FontWeight.w600,
                color: pt.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesRowSkeleton extends StatelessWidget {
  const _CategoriesRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Shimmer.fromColors(
          baseColor: pt.imageBg,
          highlightColor: pt.surface,
          child: Container(
            width: 84,
            decoration: BoxDecoration(
              color: pt.imageBg,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Recommended grid ───────────────────────────

class _RecommendedGrid extends StatelessWidget {
  const _RecommendedGrid();

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
    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (a, b) =>
          a.status != b.status || a.recommended != b.recommended,
      builder: (context, state) {
        final isLoading = state.status == HomeStatus.loading ||
            state.status == HomeStatus.initial;
        if (isLoading) return const _RecommendedGridSkeleton();
        if (state.recommended.isEmpty) {
          return const _RecommendedEmpty();
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.65,
          ),
          itemCount: state.recommended.length,
          itemBuilder: (_, i) {
            final p = state.recommended[i];
            return BlocSelector<FavoritesBloc, FavoritesState, bool>(
              selector: (s) => s.isFavorite(p.id),
              builder: (context, isFav) => PremiumProductCard(
                imageUrl: p.thumbnail ?? '',
                name: p.name,
                shop: p.description ?? '',
                price: _formatPrice(p.price),
                isFavorite: isFav,
                onTap: () =>
                    context.push('/product-detail/${p.id}', extra: p),
                onFavoriteToggle: () => context
                    .read<FavoritesBloc>()
                    .add(FavoriteToggled(_toProduct(p))),
              ),
            );
          },
        );
      },
    );
  }
}

class _RecommendedGridSkeleton extends StatelessWidget {
  const _RecommendedGridSkeleton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemCount: 4,
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

class _RecommendedEmpty extends StatelessWidget {
  const _RecommendedEmpty();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: PremiumTokens.softShadow,
        ),
        child: Row(
          children: [
            Icon(Iconsax.box, size: 28, color: pt.greyLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('home.recommended_empty'),
                style: PremiumTokens.body(
                  size: 13,
                  color: pt.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Fallback banners ───────────────────────────

const _fallbackBanners = <HomeBanner>[
  HomeBanner(
    id: '__fb1',
    imageUrl:
        'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?w=1200&q=80',
    title: MultilingualText(
      uz: 'QIŞ SOTUVI',
      ru: 'ЗИМНЯЯ РАСПРОДАЖА',
      en: 'WINTER SALE',
    ),
    subtitle: MultilingualText(
      uz: '30% gacha chegirma',
      ru: 'Скидки до 30%',
      en: 'Up to 30% Off',
    ),
  ),
  HomeBanner(
    id: '__fb2',
    imageUrl:
        'https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=1200&q=80',
    title: MultilingualText(
      uz: 'YANGI MAHSULOTLAR',
      ru: 'НОВИНКИ',
      en: 'NEW ARRIVALS',
    ),
    subtitle: MultilingualText(
      uz: 'Bahorgi kolleksiya 2026',
      ru: 'Весенняя коллекция 2026',
      en: 'Spring Collection 2026',
    ),
  ),
  HomeBanner(
    id: '__fb3',
    imageUrl:
        'https://images.unsplash.com/photo-1631679706909-1844bbd07221?w=1200&q=80',
    title: MultilingualText(
      uz: 'BEPUL YETKAZISH',
      ru: 'БЕСПЛАТНАЯ ДОСТАВКА',
      en: 'FREE DELIVERY',
    ),
    subtitle: MultilingualText(
      uz: "5M so'mdan yuqori buyurtmalarda",
      ru: 'При заказе от 5M UZS',
      en: 'On orders above 5M UZS',
    ),
  ),
];

// ─────────────────────── Top Brands (commented out for MVP) ───────────────────
// The widgets and mock data below are kept in cold storage so we can light the
// section back up in a follow-up sprint.
//
// const _mockBrands = <({String name, String logoUrl})>[
//   (
//     name: 'Mebel House',
//     logoUrl:
//         'https://images.unsplash.com/photo-1486312338219-ce68d2c6f44d?w=200&q=80',
//   ),
//   (
//     name: 'Nordic Home',
//     logoUrl:
//         'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80',
//   ),
//   (
//     name: 'Casa Luxe',
//     logoUrl:
//         'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&q=80',
//   ),
//   (
//     name: 'Studio Living',
//     logoUrl:
//         'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&q=80',
//   ),
// ];
//
// class _BrandsRow extends StatelessWidget {
//   const _BrandsRow({required this.brands});
//
//   final List<({String name, String logoUrl})> brands;
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 110,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 20),
//         itemCount: brands.length,
//         separatorBuilder: (_, _) => const SizedBox(width: 18),
//         itemBuilder: (_, i) {
//           final b = brands[i];
//           return _BrandAvatar(name: b.name, logoUrl: b.logoUrl);
//         },
//       ),
//     );
//   }
// }
//
// class _BrandAvatar extends StatelessWidget {
//   const _BrandAvatar({required this.name, required this.logoUrl});
//
//   final String name;
//   final String logoUrl;
//
//   @override
//   Widget build(BuildContext context) {
//     final pt = PremiumTokens.of(context);
//     return SizedBox(
//       width: 76,
//       child: Column(
//         children: [
//           Container(
//             width: 72,
//             height: 72,
//             padding: const EdgeInsets.all(2.5),
//             decoration: const BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [
//                   PremiumTokens.accent,
//                   Color(0xFFE8B79C),
//                   PremiumTokens.accentDeep,
//                 ],
//               ),
//             ),
//             child: Container(
//               padding: const EdgeInsets.all(3),
//               decoration: BoxDecoration(
//                 color: pt.background,
//                 shape: BoxShape.circle,
//               ),
//               child: ClipOval(
//                 child: CachedNetworkImage(
//                   imageUrl: logoUrl,
//                   fit: BoxFit.cover,
//                   placeholder: (_, _) => Shimmer.fromColors(
//                     baseColor: pt.imageBg,
//                     highlightColor: const Color(0xFFFAFAFA),
//                     child: Container(color: Colors.white),
//                   ),
//                   errorWidget: (_, _, _) => Container(
//                     color: pt.imageBg,
//                     child: Icon(Iconsax.shop, color: pt.greyLight),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             name,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: PremiumTokens.body(
//               size: 12,
//               weight: FontWeight.w600,
//               color: pt.dark,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

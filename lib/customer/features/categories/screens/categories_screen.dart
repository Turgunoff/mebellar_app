import 'dart:ui';

import 'package:go_router/go_router.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../shared/models/category_model.dart';
import '../../../widgets/glass_bottom_nav.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../bloc/categories_bloc.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ColoredBox(
      color: pt.background,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<CategoriesBloc, CategoriesState>(
          builder: (context, state) {
            if (state.status == CategoriesStatus.failure) {
              return _ErrorView(message: state.error ?? 'Unknown error');
            }

            final isLoading = state.status == CategoriesStatus.loading ||
                state.status == CategoriesStatus.initial;
            final items = state.categories;

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                GlassBottomNav.reservedHeight(context) + 48,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount: isLoading ? 5 : items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 20),
              itemBuilder: (context, i) {
                if (i == 0) return const _CategoriesAppBar();
                if (isLoading) return const _SkeletonCard();
                final cat = items[i - 1];
                return _EditorialCategoryCard(category: cat);
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App bar header
// ---------------------------------------------------------------------------

class _CategoriesAppBar extends StatelessWidget {
  const _CategoriesAppBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover',
                  style: PremiumTokens.body(
                    size: 12,
                    weight: FontWeight.w600,
                    color: PremiumTokens.accent,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Categories',
                  style: PremiumTokens.display(size: 32, letterSpacing: -0.6),
                ),
              ],
            ),
          ),
          const _SearchIconButton(),
        ],
      ),
    );
  }
}

class _SearchIconButton extends StatelessWidget {
  const _SearchIconButton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: pt.imageBg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Iconsax.search_normal_1, size: 20, color: pt.dark),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editorial card — real data
// ---------------------------------------------------------------------------

class _EditorialCategoryCard extends StatefulWidget {
  const _EditorialCategoryCard({required this.category});

  final CategoryModel category;

  @override
  State<_EditorialCategoryCard> createState() =>
      _EditorialCategoryCardState();
}

class _EditorialCategoryCardState extends State<_EditorialCategoryCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final cat = widget.category;
    final itemLabel = cat.subcategoryCount > 0
        ? '${cat.subcategoryCount} subcategories'
        : '0 items';

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () => context.push(
        '/product-list?categoryId=${Uri.encodeComponent(cat.id)}'
        '&categoryName=${Uri.encodeComponent(cat.name)}',
      ),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 170,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: PremiumTokens.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  if (cat.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: cat.imageUrl!,
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
                          size: 32,
                        ),
                      ),
                    )
                  else
                    Container(color: pt.imageBg),

                  // Gradient scrim
                  const _CardGradientScrim(),

                  // Item count pill
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _GlassItemPill(label: itemLabel),
                  ),

                  // Title + arrow
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 22,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (cat.subtitle != null) ...[
                                Text(
                                  cat.subtitle!.toUpperCase(),
                                  style: PremiumTokens.body(
                                    size: 10,
                                    weight: FontWeight.w600,
                                    color:
                                        Colors.white.withValues(alpha: 0.85),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                cat.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: PremiumTokens.display(
                                  size: 24,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading card
// ---------------------------------------------------------------------------

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Shimmer.fromColors(
      baseColor: pt.imageBg,
      highlightColor: pt.surface,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: pt.imageBg,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

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
              'Could not load categories',
              style: PremiumTokens.body(
                size: 16,
                weight: FontWeight.w600,
                color: pt.dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PremiumTokens.body(size: 13, color: pt.grey),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () =>
                  context.read<CategoriesBloc>().add(const CategoriesRequested()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared decorative widgets
// ---------------------------------------------------------------------------

class _CardGradientScrim extends StatelessWidget {
  const _CardGradientScrim();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [Color(0xCC000000), Color(0x66000000), Color(0x00000000)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xB3000000), Color(0x33000000), Color(0x00000000)],
              stops: [0.0, 0.55, 0.95],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassItemPill extends StatelessWidget {
  const _GlassItemPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: PremiumTokens.body(
              size: 11,
              weight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/image_error_placeholder.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../customer_app.dart';
import '../../../widgets/network_error_gate.dart';
import '../../../../core/theme/premium_tokens.dart';
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
        child: Column(
          children: [
            // Pinned header — stays put while the category list scrolls.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _CategoriesAppBar(),
            ),
            Expanded(
              child: NetworkErrorGate<CategoriesBloc, CategoriesState>(
                isActive: (ctx) => CustomerShellScope.of(ctx).index == 1,
                onRetry: (bloc) =>
                    bloc.add(const CategoriesRequested(refresh: true)),
                backgroundError: (s) =>
                    s.status == CategoriesStatus.ready && s.error != null
                    ? s.error
                    : null,
                child: BlocBuilder<CategoriesBloc, CategoriesState>(
                  builder: (context, state) {
                    // First-load failure with nothing cached → premium error
                    // state. Subsequent failures while we still have stale items
                    // keep the list visible (the global red banner already tells
                    // the user about the connection).
                    final isFailure = state.status == CategoriesStatus.failure;
                    final hasItems = state.categories.isNotEmpty;
                    if (isFailure && !hasItems) {
                      return ErrorState(
                        title: tr('home.categories_error_title'),
                        onRetry: () => context.read<CategoriesBloc>().add(
                          const CategoriesRequested(),
                        ),
                      );
                    }

                    // Shimmer only while we're actively loading; once the bloc
                    // emits failure (or ready) we never re-enter shimmer state.
                    final isLoading =
                        state.status == CategoriesStatus.loading ||
                        state.status == CategoriesStatus.initial;
                    final items = state.categories;

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
                      physics: const BouncingScrollPhysics(),
                      itemCount: isLoading ? 5 : items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, i) {
                        if (isLoading) return const _SkeletonCard();
                        return _EditorialCategoryCard(category: items[i]);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
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
                  tr('catalog.discover_eyebrow'),
                  style: PremiumTokens.body(
                    size: 12,
                    weight: FontWeight.w600,
                    color: PremiumTokens.accent,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr('catalog.title_2'),
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
      color: pt.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/search'),
        child: Ink(
          decoration: BoxDecoration(
            color: pt.surface,
            shape: BoxShape.circle,
            boxShadow: PremiumTokens.softShadow,
          ),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Iconsax.search_normal_1_copy,
              size: 19,
              color: PremiumTokens.accent,
            ),
          ),
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
  State<_EditorialCategoryCard> createState() => _EditorialCategoryCardState();
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
          height: 140,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: PremiumTokens.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  if (cat.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: cat.imageUrl!,
                      // ROADMAP B.7 — full-width category card image.
                      memCacheWidth: 600,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const ShimmerBox(
                        height: double.infinity,
                        borderRadius: 0,
                      ),
                      errorWidget: (_, _, _) =>
                          const ImageErrorPlaceholder(iconSize: 36),
                    )
                  else
                    Container(color: pt.imageBg),

                  // Gradient scrim
                  const _CardGradientScrim(),

                  // Subcategory count pill — hidden when there are none.
                  if (cat.subcategoryCount > 0)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _GlassItemPill(
                        label: tr(
                          'catalog.subcategory_count',
                          namedArgs: {'count': cat.subcategoryCount.toString()},
                        ),
                      ),
                    ),

                  // Title + arrow
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
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
                                    color: Colors.white.withValues(alpha: 0.85),
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
                                  size: 22,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const _CardArrowButton(),
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
    return const ShimmerBox(height: 140, borderRadius: 20);
  }
}

// ---------------------------------------------------------------------------
// Shared decorative widgets
// ---------------------------------------------------------------------------

class _CardGradientScrim extends StatelessWidget {
  const _CardGradientScrim();

  // The scrim is built from a warm espresso base (a very dark, red-leaning
  // brown, 0xFF2A150D) plus a terracotta wash. Constant — like every photo
  // scrim it always sits under white text, so it never flips for dark mode.

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        // Diagonal espresso scrim — anchors the bottom-left title in shadow
        // while the furniture stays visible toward the top-right.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [Color(0xF02A150D), Color(0x802A150D), Color(0x002A150D)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Bottom full-width darkening so the title row stays legible all the way
        // across to the arrow.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0x992A150D), Color(0x00000000)],
              stops: [0.0, 0.6],
            ),
          ),
        ),
        // Terracotta brand wash on top — lifts the dark scrim into a warm,
        // furniture-catalog brown and unifies every photo under one tone.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x59B85C38), Color(0x1FB85C38), Color(0x00B85C38)],
              stops: [0.0, 0.5, 1.0],
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
            // Warm translucent brown to sit on the terracotta scrim instead of
            // the old cold white glass.
            color: const Color(0x593A1E12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
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

// ---------------------------------------------------------------------------
// Frosted arrow affordance — warm translucent disc with a white chevron,
// matching the badge glass so the card reads as one terracotta set.
// ---------------------------------------------------------------------------

class _CardArrowButton extends StatelessWidget {
  const _CardArrowButton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x593A1E12),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: const Icon(
            Iconsax.arrow_right_3_copy,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

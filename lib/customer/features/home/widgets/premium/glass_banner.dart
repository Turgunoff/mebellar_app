import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../shared/models/banner.dart';
import '../../../../../shared/models/multilingual_text.dart';
import '../../../../../shared/widgets/image_error_placeholder.dart';
import '../../../../customer_app.dart' show CustomerShellScope;
import 'premium_tokens.dart';

class GlassBanner extends StatefulWidget {
  const GlassBanner({
    super.key,
    required this.banners,
    this.aspectRatio = 21 / 9,
  });

  final List<HomeBanner> banners;

  /// Wide, short promo band (21:9 by default) so more of the feed shows above
  /// the fold. The pager fills this ratio instead of a fixed pixel height.
  final double aspectRatio;

  /// Sentinel id for the locally-injected "Sotuvchi bo'ling" promo slide. It is
  /// rendered as a branded gradient (not a network image) and routes to the
  /// Profile tab, where the real seller-onboarding CTA lives.
  static const sellerPromoId = '__seller_promo';

  /// The seller-promo slide. Prepend it to the banner list to surface it first.
  /// `linkType: 'tab'` + `linkTarget: '4'` (Profile) is handled by
  /// [_handleBannerTap].
  static const sellerPromoBanner = HomeBanner(
    id: sellerPromoId,
    imageUrl: '',
    title: MultilingualText(
      uz: "Sotuvchi bo'ling",
      ru: 'Станьте продавцом',
      en: 'Become a seller',
    ),
    subtitle: MultilingualText(
      uz: "Mahsulotlaringizni Woody'da soting",
      ru: 'Продавайте свои товары на Woody',
      en: 'Sell your products on Woody',
    ),
    linkType: 'tab',
    linkTarget: '4',
  );

  @override
  State<GlassBanner> createState() => _GlassBannerState();
}

class _GlassBannerState extends State<GlassBanner> {
  final _controller = PageController(viewportFraction: 0.92);
  int _index = 0;
  Timer? _autoPlay;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(GlassBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) _startAutoPlay();
  }

  /// Advances the pager every few seconds, looping back to the first slide.
  /// A single banner doesn't auto-play.
  void _startAutoPlay() {
    _autoPlay?.cancel();
    if (widget.banners.length <= 1) return;
    _autoPlay = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _BannerCard(data: widget.banners[i]),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: active ? 20 : 6,
                decoration: BoxDecoration(
                  color: active ? PremiumTokens.accent : pt.greyLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Routes a banner tap to the configured target. Mirrors the admin panel's
/// action picker (category / product / url), plus the locally-injected `tab`
/// action used by the seller promo. Unknown types (incl. 'shop', which has no
/// customer screen yet) are no-ops.
Future<void> _handleBannerTap(BuildContext context, HomeBanner banner) async {
  final type = banner.linkType ?? '';
  final target = banner.linkTarget?.trim() ?? '';
  if (target.isEmpty) return;

  if (type == 'tab') {
    final index = int.tryParse(target);
    if (index != null) CustomerShellScope.of(context).goToTab(index);
    return;
  }

  if (type == 'url') {
    final uri = Uri.tryParse(target);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }

  final route = switch (type) {
    'product' => '/product-detail/$target',
    'category' => '/product-list?categoryId=${Uri.encodeComponent(target)}',
    _ => null,
  };
  if (route != null) context.push(route);
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.data});

  final HomeBanner data;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final hasAction =
        (data.linkType ?? '').isNotEmpty &&
        (data.linkTarget ?? '').trim().isNotEmpty;
    final isSellerPromo = data.id == GlassBanner.sellerPromoId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: hasAction ? () => _handleBannerTap(context, data) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: isSellerPromo
              ? _SellerPromoBody(data: data, lang: lang)
              : _ImageBannerBody(data: data, lang: lang),
        ),
      ),
    );
  }
}

/// Branded gradient slide for the "Sotuvchi bo'ling" promo — no network image,
/// so it never depends on a CDN URL and always renders.
class _SellerPromoBody extends StatelessWidget {
  const _SellerPromoBody({required this.data, required this.lang});

  final HomeBanner data;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final title = data.title?.get(lang) ?? '';
    final subtitle = data.subtitle?.get(lang) ?? '';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [PremiumTokens.accentDeep, PremiumTokens.accent],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTokens.display(
                        size: 20,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTokens.body(
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.shop, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard image banner with a frosted-glass text overlay.
class _ImageBannerBody extends StatelessWidget {
  const _ImageBannerBody({required this.data, required this.lang});

  final HomeBanner data;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final eyebrow = data.title?.get(lang) ?? '';
    final title = data.subtitle?.get(lang) ?? '';
    final hasText = eyebrow.isNotEmpty || title.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: data.imageUrl,
          // ROADMAP B.7 — full-width banner; cap near device width.
          memCacheWidth: 1080,
          fit: BoxFit.cover,
          placeholder: (_, _) => Shimmer.fromColors(
            baseColor: pt.imageBg,
            highlightColor: const Color(0xFFFAFAFA),
            child: Container(color: Colors.white),
          ),
          errorWidget: (_, _, _) => const ImageErrorPlaceholder(iconSize: 40),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.transparent, Colors.black26],
            ),
          ),
        ),
        if (hasText)
          Positioned(
            left: 20,
            bottom: 20,
            right: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (eyebrow.isNotEmpty)
                        Text(
                          eyebrow,
                          style:
                              PremiumTokens.body(
                                size: 12,
                                weight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ).copyWith(
                                shadows: const [
                                  Shadow(blurRadius: 8, color: Colors.black26),
                                ],
                              ),
                        ),
                      if (eyebrow.isNotEmpty && title.isNotEmpty)
                        const SizedBox(height: 6),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style:
                              PremiumTokens.display(
                                size: 22,
                                color: Colors.white,
                                height: 1.1,
                              ).copyWith(
                                shadows: const [
                                  Shadow(blurRadius: 12, color: Colors.black38),
                                ],
                              ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shimmer skeleton that matches [GlassBanner]'s shape and dimensions. Drop it
/// in wherever [GlassBanner] would appear while data is loading.
class GlassBannerShimmer extends StatelessWidget {
  const GlassBannerShimmer({super.key, this.aspectRatio = 21 / 9});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Shimmer.fromColors(
            baseColor: pt.imageBg,
            highlightColor: const Color(0xFFFAFAFA),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (_) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: 6,
              decoration: BoxDecoration(
                color: pt.greyLight,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

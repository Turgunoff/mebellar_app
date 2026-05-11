import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../shared/models/banner.dart';
import 'premium_tokens.dart';

class GlassBanner extends StatefulWidget {
  const GlassBanner({super.key, required this.banners, this.height = 220});

  final List<HomeBanner> banners;
  final double height;

  @override
  State<GlassBanner> createState() => _GlassBannerState();
}

class _GlassBannerState extends State<GlassBanner> {
  final _controller = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) =>
                _BannerCard(data: widget.banners[i], height: widget.height),
          ),
        ),
        const SizedBox(height: 16),
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
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.data, required this.height});

  final HomeBanner data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final eyebrow = data.title?.get(lang) ?? '';
    final title = data.subtitle?.get(lang) ?? '';
    final hasText = eyebrow.isNotEmpty || title.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: data.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Shimmer.fromColors(
                baseColor: pt.imageBg,
                highlightColor: const Color(0xFFFAFAFA),
                child: Container(color: Colors.white),
              ),
              errorWidget: (_, _, _) => Container(
                color: pt.imageBg,
                child: Icon(
                  Iconsax.gallery,
                  color: pt.greyLight,
                  size: 48,
                ),
              ),
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
                              style: PremiumTokens.body(
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
                              style: PremiumTokens.display(
                                size: 22,
                                color: Colors.white,
                                height: 1.1,
                              ).copyWith(
                                shadows: const [
                                  Shadow(
                                      blurRadius: 12, color: Colors.black38),
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
        ),
      ),
    );
  }
}

/// Shimmer skeleton that matches [GlassBanner]'s exact shape and dimensions.
/// Drop it in wherever [GlassBanner] would appear while data is loading.
class GlassBannerShimmer extends StatelessWidget {
  const GlassBannerShimmer({super.key, this.height = 220});

  final double height;

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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(height: height, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
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

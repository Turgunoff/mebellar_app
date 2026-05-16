import 'package:cached_network_image/cached_network_image.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/banner.dart';
import '../../../../shared/widgets/image_error_placeholder.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.banners, this.onTap});

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onTap;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final b = widget.banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: widget.onTap == null ? null : () => widget.onTap!(b),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: b.imageUrl,
                          // ROADMAP B.7 — full-bleed banner; cap near the
                          // widest common device width.
                          memCacheWidth: 1080,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              const ImageErrorPlaceholder(iconSize: 40),
                        ),
                        if (b.title != null)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Text(
                              b.title!.get(lang),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(blurRadius: 6, color: Colors.black54),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
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

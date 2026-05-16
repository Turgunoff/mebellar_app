import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'product_preview_kit.dart';

/// Pinned, square-expanding image gallery app bar for the product preview.
class PreviewAppBar extends StatelessWidget {
  const PreviewAppBar({super.key, required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width;
    return SliverAppBar(
      pinned: true,
      expandedHeight: size,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _GlassIconButton(
          icon: Iconsax.arrow_left_2,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _GlassIconButton(icon: Iconsax.share, onTap: () {}),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _ImageGallery(images: images),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: kInk),
        ),
      ),
    );
  }
}

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.images});

  final List<String> images;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imgs.isEmpty)
          Container(
            color: kImageBg,
            alignment: Alignment.center,
            child: const Icon(Iconsax.image, size: 72, color: kGreyMid),
          )
        else
          PageView.builder(
            controller: _controller,
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: imgs[i],
              // ROADMAP B.7 — full-width product preview image.
              memCacheWidth: 1080,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: kImageBg),
              errorWidget: (_, _, _) => Container(
                color: kImageBg,
                alignment: Alignment.center,
                child: const Icon(
                  Iconsax.gallery_slash,
                  size: 48,
                  color: kGreyMid,
                ),
              ),
            ),
          ),
        if (imgs.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < imgs.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

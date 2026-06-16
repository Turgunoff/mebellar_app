import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/fullscreen_image_viewer.dart';

/// Pinned, square-expanding image gallery app bar for the product preview.
///
/// Each gallery slide is wrapped in a [Hero] (keyed by [heroTagPrefix]+index)
/// so tapping animates open the fullscreen viewer; the viewer is reached
/// through [openFullscreenImageViewer].
///
/// As the user scrolls down, [titleOpacity] (driven by the parent screen's
/// scroll controller) fades [productName] into the toolbar slot — so once
/// the gallery scrolls off-screen, the title stays pinned at the top.
class PreviewAppBar extends StatelessWidget {
  const PreviewAppBar({
    super.key,
    required this.images,
    required this.heroTagPrefix,
    required this.productName,
    this.titleOpacity = 0,
    this.extraActions = const [],
    this.onShare,
    this.galleryOverlay,
  });

  final List<String> images;
  final String heroTagPrefix;
  final String productName;
  final double titleOpacity;

  /// Optional widget pinned to the gallery's bottom-right corner (e.g. the
  /// customer detail screen's "3D / AR" glass badge). Kept generic so this
  /// shared preview app bar carries no feature knowledge; null on surfaces
  /// that don't need it (the seller preview).
  final Widget? galleryOverlay;

  /// Toolbar actions rendered to the left of the built-in share button
  /// (e.g. the customer detail screen's favourite toggle). Use
  /// [PreviewGlassIconButton] so they match the glass style.
  final List<Widget> extraActions;

  /// Tapped when the user hits the built-in share button. Null on surfaces
  /// where sharing is meaningless (e.g. the seller's pre-publish preview),
  /// which keeps the button inert.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size.width;
    return SliverAppBar(
      pinned: true,
      expandedHeight: size,
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      titleSpacing: 0,
      // Title sits in the toolbar slot. We render it ourselves with an
      // opacity tween so it disappears entirely when the gallery is
      // expanded, then fades in as the user scrolls past the image.
      title: Opacity(
        opacity: titleOpacity,
        child: Text(
          productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: c.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.2,
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: PreviewGlassIconButton(
          icon: Iconsax.arrow_left_2,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      actions: [
        ...extraActions,
        Padding(
          padding: const EdgeInsets.all(8),
          child: PreviewGlassIconButton(
            icon: Iconsax.share,
            onTap: onShare ?? () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _ImageGallery(
          images: images,
          heroTagPrefix: heroTagPrefix,
          overlay: galleryOverlay,
        ),
      ),
    );
  }
}

/// Circular frosted toolbar button used by [PreviewAppBar] (back, share)
/// and exposed for callers that pass [PreviewAppBar.extraActions].
class PreviewGlassIconButton extends StatelessWidget {
  const PreviewGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Icon ink. Defaults to the fixed dark value that reads on the white
  /// glass — pass an accent (e.g. terracotta) for an active toggle state.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Frosted-white glass over the photo gallery in both modes, so the ink
    // icon stays the fixed dark value (it must read on the white glass, not
    // flip to a light ink in dark mode).
    final ink = color ?? AppColors.sellerInk;
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          // Toggle buttons (favourite) swap icon + ink on tap; the scale-pop
          // switcher makes that swap read as a deliberate state change.
          // Static icons (back, share) never change keys, so this is inert
          // for them.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(
              icon,
              key: ValueKey('${icon.codePoint}-${ink.toARGB32()}'),
              size: 20,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({
    required this.images,
    required this.heroTagPrefix,
    this.overlay,
  });

  final List<String> images;
  final String heroTagPrefix;
  final Widget? overlay;

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
    final c = SellerColors.of(context);
    final imgs = widget.images;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imgs.isEmpty)
          Container(
            color: c.imageBg,
            alignment: Alignment.center,
            child: Icon(Iconsax.image, size: 72, color: c.greyMid),
          )
        else
          PageView.builder(
            controller: _controller,
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openFullscreenImageViewer(
                context,
                images: imgs,
                initialIndex: i,
                heroTagPrefix: widget.heroTagPrefix,
              ),
              child: Hero(
                tag: '${widget.heroTagPrefix}-$i',
                child: CachedNetworkImage(
                  imageUrl: imgs[i],
                  // ROADMAP B.7 — full-width product preview image.
                  memCacheWidth: 1080,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: c.imageBg),
                  errorWidget: (_, _, _) => Container(
                    color: c.imageBg,
                    alignment: Alignment.center,
                    child: Icon(
                      Iconsax.gallery_slash,
                      size: 48,
                      color: c.greyMid,
                    ),
                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
        if (widget.overlay != null)
          Positioned(right: 16, bottom: 16, child: widget.overlay!),
      ],
    );
  }
}

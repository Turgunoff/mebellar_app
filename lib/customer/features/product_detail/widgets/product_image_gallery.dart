import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    super.key,
    required this.images,
    required this.heroTag,
    this.fillParent = false,
  });

  final List<String> images;
  final String heroTag;

  /// When `true`, the gallery expands to fill its parent's constraints
  /// instead of forcing a 1:1 aspect ratio. Used by the detail screen's
  /// `SliverAppBar.flexibleSpace`, where the height is controlled by
  /// `expandedHeight` and an `AspectRatio(1)` would either overflow or
  /// leave a gap.
  final bool fillParent;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreen(BuildContext context, int initial) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) => _FullscreenGallery(
          images: widget.images,
          initialIndex: initial,
          heroTag: widget.heroTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imgs = widget.images;
    // Soft, neutral surface keeps the empty space around a `BoxFit.contain`
    // image visually quiet — important because furniture photos rarely match
    // the gallery's aspect ratio and `cover` was previously cropping the
    // sides of products.
    final surface = scheme.surfaceContainerLow;
    final pageView = PageView.builder(
      controller: _controller,
      itemCount: imgs.isEmpty ? 1 : imgs.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (context, i) {
        if (imgs.isEmpty) {
          return Container(
            color: surface,
            alignment: Alignment.center,
            child: Icon(
              Icons.image_outlined,
              size: 64,
              color: scheme.outline,
            ),
          );
        }
        final img = imgs[i];
        final tag = i == 0 ? widget.heroTag : '${widget.heroTag}-$i';
        return GestureDetector(
          onTap: () => _openFullscreen(context, i),
          child: ColoredBox(
            color: surface,
            child: Hero(
              tag: tag,
              child: CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.contain,
                placeholder: (_, _) => Container(color: surface),
                errorWidget: (_, _, _) => Container(
                  color: surface,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: scheme.outline,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    return Stack(
      children: [
        if (widget.fillParent)
          Positioned.fill(child: pageView)
        else
          AspectRatio(aspectRatio: 1, child: pageView),
        if (imgs.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < imgs.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
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

class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery({
    required this.images,
    required this.initialIndex,
    required this.heroTag,
  });

  final List<String> images;
  final int initialIndex;
  final String heroTag;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final img = widget.images[i];
                final tag = i == 0 ? widget.heroTag : '${widget.heroTag}-$i';
                return Center(
                  child: Hero(
                    tag: tag,
                    child: InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.contain,
                        placeholder: (_, _) =>
                            const CircularProgressIndicator(),
                        errorWidget: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 96,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Text(
              '${_index + 1} / ${widget.images.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

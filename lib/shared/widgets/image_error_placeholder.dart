import 'package:flutter/material.dart';

/// Premium fallback for failed network images.
///
/// Drop into [CachedNetworkImage.errorWidget] (or any spot a remote image
/// could 404) instead of Material's default broken-image glyph. Uses the
/// active theme's `surfaceContainerHighest` so it sits flush with cards
/// and product tiles in both light and dark modes.
///
/// ```dart
/// CachedNetworkImage(
///   imageUrl: url,
///   errorWidget: (_, _, _) => const ImageErrorPlaceholder(),
/// )
/// ```
class ImageErrorPlaceholder extends StatelessWidget {
  const ImageErrorPlaceholder({
    super.key,
    this.iconSize = 28,
    this.borderRadius,
  });

  /// Override when the placeholder lives inside a small tile (e.g. category
  /// chip) and the default 28px glyph would look oversized.
  final double iconSize;

  /// Optional clipping radius — only needed when the placeholder isn't
  /// already wrapped in a `ClipRRect` by its parent.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: iconSize,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
    if (borderRadius == null) return body;
    return ClipRRect(borderRadius: borderRadius!, child: body);
  }
}

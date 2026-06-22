/// One placeable furniture piece in a set's AR / 2D scene. Carries everything
/// both placement modes need: the approved `.glb` (+ real cm dimensions for
/// true-to-size native AR), the 2D photo used as a draggable sticker / picker
/// thumbnail, and a display name.
///
/// A set member with no approved model ([hasModel] false) is still placeable in
/// 2D sticker mode via its [imageUrl]; the native AR mode simply skips it.
class ArSetPiece {
  const ArSetPiece({
    required this.id,
    required this.name,
    this.glbUrl,
    this.imageUrl,
    this.widthCm,
    this.heightCm,
    this.depthCm,
  });

  final String id;
  final String name;

  /// Approved `.glb` URL for native AR placement; null/empty → not 3D-placeable.
  final String? glbUrl;

  /// 2D photo URL used as a sticker in 2D mode and as a picker thumbnail in AR.
  final String? imageUrl;

  final num? widthCm;
  final num? heightCm;
  final num? depthCm;

  bool get hasModel => glbUrl != null && glbUrl!.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}

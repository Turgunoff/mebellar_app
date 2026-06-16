/// Maps a product's real dimensions (cm) to a `<model-viewer>` `scale` string —
/// space-separated `x y z` metre multipliers (ModelViewer treats 1 scene unit
/// as 1 metre, so each axis is cm / 100). Returns null when any axis is missing
/// or non-positive, so the model renders unscaled rather than collapsed.
///
/// Meshy normalises every generated mesh into a unit cube, so a per-axis
/// cm→metre multiply restores the real proportions and footprint. Shared by the
/// buyer-side and seller-side 3D viewers so the normalisation lives in one place.
String? arScaleString(num? widthCm, num? heightCm, num? depthCm) {
  final w = widthCm, h = heightCm, d = depthCm;
  if (w == null || h == null || d == null) return null;
  if (w <= 0 || h <= 0 || d <= 0) return null;
  return '${w / 100} ${h / 100} ${d / 100}';
}

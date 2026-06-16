import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';

/// Buyer-side 3D viewer for an approved `.glb`. Wraps `<model-viewer>` with AR
/// ("view in your room"), idle auto-rotate, and full rotate/zoom controls.
///
/// When the product's real dimensions are known, the model is rendered
/// true-to-size in AR: Meshy normalises every mesh, so mapping each axis to the
/// product's measured cm gives a physically accurate placement. This is an
/// approximation — it assumes the normalised model fills a unit cube, so a
/// per-axis multiply restores the real proportions and footprint.
class ArViewerScreen extends StatelessWidget {
  const ArViewerScreen({
    super.key,
    required this.modelUrl,
    required this.productName,
    this.widthCm,
    this.heightCm,
    this.depthCm,
  });

  final String modelUrl;
  final String productName;

  /// Real product dimensions in centimetres. When all three are present and
  /// positive the model is scaled true-to-size in AR; otherwise it renders
  /// unscaled (graceful — never crashes on missing dims).
  final num? widthCm;
  final num? heightCm;
  final num? depthCm;

  /// Space-separated `x y z` multipliers for the `<model-viewer>` `scale`
  /// attribute, or null when any dimension is missing/non-positive. ModelViewer
  /// treats 1 scene unit as 1 metre, so cm are divided by 100.
  String? get _scale {
    final w = widthCm, h = heightCm, d = depthCm;
    if (w == null || h == null || d == null) return null;
    if (w <= 0 || h <= 0 || d <= 0) return null;
    return '${w / 100} ${h / 100} ${d / 100}';
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scale;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        title: Text(
          tr('product.ar_viewer_title'),
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ModelViewer(
        src: modelUrl,
        alt: productName,
        ar: true,
        // Lock AR scale to true size so buyers can't pinch-resize the model and
        // misjudge whether it fits their room.
        arScale: scale != null ? ArScale.fixed : null,
        // `scale` is the native <model-viewer> attribute ('x y z' metre
        // multipliers); the package exposes it as a typed param in 1.10.0, so
        // no JS/innerModelViewerHtml injection is needed.
        scale: scale,
        autoRotate: true,
        cameraControls: true,
        backgroundColor: AppColors.lightBackground,
      ),
    );
  }
}

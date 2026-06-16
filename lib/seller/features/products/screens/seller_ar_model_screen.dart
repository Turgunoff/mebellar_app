import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_scale.dart';

/// Seller-side 3D viewer for their own QC-approved `.glb` — the same
/// `<model-viewer>` the buyer sees, so the seller previews exactly what
/// shoppers will. Idle auto-rotate + rotate/zoom controls, plus AR
/// ("view in your room"). Uzbek-only with seller tokens, matching the rest of
/// the seller product surface.
///
/// When the product's real dimensions are known the model renders true-to-size
/// in AR (Meshy normalises every mesh, so a per-axis cm→metre multiply restores
/// the real footprint); otherwise it renders unscaled — never crashes on a
/// missing dimension.
class SellerArModelScreen extends StatelessWidget {
  const SellerArModelScreen({
    super.key,
    required this.modelUrl,
    required this.productName,
    this.widthCm,
    this.heightCm,
    this.depthCm,
  });

  final String modelUrl;
  final String productName;
  final num? widthCm;
  final num? heightCm;
  final num? depthCm;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final scale = arScaleString(widthCm, heightCm, depthCm);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.ink),
        title: Text(
          '3D model',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
      ),
      body: ModelViewer(
        src: modelUrl,
        alt: productName,
        ar: true,
        // Lock AR scale to true size so the seller previews the real footprint
        // and can't pinch-resize away from it.
        arScale: scale != null ? ArScale.fixed : null,
        scale: scale,
        autoRotate: true,
        cameraControls: true,
        backgroundColor: c.background,
      ),
    );
  }
}

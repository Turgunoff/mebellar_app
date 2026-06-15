import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';

/// Buyer-side 3D viewer for an approved `.glb`. Wraps `<model-viewer>` with AR
/// ("view in your room"), idle auto-rotate, and full rotate/zoom controls.
class ArViewerScreen extends StatelessWidget {
  const ArViewerScreen({
    super.key,
    required this.modelUrl,
    required this.productName,
  });

  final String modelUrl;
  final String productName;

  @override
  Widget build(BuildContext context) {
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
        autoRotate: true,
        cameraControls: true,
        backgroundColor: AppColors.lightBackground,
      ),
    );
  }
}

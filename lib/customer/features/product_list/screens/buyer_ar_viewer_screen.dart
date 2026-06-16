import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_scale.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/sharing/product_share.dart';

/// Studio backdrop behind the (transparent) model — a near-black radial pool
/// that makes the lit `.glb` pop and reads as a premium product stage. Fixed
/// in both light & dark: the AR viewer is its own immersive surface, not a
/// themed page, so the backdrop never flips.
const Color _kStudioTop = Color(0xFF26242C);
const Color _kStudioBottom = Color(0xFF0D0C10);

/// Immersive, full-screen buyer 3D / AR viewer for an approved `.glb`. Wraps
/// `<model-viewer>` with AR ("view in your room"), idle auto-rotate, and full
/// rotate/zoom controls over a dark studio stage, plus an engaging share
/// prompt that drives the "place it → photograph it → send it" viral loop.
///
/// When the product's real dimensions are known the model is rendered
/// true-to-size in AR ([ArScale.fixed] + a per-axis `scale`): Meshy normalises
/// every mesh into a unit cube, so mapping each axis to the measured cm restores
/// the real footprint — a buyer can't pinch a sofa down to the size of a cat.
/// Missing dimensions degrade gracefully to an unscaled model (never a crash).
class BuyerArViewerScreen extends StatelessWidget {
  const BuyerArViewerScreen({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final scale = arScaleString(
      product.widthCm,
      product.heightCm,
      product.depthCm,
    );
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar glyphs read against the dark studio stage.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _kStudioBottom,
      ),
      child: Scaffold(
        backgroundColor: _kStudioBottom,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.15,
                  colors: [_kStudioTop, _kStudioBottom],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned.fill(
              child: ModelViewer(
                src: product.arModelUrl!,
                alt: product.name,
                ar: true,
                // Prioritised AR launchers — Scene Viewer (Android) and WebXR;
                // Quick Look fires on iOS only when a USDZ is present.
                arModes: const ['scene-viewer', 'webxr', 'quick-look'],
                // Lock AR scale to true size so buyers can't pinch-resize the
                // model and misjudge whether it fits their room.
                arScale: scale != null ? ArScale.fixed : null,
                // Furniture is placed on the floor (horizontal surface).
                arPlacement: ArPlacement.floor,
                // `scale` is the native <model-viewer> attribute ('x y z' metre
                // multipliers); the package exposes it as a typed param, so no
                // JS / innerModelViewerHtml injection is needed.
                scale: scale,
                autoRotate: true,
                cameraControls: true,
                // Neutral IBL gives the model even, showroom-style lighting.
                environmentImage: 'neutral',
                // A grounded contact shadow sells the "it's really here" feel.
                shadowIntensity: 1,
                // Transparent so the studio gradient shows through behind the
                // model instead of a flat fill.
                backgroundColor: Colors.transparent,
                loading: Loading.eager,
              ),
            ),
            _TopBar(productName: product.name, trueScale: scale != null),
            Positioned(
              left: 20,
              right: 20,
              bottom: bottomInset + 92,
              child: const Center(child: _ShareHintCard()),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => shareProduct(product),
          backgroundColor: AppColors.terracotta,
          foregroundColor: Colors.white,
          elevation: 6,
          icon: const Icon(Iconsax.share, size: 20),
          label: Text(
            tr('product.ar_share_cta'),
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Top overlay: a frosted back button, the product name, and a true-scale chip
/// when the model renders at real dimensions. Sits above the model on the dark
/// stage, so its glass + ink are fixed-for-dark (not theme-driven).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.productName, required this.trueScale});

  final String productName;
  final bool trueScale;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _GlassCircleButton(
              icon: Iconsax.arrow_left_2,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Colors.white,
                ),
              ),
            ),
            if (trueScale) ...[
              const SizedBox(width: 10),
              const _TrueScaleChip(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Frosted dark-glass circular icon button — reads on the studio backdrop.
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.14),
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white24, width: 1),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small terracotta "true size" chip — signals the model is shown at the
/// product's real dimensions, the core trust message of the AR feature.
class _TrueScaleChip extends StatelessWidget {
  const _TrueScaleChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.terracotta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.ruler, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            tr('product.ar_true_scale'),
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom glass card with the playful "place it → photograph it → send it"
/// prompt. The actual share affordance is the FAB below it.
class _ShareHintCard extends StatelessWidget {
  const _ShareHintCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Text(
            tr('product.ar_share_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

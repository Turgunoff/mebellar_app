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

/// Clean light "showroom" backdrop behind the model — a flat, premium
/// e-commerce stage (think IKEA/Wayfair) rather than a dark void. Fixed in both
/// light & dark: the AR viewer is its own immersive surface, not a themed page,
/// so the backdrop never flips. The model's own contact shadow + neutral IBL
/// ground it on the light stage.
const Color _kViewerBg = Color(0xFFF4F5F7);
const Color _kInk = Color(0xFF17171C);

/// Immersive, full-screen buyer 3D / AR viewer for an approved `.glb`. Wraps
/// `<model-viewer>` with AR ("view in your room"), idle auto-rotate, and full
/// rotate/zoom controls over a clean light stage, plus a prompt that points the
/// buyer at the model-viewer native AR button and a share CTA for the
/// "place it → photograph it → send it" viral loop.
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
      // Dark glyphs now read against the light stage.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _kViewerBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kViewerBg,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Solid light base — keeps the surface clean (never a black flash)
            // while the model streams in or if the WebView is slow.
            const ColoredBox(color: _kViewerBg, child: SizedBox.expand()),
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
                // A grounded contact shadow sells the "it's really here" feel
                // and reads cleanly on the light stage.
                shadowIntensity: 1,
                // Solid light fill — the model-viewer's own AR button (bottom
                // right) and chrome stay visible against it.
                backgroundColor: _kViewerBg,
                loading: Loading.eager,
              ),
            ),
            _TopBar(productName: product.name, trueScale: scale != null),
            // Instruction sits centred well above the bottom edge; the FAB is
            // centred too. The bottom-RIGHT corner is left deliberately free so
            // the model-viewer native AR button is never overlapped.
            Positioned(
              left: 20,
              right: 20,
              bottom: bottomInset + 96,
              child: const Center(child: _ArHintCard()),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => shareProduct(product),
          backgroundColor: AppColors.terracotta,
          foregroundColor: Colors.white,
          elevation: 4,
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

/// Top overlay: a back button, the product name, and a true-scale chip when the
/// model renders at real dimensions. Restyled for the light stage — solid
/// surfaces + ink, fixed-for-light (not theme-driven).
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
            _CircleIconButton(
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
                  color: _kInk,
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

/// Solid white circular icon button with a soft shadow — reads cleanly on the
/// light stage (was dark glass on the old black backdrop).
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(
        side: BorderSide(color: Color(0x14000000), width: 1),
      ),
      elevation: 2,
      shadowColor: const Color(0x22000000),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: _kInk),
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
        color: AppColors.terracotta,
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

/// Light instruction card pointing the buyer at the model-viewer native AR
/// button (bottom-right of the canvas). White surface + soft shadow + ink so it
/// reads on the clean stage; constrained width so it never reaches the bottom-
/// right corner where the AR button lives.
class _ArHintCard extends StatelessWidget {
  const _ArHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0F000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.box, size: 20, color: AppColors.terracotta),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              tr('product.ar_tap_hint'),
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

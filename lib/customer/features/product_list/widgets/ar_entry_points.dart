import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_scale.dart';
import '../../../../shared/models/product_model.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../screens/buyer_ar_viewer_screen.dart';

/// Buyer-facing AR entry points for the product detail page — the carousel
/// glass badge ([ArGlassBadge]) and the premium action card ([ArPromoCard]).
/// Both funnel into the same full-screen [BuyerArViewerScreen]; render them
/// only when `product.hasAr` (a QC-approved `.glb` exists).

/// Opens the immersive buyer 3D / AR viewer for [product]. Single launch path
/// so every entry point (badge, card) behaves identically. Presented as a
/// full-screen route so it reads as a dedicated, immersive experience.
void openBuyerArViewer(BuildContext context, ProductModel product) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BuyerArViewerScreen(product: product),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Carousel glass badge — frosted "3D / AR" pill on the gallery's bottom-right.
// ═══════════════════════════════════════════════════════════════════════════

/// A floating, frosted-glass pill that advertises the 3D / AR model from the
/// image carousel. Tapping launches the viewer. Colours are deliberately fixed
/// (not theme-driven): the badge floats over the product photo, which is the
/// same in light & dark — exactly like the gallery's existing glass controls.
class ArGlassBadge extends StatelessWidget {
  const ArGlassBadge({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openBuyerArViewer(context, product),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 8, 13, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulsingArCube(size: 18, color: PremiumTokens.accent),
                const SizedBox(width: 7),
                Text(
                  tr('product.ar_badge'),
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    // Fixed dark ink on the fixed white glass over the photo —
                    // shared with PreviewGlassIconButton (overlay-on-photo
                    // exception to the theming rule), so reuse the same token.
                    color: AppColors.sellerInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A subtly pulsing AR cube glyph. The gentle scale loop draws the eye to the
/// 3D affordance without the jitter of a full spin. Self-contained so both the
/// badge and the promo card can reuse it.
class PulsingArCube extends StatefulWidget {
  const PulsingArCube({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<PulsingArCube> createState() => _PulsingArCubeState();
}

class _PulsingArCubeState extends State<PulsingArCube>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.86,
    end: 1.1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(Icons.view_in_ar, size: widget.size, color: widget.color),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Premium action card — high-visibility CTA below the in-stock status.
// ═══════════════════════════════════════════════════════════════════════════

/// The headline AR call-to-action: a premium accent-tinted gradient card with a
/// glowing border, icon, title, subtitle, and an elevated "AR da ko'rish"
/// button. Dark-mode safe via [PremiumTokens]; the accent (terracotta) is a
/// brand constant in both modes.
class ArPromoCard extends StatelessWidget {
  const ArPromoCard({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The viewer only locks AR to true size when all three dimensions are
    // known (arScaleString != null). Match the card's promise to that so it
    // never claims "true size" for a model that renders unscaled.
    final trueScale =
        arScaleString(product.widthCm, product.heightCm, product.depthCm) !=
        null;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [PremiumTokens.accent.withValues(alpha: 0.22), pt.surface]
              : [const Color(0xFFFBEEE8), pt.surface],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PremiumTokens.accent.withValues(alpha: isDark ? 0.45 : 0.30),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumTokens.accent.withValues(alpha: isDark ? 0.20 : 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PromoIconBadge(),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('product.ar_card_title'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: 1.2,
                          color: pt.dark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tr(
                          trueScale
                              ? 'product.ar_card_subtitle'
                              : 'product.ar_card_subtitle_plain',
                        ),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: pt.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => openBuyerArViewer(context, product),
                icon: const Icon(Icons.view_in_ar, size: 20),
                label: Text(tr('product.ar_cta')),
                style: FilledButton.styleFrom(
                  backgroundColor: PremiumTokens.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accent-gradient rounded-square holding the AR glyph — the card's visual
/// anchor.
class _PromoIconBadge extends StatelessWidget {
  const _PromoIconBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PremiumTokens.accent, PremiumTokens.accentDeep],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: PremiumTokens.accent.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(Icons.view_in_ar, size: 24, color: Colors.white),
    );
  }
}

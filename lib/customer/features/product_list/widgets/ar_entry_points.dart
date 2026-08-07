import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_scale.dart';
import '../../../../shared/ar/ar_set_piece.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/product_set.dart';
import '../../../../shared/repositories/woody_set_repository.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../screens/buyer_ar_viewer_screen.dart';
import '../screens/set_ar_viewer_screen.dart';
import '../screens/set_sticker_screen.dart';

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
      settings: const RouteSettings(name: '/buyer-ar-viewer'),
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
    // A garnitur (≥2 model-bearing parts) lands as a whole set in the AR scene,
    // so the card promises that rather than a single piece.
    final multiPart = product.hasMultiPartAr;
    final subtitleKey = multiPart
        ? 'product.set_choice_subtitle'
        : (trueScale
              ? 'product.ar_card_subtitle'
              : 'product.ar_card_subtitle_plain');

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
                        tr(subtitleKey),
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

// ═══════════════════════════════════════════════════════════════════════════
// Furniture set (garnitur) — "view the WHOLE set in your room" entry.
// ═══════════════════════════════════════════════════════════════════════════

/// Fetches the set [setId] (its member products + their approved AR models) and
/// launches the multi-object placement experience: a choice sheet for native
/// true-size 3D AR (every piece independently movable/rotatable) or the
/// universal 2D sticker overlay. A set with no approved model skips straight to
/// 2D; a fetch failure surfaces a soft snackbar — never a dead end.
Future<void> openSetArExperience(
  BuildContext context, {
  required String setId,
  String? setName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  SetDetail? set;
  try {
    set = await sl<WoodySetRepository>().fetchSet(setId);
  } catch (e, st) {
    appLog.handle(e, st, '[set-ar] set fetch failed');
  }
  if (!context.mounted) return;
  navigator.pop(); // dismiss the loader
  if (set == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(tr('product.ar_load_failed'))),
    );
    return;
  }
  final pieces = set.toPieces();
  if (pieces.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(tr('product.set_2d_empty'))));
    return;
  }
  final name = setName ?? set.name;
  // No approved 3D models in the set → AR has nothing to place; go to 2D.
  if (!pieces.any((p) => p.hasModel)) {
    _pushSetSticker(navigator, pieces, name);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => _SetChoiceSheet(
      onPick3d: () {
        Navigator.of(sheetCtx).pop();
        _pushSetAr(navigator, pieces, name);
      },
      onPick2d: () {
        Navigator.of(sheetCtx).pop();
        _pushSetSticker(navigator, pieces, name);
      },
    ),
  );
}

void _pushSetAr(
  NavigatorState navigator,
  List<ArSetPiece> pieces,
  String name,
) {
  navigator.push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/set-ar-viewer'),
      fullscreenDialog: true,
      builder: (_) => SetArViewerScreen(pieces: pieces, setName: name),
    ),
  );
}

void _pushSetSticker(
  NavigatorState navigator,
  List<ArSetPiece> pieces,
  String name,
) {
  navigator.push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/set-sticker'),
      fullscreenDialog: true,
      builder: (_) => SetStickerScreen(pieces: pieces, setName: name),
    ),
  );
}

/// Compact CTA shown on a product's detail page when it belongs to a set —
/// launches the whole-set AR / 2D experience. Render only when
/// `product.hasSet`.
class SetArPromoCard extends StatelessWidget {
  const SetArPromoCard({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: pt.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: product.setId == null
            ? null
            : () => openSetArExperience(context, setId: product.setId!),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PremiumTokens.accent.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.d_cube_scan,
                  size: 22,
                  color: PremiumTokens.accent,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('product.set_view_in_room'),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: pt.dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('product.set_choice_subtitle'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: pt.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Iconsax.arrow_right_3_copy,
                size: 18,
                color: pt.grey.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for the set experience: native true-size 3D AR vs the universal
/// 2D camera overlay.
class _SetChoiceSheet extends StatelessWidget {
  const _SetChoiceSheet({required this.onPick3d, required this.onPick2d});

  final VoidCallback onPick3d;
  final VoidCallback onPick2d;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: pt.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                tr('product.set_choice_title'),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: pt.dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('product.set_choice_subtitle'),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: pt.grey,
                ),
              ),
              const SizedBox(height: 22),
              _SetChoiceOption(
                icon: Iconsax.d_cube_scan,
                title: tr('product.ar_choice_3d_title'),
                subtitle: tr('product.ar_choice_3d_subtitle'),
                highlighted: true,
                onTap: onPick3d,
              ),
              const SizedBox(height: 12),
              _SetChoiceOption(
                icon: Iconsax.camera,
                title: tr('product.ar_choice_2d_title'),
                subtitle: tr('product.ar_choice_2d_subtitle'),
                highlighted: false,
                onTap: onPick2d,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetChoiceOption extends StatelessWidget {
  const _SetChoiceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    const accent = PremiumTokens.accent;
    return Material(
      color: highlighted ? accent.withValues(alpha: 0.07) : pt.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlighted
              ? accent.withValues(alpha: 0.5)
              : pt.grey.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: highlighted ? accent : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: highlighted ? Colors.white : accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: pt.dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: pt.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Iconsax.arrow_right_3_copy,
                size: 18,
                color: pt.grey.withValues(alpha: 0.7),
              ),
            ],
          ),
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';

const double _kCoverHeight = 124;
const double _kAvatarSize = 84;
const double _kAvatarOverlap = _kAvatarSize / 2;

/// Hero card mirroring the seller-profile identity card: wide cover banner,
/// a centred overlapping logo with a camera badge, and an upload pill on the
/// cover. Tapping either image opens its picker (then the crop step).
class CoverHeader extends StatelessWidget {
  const CoverHeader({
    super.key,
    required this.coverUrl,
    required this.logoUrl,
    required this.uploadingKind,
    required this.onTapCover,
    required this.onTapLogo,
  });

  final String? coverUrl;
  final String? logoUrl;
  final String? uploadingKind;
  final VoidCallback onTapCover;
  final VoidCallback onTapLogo;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.28 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // The Stack's own height includes the avatar's overhang — children
          // outside a Stack's bounds render but never receive taps, which is
          // exactly the "can't tap the logo" bug the old negative-bottom
          // Positioned had.
          SizedBox(
            height: _kCoverHeight + _kAvatarOverlap + 6,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _kCoverHeight,
                  child: _CoverImage(
                    url: coverUrl,
                    uploading: uploadingKind == 'cover',
                    onTap: onTapCover,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _CoverEditPill(onTap: onTapCover),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: _LogoAvatar(
                      url: logoUrl,
                      uploading: uploadingKind == 'logo',
                      onTap: onTapLogo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              tr('shop_settings.upload_logo'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.grey,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.url,
    required this.uploading,
    required this.onTap,
  });

  final String? url;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = url == null || url!.isEmpty;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: _kCoverHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (empty)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.sellerPrimary,
                      AppColors.sellerPrimaryDeep,
                    ],
                  ),
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: url!,
                memCacheWidth: 1080,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.sellerPrimary,
                        AppColors.sellerPrimaryDeep,
                      ],
                    ),
                  ),
                ),
              ),
            if (empty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.gallery_add,
                      size: 26,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('shop_settings.upload_cover'),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),
            if (uploading)
              const ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverEditPill extends StatelessWidget {
  const _CoverEditPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.camera, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                tr('shop_settings.upload_cover'),
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({
    required this.url,
    required this.uploading,
    required this.onTap,
  });

  final String? url;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        // Extra room so the camera badge isn't clipped by the Stack.
        width: _kAvatarSize + 8,
        height: _kAvatarSize + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _kAvatarSize,
              height: _kAvatarSize,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: c.neutralBg,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url == null || url!.isEmpty)
                      const Center(
                        child: Icon(
                          Iconsax.shop,
                          size: 30,
                          color: AppColors.sellerPrimary,
                        ),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: url!,
                        memCacheWidth: 240,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const Center(
                          child: Icon(
                            Iconsax.shop,
                            size: 30,
                            color: AppColors.sellerPrimary,
                          ),
                        ),
                      ),
                    if (uploading)
                      const ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.sellerPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 2.5),
                ),
                child: const Icon(
                  Iconsax.camera,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

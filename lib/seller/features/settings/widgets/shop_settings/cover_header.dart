import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'settings_form_kit.dart';

/// Full-width shop cover image with an overlapping circular logo avatar and a
/// "change logo" button.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _CoverImage(
                url: coverUrl,
                uploading: uploadingKind == 'cover',
                onTap: onTapCover,
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _CoverEditPill(onTap: onTapCover),
              ),
              Positioned(
                left: 12,
                bottom: 0,
                child: _LogoAvatar(
                  url: logoUrl,
                  uploading: uploadingKind == 'logo',
                  onTap: onTapLogo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: _ChangeLogoButton(onTap: onTapLogo),
        ),
      ],
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
    return Positioned.fill(
      bottom: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Material(
              color: kFillSoft,
              child: InkWell(
                onTap: onTap,
                child: url == null || url!.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Iconsax.gallery_add,
                              size: 28,
                              color: kGreyMid,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr('shop_settings.upload_cover'),
                              style: const TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kGrey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: url!,
                        // ROADMAP B.7 — full-width shop cover banner.
                        memCacheWidth: 1080,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            const ColoredBox(color: kFillSoft),
                      ),
              ),
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
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.camera, size: 14, color: kInk),
              const SizedBox(width: 6),
              Text(
                tr('shop_settings.upload_cover'),
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kInk,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: kFillSoft,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null || url!.isEmpty)
                const Center(
                  child: Icon(
                    Iconsax.shop,
                    size: 28,
                    color: AppColors.terracotta,
                  ),
                )
              else
                CachedNetworkImage(
                  imageUrl: url!,
                  // ROADMAP B.7 — 80px shop-logo avatar.
                  memCacheWidth: 240,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(
                      Iconsax.shop,
                      size: 28,
                      color: AppColors.terracotta,
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
    );
  }
}

class _ChangeLogoButton extends StatelessWidget {
  const _ChangeLogoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kOutline, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Iconsax.camera,
                  size: 16,
                  color: AppColors.terracotta,
                ),
                const SizedBox(width: 8),
                Text(
                  tr('shop_settings.upload_logo'),
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.terracotta,
                    letterSpacing: -0.1,
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

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../shared/utils/phone_format.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/profile_cubit.dart';

/// Hero tag shared between the profile-card avatar and the fullscreen viewer,
/// so tapping the avatar flies it open. Single image → suffix `-0` to match
/// [FullscreenImageViewer]'s `<prefix>-<index>` convention.
const String kProfileAvatarHeroTag = 'profile-avatar-0';

/// Identity card at the top of the profile screen — avatar, name, the login
/// phone and an edit affordance. Tapping the avatar opens it fullscreen;
/// tapping anywhere else on the card edits the profile.
class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.profile,
    required this.onEdit,
    required this.onAvatarTap,
  });

  final ProfileState profile;
  final VoidCallback onEdit;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final secondary = profile.secondaryLine;

    return Material(
      color: pt.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: pt.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: PremiumTokens.softShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Hero(
                  tag: kProfileAvatarHeroTag,
                  child: ProfileAvatar(
                    avatarUrl: profile.avatarUrl,
                    name: profile.hasName ? profile.name : null,
                    size: 58,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.displayName,
                      style: PremiumTokens.display(
                        size: 18,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondary != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Iconsax.call, size: 13, color: pt.grey),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              formatUzPhone(secondary),
                              style: PremiumTokens.body(
                                size: 13,
                                color: pt.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Visual affordance only — the enclosing InkWell carries the tap.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.edit_2,
                  size: 18,
                  color: PremiumTokens.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round avatar with fallbacks: a freshly-picked local file, then the cached
/// network image, then the user's initials on a brand gradient, then a generic
/// user glyph. Pass the full [name]; initials are derived from it (null name →
/// user glyph). [localImage] (an unsaved pick) takes precedence over everything.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.localImage,
    this.size = 58,
  });

  final String? avatarUrl;
  final String? name;
  final File? localImage;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    if (localImage != null) {
      return ClipOval(
        child: Image.file(
          localImage!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    if (!hasAvatar) return _gradient(context);

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          memCacheWidth: (size * 3).round(),
          fit: BoxFit.cover,
          placeholder: (_, _) => ColoredBox(color: pt.imageBg),
          errorWidget: (_, _, _) => _gradient(context),
        ),
      ),
    );
  }

  Widget _gradient(BuildContext context) {
    final initials = (name != null && name!.trim().isNotEmpty)
        ? _initialsOf(name!)
        : null;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [PremiumTokens.accent, PremiumTokens.accentDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: initials != null
          ? Text(
              initials,
              style: PremiumTokens.display(
                size: size * 0.34,
                color: Colors.white,
                letterSpacing: 0,
              ),
            )
          : Icon(Iconsax.user, color: Colors.white, size: size * 0.42),
    );
  }
}

String _initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
}

/// Shimmer placeholder shown while the profile row is loading.
class UserCardShimmer extends StatelessWidget {
  const UserCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: const Color(0xFFF5F5F5),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: PremiumTokens.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 18,
                    width: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 13,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

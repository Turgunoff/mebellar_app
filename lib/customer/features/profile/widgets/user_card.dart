import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/profile_cubit.dart';

/// Identity card at the top of the profile screen — avatar, name, secondary
/// line and an inline edit affordance.
class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.profile, required this.onEdit});

  final ProfileState profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final hasAvatar =
        profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 64,
              height: 64,
              child: hasAvatar
                  ? CachedNetworkImage(
                      imageUrl: profile.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: pt.imageBg),
                      errorWidget: (_, _, _) => const _AvatarFallback(),
                    )
                  : const _AvatarFallback(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.displayName,
                        style: PremiumTokens.display(
                          size: 20,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkResponse(
                      onTap: onEdit,
                      radius: 18,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Iconsax.edit_2, size: 16, color: pt.grey),
                      ),
                    ),
                  ],
                ),
                if (profile.secondaryLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.secondaryLine!,
                    style: PremiumTokens.body(size: 13, color: pt.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ColoredBox(
      color: pt.imageBg,
      child: Icon(Iconsax.user, color: pt.greyLight),
    );
  }
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: PremiumTokens.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
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

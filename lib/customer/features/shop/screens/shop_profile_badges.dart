part of 'shop_profile_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Achievement trust badges — the seller's unlocked milestones, rendered as a
// horizontal row of compact gold medallions. Tapping one opens a bottom sheet
// explaining what the badge means. Social proof for the buyer.
// ═══════════════════════════════════════════════════════════════════════════

/// Fixed gold accent for the medallions — a brand/status colour that, like the
/// terracotta accent, stays constant across light/dark rather than flipping.
const Color _kBadgeGold = Color(0xFFE6B23E);
const Color _kBadgeGoldDeep = Color(0xFFC8902A);

/// Maps a backend achievement icon token to an Iconsax glyph. Mirrors the
/// seller dashboard's `achievementIcon`; kept local so customer code doesn't
/// reach into the seller feature. Unknown tokens fall back to a medal so a new
/// server-side achievement still renders without an app update.
IconData achievementBadgeIcon(String token) => switch (token) {
  'medal' => Iconsax.medal_star,
  'crown' => Iconsax.crown_1,
  'cup' => Iconsax.cup,
  'box' => Iconsax.box,
  'box_tick' => Iconsax.box_tick,
  'wallet' => Iconsax.wallet_check,
  'star' => Iconsax.star_1,
  'flash' => Iconsax.flash_1,
  _ => Iconsax.medal_star,
};

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.achievements, required this.accent});

  final List<ShopAchievement> achievements;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionTitle(text: 'Yutuqlar', accent: accent),
              const SizedBox(width: 8),
              Icon(Iconsax.medal_star, size: 15, color: _kBadgeGoldDeep),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: achievements.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) =>
                  _BadgeChip(achievement: achievements[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable medallion + its short title underneath.
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.achievement});

  final ShopAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showAchievementSheet(context, achievement),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Medallion(icon: achievementBadgeIcon(achievement.icon)),
            const SizedBox(height: 7),
            Text(
              achievement.titleUz,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: _ts(
                size: 11,
                weight: FontWeight.w600,
                height: 1.15,
                color: pt.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular gold gradient badge with a soft glow — the visual anchor of a
/// trust badge. Reused at two sizes (row chip + bottom-sheet hero).
class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon, this.size = 56});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBadgeGold, _kBadgeGoldDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: _kBadgeGoldDeep.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.42, color: Colors.white),
    );
  }
}

/// Opens a translucent-scrim bottom sheet describing the tapped achievement.
Future<void> _showAchievementSheet(
  BuildContext context,
  ShopAchievement achievement,
) {
  final pt = PremiumTokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _AchievementSheet(achievement: achievement, tokens: pt),
  );
}

class _AchievementSheet extends StatelessWidget {
  const _AchievementSheet({required this.achievement, required this.tokens});

  final ShopAchievement achievement;
  final PremiumTokens tokens;

  @override
  Widget build(BuildContext context) {
    final pt = tokens;
    final description = (achievement.descriptionUz ?? '').trim();
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: PremiumTokens.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: pt.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 22),
            _Medallion(icon: achievementBadgeIcon(achievement.icon), size: 76),
            const SizedBox(height: 18),
            Text(
              achievement.titleUz,
              textAlign: TextAlign.center,
              style: _ts(
                size: 18,
                weight: FontWeight.w800,
                letterSpacing: -0.3,
                color: pt.dark,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: _ts(size: 13.5, height: 1.5, color: pt.grey),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _kBadgeGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.verify, size: 15, color: _kBadgeGoldDeep),
                  const SizedBox(width: 6),
                  Text(
                    'Qo\'lga kiritilgan nishon',
                    style: _ts(
                      size: 12,
                      weight: FontWeight.w700,
                      color: _kBadgeGoldDeep,
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

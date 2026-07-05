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

/// Maps a backend achievement icon name to a FontAwesome glyph. Mirrors the
/// seller dashboard's `achievementIcon`; kept local so customer code doesn't
/// reach into the seller feature. Unknown names fall back to a trophy so a new
/// server-side achievement still renders without an app update.
FaIconData achievementBadgeIcon(String name) => switch (name) {
  'box' => FontAwesomeIcons.box,
  'boxes-stacked' => FontAwesomeIcons.boxesStacked,
  'award' => FontAwesomeIcons.award,
  'trophy' => FontAwesomeIcons.trophy,
  'medal' => FontAwesomeIcons.medal,
  'money-bill-wave' => FontAwesomeIcons.moneyBillWave,
  'wand-magic-sparkles' => FontAwesomeIcons.wandMagicSparkles,
  'cubes' => FontAwesomeIcons.cubes,
  'bolt' => FontAwesomeIcons.bolt,
  'star' => FontAwesomeIcons.star,
  'couch' => FontAwesomeIcons.couch,
  'crown' => FontAwesomeIcons.crown,
  // Legacy Iconsax-era tokens (pre-rebuild cached data).
  'cup' => FontAwesomeIcons.trophy,
  'box_tick' => FontAwesomeIcons.boxesStacked,
  'wallet' => FontAwesomeIcons.wallet,
  'flash' => FontAwesomeIcons.bolt,
  _ => FontAwesomeIcons.trophy,
};

/// Buyer-facing title for a public trust badge. Falls back to the catalogue
/// title when [code] is unknown (shouldn't happen for [_kPublicBadgeCodes]).
String publicBadgeTitle(String code, ShopAchievement achievement, String lang) {
  final key = 'shop.badge_${code}_title';
  final localized = tr(key);
  if (localized != key) return localized;
  return achievement.localizedTitle(lang);
}

/// Buyer-facing blurb — never the seller-dashboard `reward_*` copy.
String publicBadgeDescription(String code) {
  return tr('shop.badge_${code}_desc');
}

/// The only milestones a buyer sees — high-value SOCIAL PROOF badges that build
/// trust. Internal/administrative milestones (product-count tiers, etc.) are
/// deliberately excluded so the shop header stays meaningful to shoppers.
const Set<String> _kPublicBadgeCodes = {
  'first_sale', // Faol sotuvchi
  'high_revenue', // Ishonchli hamkor
  'top_rated', // Mijozlar yoqimtoyi
  'fast_processor', // Chaqmoq
  'ar_master', // Virtual Ko'rgazma
};

/// Horizontal strip of trust badges shown in the shop header — directly under
/// the verified subtitle, above the stats card. Filters the seller's unlocked
/// milestones to [_kPublicBadgeCodes], renders each as a terracotta medallion,
/// and opens the localized reward sheet on tap. Renders nothing when the seller
/// has earned none of the public milestones, so the header stays clean.
class ShopProfileBadgesRow extends StatelessWidget {
  const ShopProfileBadgesRow({super.key, required this.achievements});

  final List<ShopAchievement> achievements;

  @override
  Widget build(BuildContext context) {
    // Keep the catalogue's sort order; just drop non-public milestones.
    final public = achievements
        .where((a) => _kPublicBadgeCodes.contains(a.code))
        .toList(growable: false);
    if (public.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: public.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _BadgePill(
            achievement: public[i],
            // Stagger each badge's entrance so the strip animates in on load.
            index: i,
          ),
        ),
      ),
    );
  }
}

/// One circular terracotta trust badge. Fades + pops in on load (staggered by
/// [index]); tapping opens the localized reward sheet.
class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.achievement, required this.index});

  final ShopAchievement achievement;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 90),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.8 + 0.2 * t.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: Semantics(
        button: true,
        label: publicBadgeTitle(
          achievement.code,
          achievement,
          context.locale.languageCode,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showAchievementSheet(context, achievement),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PremiumTokens.accent,
                    PremiumTokens.accent.withValues(alpha: 0.82),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: PremiumTokens.accent.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FaIcon(
                achievementBadgeIcon(achievement.icon),
                size: 21,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular gold gradient badge with a soft glow — the bottom-sheet hero anchor.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon, this.size = 56});

  final FaIconData icon;
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
      child: FaIcon(icon, size: size * 0.42, color: Colors.white),
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
    final lang = context.locale.languageCode;
    final title = publicBadgeTitle(achievement.code, achievement, lang);
    final description = publicBadgeDescription(achievement.code);
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
              title,
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
                    tr('shop.earned_badge'),
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

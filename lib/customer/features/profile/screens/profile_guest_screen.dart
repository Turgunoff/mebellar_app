import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../auth/auth_bottom_sheet.dart';
import '../../../../seller/features/onboarding/screens/onboarding_screen.dart';
import '../../../widgets/glass_bottom_nav.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import 'about_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

/// Premium guest (unauthenticated) profile screen.
///
/// Sibling to [ProfileScreen]: same bones — header, soft cards, glass
/// nav allowance — but the identity block is replaced by a value-prop hero
/// that funnels into Sign In / Sign Up. The generic menu (Settings / Help /
/// About) stays available so logged-out users can still reach things they
/// don't need an account for.
class ProfileGuestScreen extends StatelessWidget {
  const ProfileGuestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ColoredBox(
      color: pt.background,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            GlassBottomNav.reservedHeight(context) + 24,
          ),
          children: [
            const _GuestHeader(),
            const SizedBox(height: 24),
            _WelcomeHeroCard(
              onContinue: () => showAuthBottomSheet(context),
            ),
            const SizedBox(height: 24),
            _GuestMenuListCard(
              items: _guestMenuItems(context),
              onSell: () => _openSellerOnboarding(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openSellerOnboarding(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _GuestHeader extends StatelessWidget {
  const _GuestHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
      child: Text(
        'Profil',
        style: PremiumTokens.display(size: 32, letterSpacing: -0.6),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome hero card (icon + value prop + CTAs)
// ---------------------------------------------------------------------------

class _WelcomeHeroCard extends StatelessWidget {
  const _WelcomeHeroCard({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        children: [
          // Line-art identity icon inside a soft grey halo.
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: pt.imageBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: pt.divider,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Iconsax.user,
              size: 40,
              color: pt.dark,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Xush kelibsiz!',
            textAlign: TextAlign.center,
            style: PremiumTokens.display(size: 24, letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          Text(
            "Buyurtmalarni boshqarish va do'koningiz savdosini "
            "kuzatish uchun tizimga kiring yoki ro'yxatdan o'ting.",
            textAlign: TextAlign.center,
            style: PremiumTokens.body(
              size: 14,
              color: pt.grey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryCta(label: 'Davom etish', onTap: onContinue),
        ],
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: PremiumTokens.accent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: PremiumTokens.body(
                size: 15,
                weight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu list — same visual language as the authenticated profile so a sign-in
// transition doesn't restructure the layout, only swap the hero block.
// ---------------------------------------------------------------------------

class _GuestMenuListCard extends StatelessWidget {
  const _GuestMenuListCard({required this.items, required this.onSell});

  final List<_MenuEntry> items;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.softShadow,
      ),
      // ClipRRect lets the seller-acquisition row's tinted background hug
      // the card's rounded corners without bleeding past the edge.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _SellOnWoodyRow(onTap: onSell),
            Divider(height: 1, color: pt.divider),
            for (var i = 0; i < items.length; i++) ...[
              _MenuRow(entry: items[i]),
              if (i != items.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Divider(height: 1, color: pt.divider),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Seller-acquisition CTA pinned to the top of the guest menu.
///
/// Visual treatment is intentionally louder than the surrounding settings
/// rows — Terracotta-tinted background, bold title, subtitle copy, and a
/// brand-colored chevron — because guests who happen to be furniture sellers
/// would otherwise have no obvious entry point into the seller flow.
class _SellOnWoodyRow extends StatelessWidget {
  const _SellOnWoodyRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: PremiumTokens.accent.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront,
                  size: 20,
                  color: PremiumTokens.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Woody'da soting",
                      style: PremiumTokens.body(
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Biznesingizni minglab xaridorlarga yetkazing',
                      style: PremiumTokens.body(
                        size: 12,
                        color: pt.grey,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: PremiumTokens.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: pt.imageBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(entry.icon, size: 18, color: pt.dark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  entry.label,
                  style: PremiumTokens.body(
                    size: 14,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: pt.greyLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mock data
// ---------------------------------------------------------------------------

class _MenuEntry {
  const _MenuEntry({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

List<_MenuEntry> _guestMenuItems(BuildContext context) => [
      _MenuEntry(
        icon: Iconsax.setting_2,
        label: 'Sozlamalar',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      _MenuEntry(
        icon: Iconsax.message_question,
        label: "Yordam va Qo'llab-quvvatlash",
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HelpScreen()),
        ),
      ),
      _MenuEntry(
        icon: Iconsax.info_circle,
        label: 'Ilova haqida',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        ),
      ),
    ];

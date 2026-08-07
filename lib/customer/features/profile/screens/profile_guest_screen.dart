import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../auth/auth_bottom_sheet.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/notifications/push_service.dart';
import '../../../../core/widgets/safe_showcase.dart';
import '../../../../seller/features/onboarding/screens/onboarding_screen.dart';
import '../../../customer_app.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../shared/about/about_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

/// First-launch spotlight flag — shown once when the guest opens the Profile
/// tab so the seller-acquisition row is discoverable.
const String _kSeenSellOnWoodyShowcasePrefKey =
    'has_seen_sell_on_woody_showcase';

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
    return ShowCaseWidget(builder: (context) => const _ProfileGuestView());
  }
}

class _ProfileGuestView extends StatefulWidget {
  const _ProfileGuestView();

  @override
  State<_ProfileGuestView> createState() => _ProfileGuestViewState();
}

class _ProfileGuestViewState extends State<_ProfileGuestView> {
  final GlobalKey _sellRowKey = GlobalKey();
  int? _lastTabIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final index = CustomerShellScope.of(context).index;
    if (index == 4 && _lastTabIndex != 4) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_maybeStartSellShowcase()),
      );
    }
    _lastTabIndex = index;
  }

  Future<void> _maybeStartSellShowcase() async {
    if (CustomerShellScope.of(context).index != 4) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kSeenSellOnWoodyShowcasePrefKey) ?? false) return;
    if (!mounted) return;
    await safeStartShowCase(context, [_sellRowKey]);
    await prefs.setBool(_kSeenSellOnWoodyShowcasePrefKey, true);
  }

  void _openSellerOnboarding(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/onboarding'),
        builder: (_) => const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          tr('profile.title'),
          style: PremiumTokens.display(size: 28, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _WelcomeHeroCard(onContinue: () => showAuthScreen(context)),
          const SizedBox(height: 24),
          _GuestMenuListCard(
            items: _guestMenuItems(context),
            sellRowKey: _sellRowKey,
            onSell: () => _openSellerOnboarding(context),
          ),
        ],
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
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: pt.imageBg,
              shape: BoxShape.circle,
              border: Border.all(color: pt.divider, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(Iconsax.user, size: 40, color: pt.dark),
          ),
          const SizedBox(height: 20),
          Text(
            tr('profile.guest_welcome_title'),
            textAlign: TextAlign.center,
            style: PremiumTokens.display(size: 24, letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          Text(
            tr('profile.guest_welcome_body'),
            textAlign: TextAlign.center,
            style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.5),
          ),
          const SizedBox(height: 24),
          _PrimaryCta(label: tr('profile.continue'), onTap: onContinue),
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
  const _GuestMenuListCard({
    required this.items,
    required this.sellRowKey,
    required this.onSell,
  });

  final List<_MenuEntry> items;
  final GlobalKey sellRowKey;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _SellOnWoodyRow(showcaseKey: sellRowKey, onTap: onSell),
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
class _SellOnWoodyRow extends StatelessWidget {
  const _SellOnWoodyRow({required this.showcaseKey, required this.onTap});

  final GlobalKey showcaseKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final row = Material(
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
                      tr('profile.sell_on_woody_title'),
                      style: PremiumTokens.body(
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('profile.sell_on_woody_subtitle'),
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
                Iconsax.arrow_right_3_copy,
                size: 22,
                color: PremiumTokens.accent,
              ),
            ],
          ),
        ),
      ),
    );

    return Showcase(
      key: showcaseKey,
      title: tr('profile.sell_on_woody_showcase_title'),
      description: tr('profile.sell_on_woody_showcase_desc'),
      targetShapeBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      targetPadding: const EdgeInsets.all(4),
      tooltipBackgroundColor: pt.surface,
      textColor: pt.dark,
      tooltipBorderRadius: BorderRadius.circular(16),
      titleTextStyle: PremiumTokens.display(size: 16, letterSpacing: -0.2),
      descTextStyle: PremiumTokens.body(size: 13, height: 1.4, color: pt.grey),
      onTargetClick: onTap,
      disposeOnTap: true,
      child: row,
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
                  style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
                ),
              ),
              Icon(Iconsax.arrow_right_3_copy, size: 20, color: pt.greyLight),
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
    label: tr('profile.menu_settings'),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/settings'),
        builder: (_) => SettingsScreen(
          authRepository: sl<AuthRepository>(),
          pushService: sl.isRegistered<PushService>()
              ? sl<PushService>()
              : null,
        ),
      ),
    ),
  ),
  _MenuEntry(
    icon: Iconsax.message_question,
    label: tr('profile.help_title'),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/help'),
        builder: (_) => const HelpScreen(),
      ),
    ),
  ),
  _MenuEntry(
    icon: Iconsax.info_circle,
    label: tr('profile.menu_about'),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/about'),
        builder: (_) => const AboutScreen(),
      ),
    ),
  ),
];

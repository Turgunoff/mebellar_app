import 'package:flutter/material.dart';
import '../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../config/app_mode.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/repositories/notifications_repository.dart';
import '../../../shared/widgets/notifications_screen.dart';
import '../reviews/screens/reviews_screen.dart';
import '../settings/screens/services_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../settings/screens/shop_settings_screen.dart';
import '../tariff/screens/tariff_screen.dart';

// Local tokens — kept here so the screen reads top-to-bottom without
// chasing theme indirection. Plus Jakarta Sans is applied to every
// `Text` explicitly via `AppFonts.seller` so the surface
// is immune to theme regressions and the M3 surface tint that the
// teal seller seed otherwise bleeds onto neutral backgrounds.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _divider = Color(0xFFEFEFEF);
const _avatarBg = Color(0xFFEDEDED);
const _verifiedBg = Color(0xFFDCF1E5);
const _verifiedFg = Color(0xFF1F6B49);
const _gold = Color(0xFFD4A017);

class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _ProfileHeaderBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  const _ProfileIdentity(shopName: 'Archa Design'),
                  const SizedBox(height: 24),
                  _SectionLabel(text: "Do'konni boshqarish"),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    items: [
                      _SettingsItem(
                        icon: Iconsax.shop,
                        title: "Do'kon sozlamalari",
                        subtitle: "Logo, ish vaqti, ko'rinish",
                        onTap: () => _push(context, const ShopSettingsScreen()),
                      ),
                      _SettingsItem(
                        icon: Iconsax.truck_fast,
                        title: "Do'kon xizmatlari",
                        subtitle: 'Yetkazib berish, kafolat',
                        onTap: () =>
                            _push(context, const SellerServicesScreen()),
                      ),
                      _SettingsItem(
                        icon: Iconsax.messages_2,
                        title: 'Sharhlar va Baholar',
                        subtitle: 'Mijozlar fikri va javoblar',
                        onTap: () => _push(context, const ReviewsScreen()),
                      ),
                      _SettingsItem(
                        icon: Iconsax.crown_1,
                        iconColor: _gold,
                        title: 'Tarif',
                        subtitle: 'Joriy tarif: Pro',
                        onTap: () => _push(context, const TariffScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(text: 'Ilova sozlamalari'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    items: [
                      _SettingsItem(
                        icon: Iconsax.notification,
                        title: 'Bildirishnomalar',
                        onTap: () => _push(
                          context,
                          const NotificationsScreen(mode: AppMode.seller),
                        ),
                      ),
                      _SettingsItem(
                        icon: Iconsax.setting_2,
                        title: 'Sozlamalar',
                        subtitle: 'Til, mavzu va bildirishnomalar',
                        onTap: () => _push(context, const SettingsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(text: 'Harakatlar'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    items: [
                      _SettingsItem(
                        icon: Iconsax.user_octagon,
                        iconColor: AppColors.terracotta,
                        title: 'Xaridor rejimi',
                        titleColor: AppColors.terracotta,
                        onTap: () => switchAppMode(context, AppMode.customer),
                      ),
                      _SettingsItem(
                        icon: Iconsax.logout,
                        iconColor: _logoutRed,
                        title: 'Chiqish',
                        titleColor: _logoutRed,
                        showTrailing: false,
                        onTap: () => performLogout(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

final Color _logoutRed = Colors.red.shade600;

// =============================================================================
// 1. Header — "Profil" title + borderless Iconsax bell with terracotta badge
// =============================================================================
class _ProfileHeaderBar extends StatelessWidget {
  const _ProfileHeaderBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBackground,
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr('profile.title'),
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(mode: AppMode.seller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = sl.isRegistered<NotificationsRepository>()
        ? sl<NotificationsRepository>().watchUnread(mode: AppMode.seller.name)
        : const Stream<int>.empty();

    return StreamBuilder<int>(
      stream: stream,
      initialData: sl.isRegistered<NotificationsRepository>()
          ? sl<NotificationsRepository>().unreadCount(mode: AppMode.seller.name)
          : 0,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(Iconsax.notification, size: 24, color: _ink),
                  if (count > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.terracotta,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: AppColors.lightBackground,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: TextStyle(fontFamily: AppFonts.seller, 
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 2. Identity card — large avatar, shop name, "Verified seller" pill
// =============================================================================
class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.shopName});

  final String shopName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: _avatarBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Iconsax.shop,
            size: 36,
            color: AppColors.terracotta,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          shopName,
          style: TextStyle(fontFamily: AppFonts.seller, 
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const _VerifiedBadge(),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _verifiedBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.tick_circle, size: 13, color: _verifiedFg),
          const SizedBox(width: 5),
          Text(
            'Tasdiqlangan sotuvchi',
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _verifiedFg,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 3. Section label — small all-caps style above each grouped card
// =============================================================================
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(fontFamily: AppFonts.seller, 
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _grey,
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
  }
}

// =============================================================================
// 4. Grouped settings card — pure white, soft shadow, hairline dividers
// =============================================================================
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});

  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(items[i]);
      if (i < items.length - 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.only(left: 60),
            child: Divider(height: 1, thickness: 1, color: _divider),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

// =============================================================================
// 5. Settings row — leading icon tile, title + optional subtitle, chevron
// =============================================================================
class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.showTrailing = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;
  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor ?? _ink),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? _ink,
                        letterSpacing: -0.1,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontFamily: AppFonts.seller, 
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _grey,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showTrailing) ...[
                const SizedBox(width: 8),
                const Icon(Iconsax.arrow_right_3, size: 18, color: _greyMid),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../config/app_mode.dart';
import '../../../config/remote_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../shared/models/tariff.dart';
import '../../../shared/models/verification_status.dart';
import '../../../shared/widgets/brand_refresh_indicator.dart';
import '../reviews/screens/reviews_screen.dart';
import '../settings/screens/services_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../settings/screens/shop_settings_screen.dart';
import '../tariff/screens/tariff_screen.dart';
import 'cubit/seller_profile_cubit.dart';

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
const _pendingBg = Color(0xFFFFF1D6);
const _pendingFg = Color(0xFF8A5A00);
const _rejectedBg = Color(0xFFFCE4E4);
const _rejectedFg = Color(0xFFB42318);
const _neutralBadgeBg = Color(0xFFEFEFEF);
const _neutralBadgeFg = Color(0xFF6B6B6B);
const _gold = Color(0xFFD4A017);

class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerProfileCubit>(
      create: (_) => sl<SellerProfileCubit>()..load(),
      child: const _SellerProfileView(),
    );
  }
}

class _SellerProfileView extends StatelessWidget {
  const _SellerProfileView();

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
              child: BrandRefreshIndicator(
                color: AppColors.sellerPrimary,
                onRefresh: () => context.read<SellerProfileCubit>().load(),
                child: BlocBuilder<SellerProfileCubit, SellerProfileState>(
                  builder: (context, state) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: [
                        _ProfileIdentity(state: state),
                        const SizedBox(height: 24),
                        const _SectionLabel(text: "Do'konni boshqarish"),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Iconsax.shop,
                              title: "Do'kon sozlamalari",
                              subtitle: "Logo, ish vaqti, ko'rinish",
                              onTap: () =>
                                  _push(context, const ShopSettingsScreen()),
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
                              onTap: () =>
                                  _push(context, const ReviewsScreen()),
                            ),
                            // Tariff is hidden while the tariff system is
                            // switched off (RemoteConfig.tariffEnabled).
                            if (RemoteConfig.instance.tariffEnabled)
                              _SettingsItem(
                                icon: Iconsax.crown_1,
                                iconColor: _gold,
                                title: 'Tarif',
                                subtitle: _planSubtitle(state),
                                onTap: () =>
                                    _push(context, const TariffScreen()),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const _SectionLabel(text: 'Ilova sozlamalari'),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Iconsax.message,
                              title: 'Suhbatlar',
                              subtitle: 'Mijozlar bilan yozishuvlar',
                              onTap: () => context.push('/seller/chats'),
                            ),
                            // Bildirishnomalar entry removed — the dashboard
                            // bell icon is the canonical entry point, so this
                            // row was redundant.
                            _SettingsItem(
                              icon: Iconsax.setting_2,
                              title: 'Sozlamalar',
                              subtitle: 'Til, mavzu va bildirishnomalar',
                              onTap: () =>
                                  _push(context, const SettingsScreen()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const _SectionLabel(text: 'Harakatlar'),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Iconsax.user_octagon,
                              iconColor: AppColors.terracotta,
                              title: 'Xaridor rejimi',
                              titleColor: AppColors.terracotta,
                              onTap: () =>
                                  switchAppMode(context, AppMode.customer),
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
                    );
                  },
                ),
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

  static String _planSubtitle(SellerProfileState state) {
    if (state.isInitialLoading) return 'Yuklanmoqda…';
    return 'Joriy tarif: ${_planLabel(state.plan)}';
  }

  static String _planLabel(TariffPlan plan) {
    return switch (plan) {
      TariffPlan.free => 'Free',
      TariffPlan.basic => 'Basic',
      TariffPlan.pro => 'Pro',
      TariffPlan.enterprise => 'Enterprise',
    };
  }
}

final Color _logoutRed = Colors.red.shade600;

// =============================================================================
// 1. Header — "Profil" title
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
              style: TextStyle(
                fontFamily: AppFonts.seller,
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

// =============================================================================
// 2. Identity card — large avatar, shop name, status pill
// =============================================================================
class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.state});

  final SellerProfileState state;

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoading) {
      return const _IdentitySkeleton();
    }
    return Column(
      children: [
        _Avatar(logoUrl: state.logoUrl),
        const SizedBox(height: 14),
        Text(
          state.displayShopName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        _StatusBadge(status: state.verificationStatus),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(color: _avatarBg, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: (url == null || url.isEmpty)
          ? const Icon(Iconsax.shop, size: 36, color: AppColors.terracotta)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: 80,
              height: 80,
              memCacheWidth: 240,
              errorWidget: (_, _, _) => const Icon(
                Iconsax.shop,
                size: 36,
                color: AppColors.terracotta,
              ),
              placeholder: (_, _) => const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.terracotta,
                ),
              ),
            ),
    );
  }
}

class _IdentitySkeleton extends StatelessWidget {
  const _IdentitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E6E6),
      highlightColor: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: _avatarBg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 160,
            height: 20,
            decoration: BoxDecoration(
              color: _avatarBg,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 140,
            height: 22,
            decoration: BoxDecoration(
              color: _avatarBg,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, icon) = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  /// Picks the badge palette + label for the four meaningful statuses. The
  /// `none` bucket also covers an authenticated user whose `sellers` row is
  /// missing — pre-onboarding state.
  static (String, Color, Color, IconData) _styleFor(VerificationStatus s) {
    return switch (s) {
      VerificationStatus.approved => (
        'Tasdiqlangan sotuvchi',
        _verifiedBg,
        _verifiedFg,
        Iconsax.tick_circle,
      ),
      VerificationStatus.pending || VerificationStatus.inReview => (
        'Tasdiqlash kutilmoqda',
        _pendingBg,
        _pendingFg,
        Iconsax.clock,
      ),
      VerificationStatus.rejected => (
        'Tasdiqlash rad etilgan',
        _rejectedBg,
        _rejectedFg,
        Iconsax.close_circle,
      ),
      VerificationStatus.none => (
        'Tasdiqlanmagan',
        _neutralBadgeBg,
        _neutralBadgeFg,
        Iconsax.info_circle,
      ),
    };
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
        style: TextStyle(
          fontFamily: AppFonts.seller,
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
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
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
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
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

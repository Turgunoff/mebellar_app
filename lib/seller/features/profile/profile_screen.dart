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
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../reviews/screens/reviews_screen.dart';
import '../settings/screens/services_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../settings/screens/shop_settings_screen.dart';
import '../tariff/screens/tariff_screen.dart';
import 'cubit/seller_profile_cubit.dart';

// Fixed (brightness-independent) local tokens — the verification-status
// intent tints and the tariff gold. Adaptive ink/grey/surface/divider/avatar
// colours are read from `SellerColors.of(context)` per build so the screen
// flips with the seller theme. Plus Jakarta Sans is applied to every `Text`
// explicitly via `AppFonts.seller`.
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
      color: SellerColors.of(context).background,
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
                              iconColor: AppColors.sellerPrimary,
                              title: 'Xaridor rejimi',
                              titleColor: AppColors.sellerPrimary,
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
    return 'Joriy tarif: ${state.plan.label}';
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
    final c = SellerColors.of(context);
    return Container(
      color: c.background,
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
                color: c.ink,
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
// 2. Identity hero card — cover banner, overlapping logo, name, badges
// =============================================================================
const double _kCoverHeight = 124;
const double _kAvatarSize = 84;
const double _kAvatarOverlap = _kAvatarSize / 2;

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.state});

  final SellerProfileState state;

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoading) {
      return const _IdentitySkeleton();
    }
    final c = SellerColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sellerName = state.sellerName;
    final showOwner = sellerName != null &&
        sellerName.isNotEmpty &&
        sellerName != state.displayShopName;

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
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: state.hasCover
                    ? () => openFullscreenImageViewer(
                          context,
                          images: [state.coverUrl!],
                          initialIndex: 0,
                          heroTagPrefix: 'shop-cover',
                        )
                    : null,
                child: Hero(
                  tag: 'shop-cover-0',
                  child: _CoverBanner(coverUrl: state.coverUrl),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _CoverEditButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ShopSettingsScreen(),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: -_kAvatarOverlap,
                child: Center(
                  child: GestureDetector(
                    onTap: state.hasLogo
                        ? () => openFullscreenImageViewer(
                              context,
                              images: [state.logoUrl!],
                              initialIndex: 0,
                              heroTagPrefix: 'shop-logo',
                            )
                        : null,
                    child: Hero(
                      tag: 'shop-logo-0',
                      child: _Avatar(logoUrl: state.logoUrl),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _kAvatarOverlap + 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              children: [
                Text(
                  state.displayShopName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                if (showOwner) ...[
                  const SizedBox(height: 4),
                  Text(
                    sellerName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.grey,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusBadge(status: state.verificationStatus),
                    if (RemoteConfig.instance.tariffEnabled)
                      _PlanChip(plan: state.plan),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wide shop cover. Falls back to a branded indigo gradient with a subtle
/// watermark when the seller hasn't uploaded one yet.
class _CoverBanner extends StatelessWidget {
  const _CoverBanner({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    final fallback = Container(
      height: _kCoverHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sellerPrimary, AppColors.sellerPrimaryDeep],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -26,
            child: Icon(
              Iconsax.shop,
              size: 120,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            left: -30,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: (url == null || url.isEmpty)
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              height: _kCoverHeight,
              width: double.infinity,
              fit: BoxFit.cover,
              memCacheWidth: 1200,
              placeholder: (_, _) => Container(
                height: _kCoverHeight,
                color: SellerColors.of(context).imageBg,
              ),
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}

class _CoverEditButton extends StatelessWidget {
  const _CoverEditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.32),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(Iconsax.edit_2, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final url = logoUrl;
    // Surface-coloured ring lifts the logo off the cover photo.
    return Container(
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
        alignment: Alignment.center,
        child: (url == null || url.isEmpty)
            ? const Icon(Iconsax.shop, size: 34, color: AppColors.sellerPrimary)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: _kAvatarSize,
                height: _kAvatarSize,
                memCacheWidth: 240,
                errorWidget: (_, _, _) => const Icon(
                  Iconsax.shop,
                  size: 34,
                  color: AppColors.sellerPrimary,
                ),
                placeholder: (_, _) => const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.sellerPrimary,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Gold crown chip showing the active tariff plan.
class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.plan});

  final TariffPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.sellerGoldBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.crown_1, size: 13, color: _gold),
          const SizedBox(width: 5),
          Text(
            '${plan.label} tarif',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _gold,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentitySkeleton extends StatelessWidget {
  const _IdentitySkeleton();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final block = c.neutralBg;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E6),
      highlightColor: dark ? const Color(0xFF383838) : const Color(0xFFF5F5F5),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: _kCoverHeight,
                decoration: BoxDecoration(
                  color: block,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: -_kAvatarOverlap,
                child: Center(
                  child: Container(
                    width: _kAvatarSize,
                    height: _kAvatarSize,
                    decoration:
                        BoxDecoration(color: block, shape: BoxShape.circle),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _kAvatarOverlap + 12),
          Container(
            width: 160,
            height: 20,
            decoration: BoxDecoration(
              color: block,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 140,
            height: 22,
            decoration: BoxDecoration(
              color: block,
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
    var (label, bg, fg, icon) = _styleFor(status);
    // The "unverified" (neutral) badge sits on the page background, so its
    // soft grey must flip with the theme — the coloured intent badges read
    // fine on both modes and stay fixed.
    if (status == VerificationStatus.none) {
      final c = SellerColors.of(context);
      bg = c.neutralBg;
      fg = c.neutralFg;
    }
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
          color: SellerColors.of(context).grey,
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
    final c = SellerColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(items[i]);
      if (i < items.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Divider(height: 1, thickness: 1, color: c.divider),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.28 : 0.05),
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
    final c = SellerColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor ?? c.ink),
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
                        color: titleColor ?? c.ink,
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
                          color: c.grey,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showTrailing) ...[
                const SizedBox(width: 8),
                Icon(Iconsax.arrow_right_3, size: 18, color: c.greyMid),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

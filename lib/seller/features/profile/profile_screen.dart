import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:hive/hive.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../config/app_mode.dart';
import '../../../config/remote_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/woody_api_client.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../shared/chat/bloc/total_unread_chats_cubit.dart';
import '../../../shared/chat/widgets/unread_count_badge.dart';
import '../../../shared/models/shop_settings.dart';
import '../../../shared/models/tariff.dart';
import '../../../shared/models/verification_status.dart';
import '../../../shared/payments/pending_payment_service.dart';
import '../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../products/data/ar_token_repository.dart';
import '../reviews/screens/reviews_screen.dart';
import '../../../shared/models/seller_wallet.dart';
import '../settings/screens/services_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../settings/screens/shop_settings_screen.dart';
import '../tariff/screens/tariff_screen.dart';
import '../wallet/screens/ar_tokens_screen.dart';
import '../wallet/screens/wallet_screen.dart';
import '../onboarding/screens/seller_contract_screen.dart';
import 'cubit/seller_profile_cubit.dart';

// All surface / ink / grey / divider / status-intent / gold colours are read
// from `SellerColors.of(context)` per build so the screen flips with the
// seller theme. Plus Jakarta Sans is applied to every `Text` explicitly via
// `AppFonts.seller`.

class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TotalUnreadChatsCubit is provided by the seller shell, so the
    // "Suhbatlar" row badge here and the bottom-nav Profile badge share one
    // live unread count off a single subscription.
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
                    final unreadChats = context
                        .watch<TotalUnreadChatsCubit>()
                        .state;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: [
                        _ProfileIdentity(state: state),
                        const SizedBox(height: 24),
                        // Group 1 — Finance & subscriptions (money, plan,
                        // usage limits). Surfaced first as the highest-stakes
                        // surface for a seller.
                        _SectionLabel(
                          text: tr('seller.profile_section_finance'),
                        ),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Iconsax.wallet_3_copy,
                              iconColor: state.wallet?.isHealthy == false
                                  ? AppColors.danger
                                  : null,
                              title: tr('seller.profile_wallet_title'),
                              subtitle: _walletSubtitle(state),
                              onTap: () => _push(context, const WalletScreen()),
                            ),
                            // Tariff is hidden while the tariff system is
                            // switched off (RemoteConfig.tariffEnabled).
                            if (RemoteConfig.instance.tariffEnabled)
                              _SettingsItem(
                                icon: Iconsax.crown_1_copy,
                                iconColor: SellerColors.of(context).gold,
                                title: tr('seller.tariff_title'),
                                subtitle: _planSubtitle(state),
                                onTap: () =>
                                    _push(context, const TariffScreen()),
                              ),
                            _SettingsItem(
                              icon: Iconsax.flash_1_copy,
                              iconColor: SellerColors.of(context).gold,
                              title: tr('seller.profile_ar_tokens_title'),
                              subtitle: tr('seller.profile_ar_tokens_subtitle'),
                              onTap: () => _push(
                                context,
                                ArTokensScreen(
                                  repo: sl<ArTokenRepository>(),
                                  api: sl<WoodyApiClient>(),
                                  settingsBox: sl<Box>(
                                    instanceName: HiveBoxes.settings,
                                  ),
                                  pendingPayments:
                                      sl.isRegistered<PendingPaymentService>()
                                      ? sl<PendingPaymentService>()
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Group 2 — Customer relations (high-frequency buyer
                        // interaction surfaces).
                        _SectionLabel(
                          text: tr('seller.profile_section_customer_relations'),
                        ),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            // Promoted out of "Ilova sozlamalari" — chats are a
                            // core customer-relations surface, not an app
                            // setting.
                            _SettingsItem(
                              icon: Iconsax.message_copy,
                              title: tr('seller.profile_chats_title'),
                              subtitle: tr('seller.profile_chats_subtitle'),
                              badgeCount: unreadChats,
                              onTap: () => context.push('/seller/chats'),
                            ),
                            _SettingsItem(
                              icon: Iconsax.messages_2_copy,
                              title: tr('seller.profile_reviews_title'),
                              subtitle: tr('seller.profile_reviews_subtitle'),
                              onTap: () =>
                                  _push(context, const ReviewsScreen()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Group 3 — Store configuration (set-and-forget admin
                        // settings).
                        _SectionLabel(
                          text: tr('seller.profile_section_manage_shop'),
                        ),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Iconsax.shop_copy,
                              title: tr('seller.shop_settings'),
                              subtitle: tr('seller.shop_settings_subtitle'),
                              onTap: () => _openShopSettings(context),
                            ),
                            _SettingsItem(
                              icon: Iconsax.truck_fast_copy,
                              title: tr('seller.profile_shop_services_title'),
                              subtitle: tr(
                                'seller.profile_shop_services_subtitle',
                              ),
                              onTap: () =>
                                  _push(context, const SellerServicesScreen()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _SectionLabel(
                          text: tr('seller.profile_section_app_settings'),
                        ),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            // Chats/reviews/wallet live in their own grouped
                            // sections above; only app-level prefs remain here.
                            // Bildirishnomalar entry removed — the dashboard
                            // bell icon is the canonical entry point.
                            _SettingsItem(
                              icon: Iconsax.setting_2_copy,
                              title: tr('seller.profile_settings_title'),
                              subtitle: tr('seller.profile_settings_subtitle'),
                              onTap: () =>
                                  _push(context, const SettingsScreen()),
                            ),
                            _SettingsItem(
                              icon: Iconsax.document_text_copy,
                              title: tr('seller.profile_contract_title'),
                              subtitle: tr('seller.profile_contract_subtitle'),
                              onTap: () {
                                final rate = state.plan.commissionRate;
                                final commission = rate == rate.roundToDouble()
                                    ? rate.toInt().toString()
                                    : rate.toString();
                                _push(
                                  context,
                                  SellerContractScreen(
                                    isReadOnly: true,
                                    sellerName: state.displayShopName,
                                    sellerPhone: state.contactPhone ?? '',
                                    commissionPercent: commission,
                                    acceptedAt: state.contractAcceptedAt,
                                    acceptedVersion: state.contractVersion,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _SectionLabel(
                          text: tr('seller.profile_section_actions'),
                        ),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Iconsax.user_octagon_copy,
                              iconColor: AppColors.sellerPrimary,
                              title: tr('seller.profile_switch_to_buyer'),
                              titleColor: AppColors.sellerPrimary,
                              onTap: () =>
                                  switchAppMode(context, AppMode.customer),
                            ),
                            _SettingsItem(
                              icon: Iconsax.logout_copy,
                              iconColor: _logoutRed,
                              title: tr('seller.profile_logout'),
                              titleColor: _logoutRed,
                              showTrailing: false,
                              onTap: () => _confirmAndLogout(context),
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
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/${screen.runtimeType}'),
        builder: (_) => screen,
      ),
    );
  }

  static String _planSubtitle(SellerProfileState state) {
    if (state.isInitialLoading) return tr('seller.profile_loading');
    return tr(
      'seller.profile_current_plan',
      namedArgs: {'plan': state.plan.label},
    );
  }

  static String _walletSubtitle(SellerProfileState state) {
    final wallet = state.wallet;
    if (wallet == null) return tr('seller.profile_wallet_subtitle_default');
    if (wallet.isSuspendedDueToDebt) {
      return tr('seller.profile_wallet_suspended');
    }
    if (wallet.isInGrace) {
      return tr(
        'seller.profile_wallet_balance_grace',
        namedArgs: {
          'amount': formatSom(wallet.balance),
          'hours': '${wallet.graceHoursLeft()}',
        },
      );
    }
    return tr(
      'seller.profile_wallet_balance',
      namedArgs: {'amount': formatSom(wallet.balance)},
    );
  }
}

final Color _logoutRed = Colors.red.shade600;

/// Asks for confirmation (same copy as the customer profile dialog), then
/// runs the full [performLogout] teardown. Seller previously skipped the
/// confirm step and signed out on the first tap.
Future<void> _confirmAndLogout(BuildContext context) async {
  final c = SellerColors.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final error = Theme.of(ctx).colorScheme.error;
      return Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Iconsax.logout_copy, size: 24, color: error),
              ),
              const SizedBox(height: 20),
              Text(
                tr('profile.sign_out_title'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                tr('profile.sign_out_confirm'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  color: c.grey,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.ink,
                        side: BorderSide(color: c.divider),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr('profile.cancel'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr('profile.sign_out_action'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (confirmed == true && context.mounted) {
    await performLogout(context);
  }
}

/// Opens shop settings and, when the seller saves, applies the returned
/// settings straight onto the profile identity card — logo/cover removals and
/// renames show up the moment the settings screen pops, no manual refresh.
Future<void> _openShopSettings(BuildContext context) async {
  final cubit = context.read<SellerProfileCubit>();
  final saved = await Navigator.of(context, rootNavigator: true)
      .push<ShopSettings>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/shop-settings'),
          builder: (_) => const ShopSettingsScreen(),
        ),
      );
  if (saved != null) cubit.applyShopSettings(saved);
}

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
    final showOwner =
        sellerName != null &&
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
          // The Stack's height includes the avatar overhang — content outside
          // a Stack's bounds renders but never receives taps, so the old
          // negative-bottom Positioned made the logo's lower half dead.
          SizedBox(
            height: _kCoverHeight + _kAvatarOverlap + 6,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _kCoverHeight,
                  child: GestureDetector(
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
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _CoverEditButton(
                    onTap: () => _openShopSettings(context),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
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
          ),
          const SizedBox(height: 12),
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
              Iconsax.shop_copy,
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
          child: Icon(Iconsax.edit_2_copy, size: 16, color: Colors.white),
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
        decoration: BoxDecoration(color: c.neutralBg, shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: (url == null || url.isEmpty)
            ? const Icon(
                Iconsax.shop_copy,
                size: 34,
                color: AppColors.sellerPrimary,
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: _kAvatarSize,
                height: _kAvatarSize,
                memCacheWidth: 240,
                errorWidget: (_, _, _) => const Icon(
                  Iconsax.shop_copy,
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
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.goldBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.crown_1_copy, size: 13, color: c.gold),
          const SizedBox(width: 5),
          Text(
            tr('seller.profile_plan_chip', namedArgs: {'plan': plan.label}),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.gold,
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
                    decoration: BoxDecoration(
                      color: block,
                      shape: BoxShape.circle,
                    ),
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
    final c = SellerColors.of(context);
    final (label, bg, fg, icon) = _styleFor(c, status);
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

  /// Picks the badge palette + label for the four meaningful statuses. Each
  /// intent maps to a brightness-aware [SellerColors] pair so the badges flip
  /// with the theme. The `none` bucket also covers an authenticated user whose
  /// `sellers` row is missing — pre-onboarding state.
  static (String, Color, Color, IconData) _styleFor(
    SellerColors c,
    VerificationStatus s,
  ) {
    return switch (s) {
      VerificationStatus.approved => (
        tr('seller.profile_status_approved'),
        c.positiveBg,
        c.positive,
        Iconsax.tick_circle_copy,
      ),
      VerificationStatus.pending || VerificationStatus.inReview => (
        tr('seller.profile_status_pending'),
        c.warningBg,
        c.warning,
        Iconsax.clock_copy,
      ),
      VerificationStatus.rejected => (
        tr('seller.profile_status_rejected'),
        c.negativeBg,
        c.negative,
        Iconsax.close_circle_copy,
      ),
      VerificationStatus.none => (
        tr('seller.profile_status_none'),
        c.neutralBg,
        c.neutralFg,
        Iconsax.info_circle_copy,
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
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;
  final bool showTrailing;

  /// Unread pill shown before the chevron (the "Suhbatlar" row). Hidden at 0.
  final int badgeCount;

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
              if (badgeCount > 0) ...[
                const SizedBox(width: 8),
                UnreadCountBadge(count: badgeCount),
              ],
              if (showTrailing) ...[
                const SizedBox(width: 8),
                Icon(Iconsax.arrow_right_3_copy, size: 18, color: c.greyMid),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

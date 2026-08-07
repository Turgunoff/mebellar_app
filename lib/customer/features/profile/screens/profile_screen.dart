import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../config/app_mode.dart';
import '../../../../core/auth/app_mode_cubit.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/chat/bloc/total_unread_chats_cubit.dart';
import '../../support/bloc/support_unread_cubit.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../notifications/cubit/notifications_cubit.dart';
import '../../orders/cubit/profile_orders_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../widgets/account_dialogs.dart';
import '../widgets/danger_zone.dart';
import '../widgets/orders_block.dart';
import '../widgets/profile_menu_card.dart';
import '../widgets/seller_banners.dart';
import '../widgets/user_card.dart';
import '../../../../shared/about/about_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

/// Customer profile screen.
///
/// ROADMAP B.4 — the original 1,687-line file was split: every section widget
/// lives under `profile/widgets/`, the account dialogs are top-level functions
/// in `account_dialogs.dart`, and this file is the screen scaffold plus its
/// thin navigation orchestration.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    sl<ProfileCubit>().fetch();
    sl<ProfileOrdersCubit>().fetch();
  }

  void _openAvatarViewer(ProfileState profile) {
    final url = profile.avatarUrl;
    if (url == null || url.isEmpty) {
      // No photo yet — send the user to the editor to set one instead.
      _openEditScreen(profile);
      return;
    }
    openFullscreenImageViewer(
      context,
      images: [url],
      initialIndex: 0,
      heroTagPrefix: 'profile-avatar',
    );
  }

  void _openEditScreen(ProfileState profile) {
    final cubit = context.read<ProfileCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/edit-profile'),
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: EditProfileScreen(profile: profile),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/${screen.runtimeType}'),
        builder: (_) => screen,
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      sl<ProfileCubit>().fetch(),
      sl<ProfileOrdersCubit>().fetch(),
    ]);
  }

  Future<void> _openSellerOnboarding() async {
    // Wait for the onboarding stack to pop so we can refresh the profile
    // afterwards. Without this, `profiles.is_seller_pending` flips to true
    // server-side but the banner here keeps showing "Become a seller" until
    // the next app launch refetches the row.
    await context.push('/seller/onboarding');
    if (!mounted) return;
    await context.read<ProfileCubit>().fetch();
  }

  List<MenuEntry> _buildMenuItems(
    BuildContext context,
    int unreadChats,
    int unreadSupport,
  ) => [
    // Resubmit-after-rejection stays on the profile seller cards
    // (SellerRejectedBanner / BecomeSellerBanner) — no separate menu row.
    MenuEntry(
      icon: Iconsax.message_copy,
      label: tr('chat.title'),
      badgeCount: unreadChats,
      onTap: () => context.push('/chats'),
    ),
    MenuEntry(
      icon: Iconsax.setting_2_copy,
      label: tr('profile.menu_settings'),
      onTap: () => _push(context, const SettingsScreen()),
    ),
    MenuEntry(
      icon: Iconsax.message_question_copy,
      label: tr('profile.help_title'),
      badgeCount: unreadSupport,
      onTap: () => context.push('/support'),
    ),
    MenuEntry(
      icon: Iconsax.info_circle_copy,
      label: tr('profile.menu_about'),
      onTap: () => _push(context, const AboutScreen()),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // The unread count comes from the shell-level TotalUnreadChatsCubit
    // (provided in customer_app.dart) so the in-profile "Suhbatlar" badge and
    // the bottom-nav Profile badge stay in lock-step off one subscription.
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final profileState = context.watch<ProfileCubit>().state;
    final unreadChats = context.watch<TotalUnreadChatsCubit>().state;
    final unreadSupport = context.watch<SupportUnreadCubit>().state;
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
      body: BrandRefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (profileState.isLoading)
              const UserCardShimmer()
            else if (profileState.isSignedIn)
              UserCard(
                profile: profileState,
                onEdit: () => _openEditScreen(profileState),
                onAvatarTap: () => _openAvatarViewer(profileState),
              ),
            const SizedBox(height: 24),
            const OrdersBlock(),
            const SizedBox(height: 20),
            // Approved-known wins over the loading shimmer: a cached approved
            // seller gets the green panel card on the first frame instead of a
            // shimmer→banner transition, and never the "become a seller" CTA.
            if (profileState.isApprovedSellerKnown)
              SellerApprovedBanner(
                // Live seller-panel unread, from the shared root cubit — kept
                // out of the customer bell, surfaced here instead.
                unreadCount: context.select<NotificationsCubit, int>(
                  (c) => c.state.sellerUnreadCount,
                ),
                onOpenDashboard: () {
                  // Defence-in-depth: refresh the cached approval flag before
                  // flipping. The banner only renders when approved, but the
                  // boot-time guard depends on this cache being true to honor
                  // a persisted `seller` mode on the next cold start.
                  sl<AppModeCubit>().recordSellerApproval(true);
                  context.read<AppModeCubit>().switchMode(AppMode.seller);
                  // Phoenix.rebirth (triggered by the root-level mode-swap
                  // listener in main.dart) tears this widget tree down and
                  // mounts SellerApp — no further navigation needed here.
                },
              )
            else if (profileState.isLoading)
              const SellerBannerShimmer()
            else if (profileState.isSellerRejected &&
                !profileState.rejectedBannerDismissed)
              SellerRejectedBanner(
                reason: profileState.sellerRejectionReason,
                onEdit: _openSellerOnboarding,
                onDismiss: () =>
                    context.read<ProfileCubit>().dismissRejectedBanner(),
              )
            else if (profileState.isSellerPending)
              const SellerPendingBanner()
            else
              BecomeSellerBanner(onTap: _openSellerOnboarding),
            const SizedBox(height: 24),
            MenuListCard(
              items: _buildMenuItems(
                context,
                unreadChats,
                unreadSupport,
              ),
            ),
            const SizedBox(height: 28),
            DangerZone(
              onSignOut: () => showSignOutDialog(context),
              onDeleteAccount: () => confirmAccountDeletion(context),
            ),
          ],
        ),
      ),
    );
  }
}

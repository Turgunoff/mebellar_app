import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../config/app_mode.dart';
import '../../../../core/auth/app_mode_cubit.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../widgets/glass_bottom_nav.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../../orders/cubit/profile_orders_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../widgets/account_dialogs.dart';
import '../widgets/danger_zone.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/orders_block.dart';
import '../widgets/profile_menu_card.dart';
import '../widgets/seller_banners.dart';
import '../widgets/user_card.dart';
import 'about_screen.dart';
import 'help_screen.dart';
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

  void _showEditSheet(ProfileState profile) {
    final cubit = context.read<ProfileCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: EditProfileSheet(
          currentName: profile.name ?? '',
          currentPhone: profile.phone ?? '',
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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

  List<MenuEntry> _buildMenuItems(BuildContext context) => [
    MenuEntry(
      icon: Iconsax.message,
      label: tr('chat.title'),
      onTap: () => context.push('/chats'),
    ),
    MenuEntry(
      icon: Iconsax.setting_2,
      label: 'Sozlamalar',
      onTap: () => _push(context, const SettingsScreen()),
    ),
    MenuEntry(
      icon: Iconsax.message_question,
      label: "Yordam va Qo'llab-quvvatlash",
      onTap: () => _push(context, const HelpScreen()),
    ),
    MenuEntry(
      icon: Iconsax.info_circle,
      label: 'Ilova haqida',
      onTap: () => _push(context, const AboutScreen()),
    ),
    // TEMPORARY: lets us activate Crashlytics in the Firebase console on
    // the first install. Remove once a real crash has landed in the
    // dashboard. Tap = non-fatal sample; long-press = forced fatal crash.
    MenuEntry(
      icon: Iconsax.warning_2,
      label: 'Crashlytics testi',
      onTap: () => _runCrashlyticsTest(context, fatal: false),
      onLongPress: () => _runCrashlyticsTest(context, fatal: true),
    ),
  ];

  Future<void> _runCrashlyticsTest(
    BuildContext context, {
    required bool fatal,
  }) async {
    if (fatal) {
      // Block briefly so the SnackBar paints before the engine tears down.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crashlytics: fatal crash yuborilmoqda…'),
          duration: Duration(seconds: 1),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 800));
      // Engine-level crash — most realistic test of the pipeline.
      FirebaseCrashlytics.instance.crash();
    } else {
      // Non-fatal: activates the Firebase dashboard without killing the app.
      await FirebaseCrashlytics.instance.recordError(
        Exception('Crashlytics non-fatal test (profile button)'),
        StackTrace.current,
        reason: 'manual test from profile menu',
        fatal: false,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Crashlytics: non-fatal yuborildi. 5-10 daqiqada Firebase\'da '
            "ko'rinadi. Long-press = fatal crash.",
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final profileState = context.watch<ProfileCubit>().state;
    return Scaffold(
      backgroundColor: pt.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Profil',
          style: PremiumTokens.display(size: 28, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          GlassBottomNav.reservedHeight(context) + 24,
        ),
        children: [
          if (profileState.isLoading)
            const UserCardShimmer()
          else if (profileState.email.isNotEmpty)
            UserCard(
              profile: profileState,
              onEdit: () => _showEditSheet(profileState),
            ),
          const SizedBox(height: 24),
          const OrdersBlock(),
          const SizedBox(height: 20),
          if (profileState.isSellerApproved)
            SellerApprovedBanner(
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
          else if (profileState.isSellerRejected)
            SellerRejectedBanner(
              reason: profileState.sellerRejectionReason,
              onEdit: _openSellerOnboarding,
            )
          else if (profileState.isSellerPending)
            const SellerPendingBanner()
          else
            BecomeSellerBanner(onTap: _openSellerOnboarding),
          const SizedBox(height: 24),
          MenuListCard(items: _buildMenuItems(context)),
          const SizedBox(height: 28),
          DangerZone(
            onSignOut: () => showSignOutDialog(context),
            onDeleteAccount: () => confirmAccountDeletion(context),
          ),
        ],
      ),
    );
  }
}

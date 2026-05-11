import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../seller/features/onboarding/screens/onboarding_screen.dart';
import '../../../widgets/glass_bottom_nav.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import 'about_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  _ProfileData? _profile;
  bool _isLoading = true;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    // Re-fetch when step 3 of auth (profile save) completes.
    // updateUser() emits userUpdated on the auth stream.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.userUpdated && mounted) {
        _fetchProfile();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone, avatar_url, is_seller_pending')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _profile = _ProfileData(
            email: user.email ?? '',
            name: data['full_name'] as String?,
            phone: data['phone'] as String?,
            avatarUrl: data['avatar_url'] as String?,
            isSellerPending: (data['is_seller_pending'] as bool?) ?? false,
          );
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      // PGRST116: ".single() found 0 rows" — the account was deleted from the
      // DB but the local JWT is still cached (ghost session).
      if (e.code == 'PGRST116') {
        talker.warning(
          'Ghost session detected: profile row missing for user ${user.id}. '
          'Forcing local sign-out.',
        );
        await Supabase.instance.client.auth.signOut();
        // signOut() fires onAuthStateChange → shell sets _isAuthenticated=false
        // → ProfileScreen is unmounted. Clear state defensively in case
        // the widget is still in the tree during the transition frame.
        if (mounted)
          setState(() {
            _profile = null;
            _isLoading = false;
          });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    final pt = PremiumTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: pt.surface,
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
                  color: const Color(0xFFE05A4A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Iconsax.logout,
                  size: 24,
                  color: Color(0xFFE05A4A),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Hisobdan chiqish',
                style: PremiumTokens.display(size: 20, letterSpacing: -0.2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Hisobingizdan chiqmoqchimisiz?',
                style: PremiumTokens.body(
                  size: 14,
                  color: pt.grey,
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
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: pt.divider),
                      ),
                      child: Text(
                        'Bekor qilish',
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: pt.dark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: const Color(0xFFE05A4A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Chiqish',
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w600,
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
      ),
    );
    if (confirmed == true && mounted) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  Future<void> _deleteAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final pt = PremiumTokens.of(context);
    final ctrl = TextEditingController();
    bool isLoading = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissal during loading
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          backgroundColor: pt.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0x1AE05A4A),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Iconsax.trash,
                    size: 22,
                    color: Color(0xFFE05A4A),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Akkauntni o'chirish",
                  style: PremiumTokens.display(size: 20, letterSpacing: -0.2),
                ),
                const SizedBox(height: 10),
                Text(
                  "Bu amalni bekor qilib bo'lmaydi. Barcha "
                  "ma'lumotlaringiz o'chiriladi.",
                  style: PremiumTokens.body(
                    size: 13,
                    color: pt.grey,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Tasdiqlash uchun DELETE so'zini kiriting:",
                  style: PremiumTokens.body(size: 13, color: pt.dark),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  enabled: !isLoading, // Disable input during loading
                  style: PremiumTokens.body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: const Color(0xFFE05A4A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    filled: true,
                    fillColor: pt.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: pt.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE05A4A),
                        width: 1.5,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: pt.divider, width: 1),
                    ),
                  ),
                  onChanged: (_) => setStateDialog(() {}),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: pt.divider),
                        ),
                        child: Text(
                          'Bekor qilish',
                          style: PremiumTokens.body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: pt.dark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: ctrl,
                        builder: (_, val, _) => FilledButton(
                          onPressed: val.text == 'DELETE' && !isLoading
                              ? () async {
                                  setStateDialog(() => isLoading = true);

                                  try {
                                    // Hard-delete the auth user via SECURITY DEFINER
                                    // RPC. profiles → sellers → shops cascade
                                    // through their FKs; favorites cascades
                                    // directly from auth.users.
                                    await Supabase.instance.client.rpc(
                                      'delete_user_account',
                                    );

                                    await _clearLocalAfterDelete();

                                    if (ctx.mounted) {
                                      Navigator.of(
                                        ctx,
                                        rootNavigator: true,
                                      ).pop(true);
                                    }

                                    // signOut() drops the local JWT and fires
                                    // AuthCubit → root rebuild → ProfileScreen
                                    // unmounts.
                                    await Supabase.instance.client.auth
                                        .signOut();

                                    talker.info(
                                      'Account hard-deleted successfully',
                                    );
                                  } catch (e, st) {
                                    talker.error(
                                      'Account deletion failed',
                                      e,
                                      st,
                                    );

                                    if (!ctx.mounted) return;

                                    setStateDialog(() => isLoading = false);

                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Xato: $e",
                                          style: PremiumTokens.body(
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: const Color(
                                          0xFFE05A4A,
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: const Color(0xFFE05A4A),
                            disabledBackgroundColor: const Color(
                              0xFFE05A4A,
                            ).withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Tasdiqlash',
                                  style: PremiumTokens.body(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _clearLocalAfterDelete() async {
    try {
      if (sl.isRegistered<SecureStorage>()) {
        await sl<SecureStorage>().clear();
      }
      const userScopedBoxes = [
        HiveBoxes.cache,
        HiveBoxes.favorites,
        HiveBoxes.onboardingDraft,
        HiveBoxes.pendingRoute,
      ];
      for (final name in userScopedBoxes) {
        if (sl.isRegistered<Box>(instanceName: name)) {
          await sl<Box>(instanceName: name).clear();
        }
      }
    } catch (e, st) {
      // Best-effort: a stale local cache must not block account deletion.
      talker.warning('Local cleanup after delete failed', e, st);
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openSellerOnboarding() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    _fetchProfile();
  }

  List<_MenuEntry> _buildMenuItems(BuildContext context) => [
    _MenuEntry(icon: Iconsax.location, label: 'Mening manzillarim'),
    _MenuEntry(icon: Iconsax.card, label: "To'lov usullari"),
    _MenuEntry(
      icon: Iconsax.setting_2,
      label: 'Sozlamalar',
      onTap: () => _push(context, const SettingsScreen()),
    ),
    _MenuEntry(
      icon: Iconsax.message_question,
      label: "Yordam va Qo'llab-quvvatlash",
      onTap: () => _push(context, const HelpScreen()),
    ),
    _MenuEntry(
      icon: Iconsax.info_circle,
      label: 'Ilova haqida',
      onTap: () => _push(context, const AboutScreen()),
    ),
  ];

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
            const _ProfileHeader(notificationCount: 0),
            const SizedBox(height: 20),
            if (_isLoading)
              const _UserCardShimmer()
            else if (_profile != null)
              _UserCard(profile: _profile!),
            const SizedBox(height: 24),
            const _OrdersBlock(),
            const SizedBox(height: 20),
            if (_profile?.isSellerPending == true)
              const _SellerPendingBanner()
            else
              _BecomeSellerBanner(onTap: _openSellerOnboarding),
            const SizedBox(height: 24),
            _MenuListCard(items: _buildMenuItems(context)),
            const SizedBox(height: 28),
            _DangerZone(onSignOut: _signOut, onDeleteAccount: _deleteAccount),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile data model
// ---------------------------------------------------------------------------

class _ProfileData {
  const _ProfileData({
    required this.email,
    this.name,
    this.phone,
    this.avatarUrl,
    this.isSellerPending = false,
  });

  final String email;
  final String? name;
  final String? phone;
  final String? avatarUrl;
  final bool isSellerPending;

  bool get hasName => name != null && name!.isNotEmpty;

  /// Primary line: full_name if available, otherwise email.
  String get displayName => hasName ? name! : email;

  /// Secondary line: phone if available, otherwise email (only shown when
  /// we already show the name as primary).
  String? get secondaryLine {
    if (!hasName) return null;
    return (phone != null && phone!.isNotEmpty) ? phone : email;
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.notificationCount});

  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Profil',
              style: PremiumTokens.display(size: 32, letterSpacing: -0.6),
            ),
          ),
          _NotificationBell(count: notificationCount),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: pt.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {},
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: pt.divider),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(Iconsax.notification, size: 20, color: pt.dark),
              if (count > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE05A4A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pt.surface, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: PremiumTokens.body(
                        size: 9,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User identity card
// ---------------------------------------------------------------------------

class _UserCard extends StatelessWidget {
  const _UserCard({required this.profile});

  final _ProfileData profile;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final hasAvatar =
        profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 64,
              height: 64,
              child: hasAvatar
                  ? CachedNetworkImage(
                      imageUrl: profile.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: pt.imageBg),
                      errorWidget: (_, _, _) => const _AvatarFallback(),
                    )
                  : const _AvatarFallback(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.displayName,
                        style: PremiumTokens.display(
                          size: 20,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkResponse(
                      onTap: () {},
                      radius: 18,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Iconsax.edit_2, size: 16, color: pt.grey),
                      ),
                    ),
                  ],
                ),
                if (profile.secondaryLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.secondaryLine!,
                    style: PremiumTokens.body(size: 13, color: pt.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ColoredBox(
      color: pt.imageBg,
      child: Icon(Iconsax.user, color: pt.greyLight),
    );
  }
}

class _UserCardShimmer extends StatelessWidget {
  const _UserCardShimmer();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: const Color(0xFFF5F5F5),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: PremiumTokens.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 18,
                    width: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 13,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
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

// ---------------------------------------------------------------------------
// Orders quick-access block
// ---------------------------------------------------------------------------

class _OrdersBlock extends StatelessWidget {
  const _OrdersBlock();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Buyurtmalarim',
                    style: PremiumTokens.body(
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: PremiumTokens.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Barchasi',
                        style: PremiumTokens.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: PremiumTokens.accent,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Iconsax.arrow_right_3,
                        size: 14,
                        color: PremiumTokens.accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
            child: Row(
              children: [
                Expanded(
                  child: _OrderStatusTile(
                    icon: Iconsax.clock,
                    label: 'Kutilmoqda',
                    count: 0,
                  ),
                ),
                Expanded(
                  child: _OrderStatusTile(
                    icon: Iconsax.box_1,
                    label: 'Tayyorlanmoqda',
                    count: 0,
                  ),
                ),
                Expanded(
                  child: _OrderStatusTile(
                    icon: Iconsax.box_time,
                    label: "Yo'lda",
                    count: 0,
                  ),
                ),
                Expanded(
                  child: _OrderStatusTile(
                    icon: Iconsax.tick_circle,
                    label: 'Yetkazilgan',
                    count: 0,
                    showCount: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusTile extends StatelessWidget {
  const _OrderStatusTile({
    required this.icon,
    required this.label,
    required this.count,
    this.showCount = true,
  });

  final IconData icon;
  final String label;
  final int count;

  /// Delivered orders accumulate over time and aren't actionable, so the
  /// badge is suppressed there to keep the row's visual weight balanced.
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: pt.imageBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: pt.dark),
                ),
                if (showCount && count > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: PremiumTokens.accent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: pt.surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: PremiumTokens.body(
                          size: 10,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: PremiumTokens.body(size: 11, color: pt.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Become-a-seller premium banner
// ---------------------------------------------------------------------------

class _BecomeSellerBanner extends StatelessWidget {
  const _BecomeSellerBanner({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PremiumTokens.accent, PremiumTokens.accentDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumTokens.accentDeep.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Iconsax.shop, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                'Sotuvchi bo\'lish',
                style: PremiumTokens.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Mebellar'da o'z biznesingizni boshlang",
            style: PremiumTokens.display(
              size: 22,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Mahsulotlaringizni minglab xaridorlarga "
            "yetkazing va sotuvni bugundan boshlang.",
            style: PremiumTokens.body(
              size: 13,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sotuvchi bo'lish",
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: PremiumTokens.accentDeep,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Iconsax.arrow_right_1,
                        size: 16,
                        color: PremiumTokens.accentDeep,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu list (settings + info)
// ---------------------------------------------------------------------------

class _MenuListCard extends StatelessWidget {
  const _MenuListCard({required this.items});

  final List<_MenuEntry> items;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        children: [
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
              Icon(Icons.chevron_right, size: 20, color: pt.greyLight),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Danger zone
// ---------------------------------------------------------------------------

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onSignOut, required this.onDeleteAccount});

  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onSignOut,
            icon: Icon(Iconsax.logout, size: 18, color: pt.dark),
            label: Text(
              'Chiqish',
              style: PremiumTokens.body(
                size: 14,
                weight: FontWeight.w600,
                color: pt.dark,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: pt.surface,
              side: BorderSide(color: pt.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onDeleteAccount,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE05A4A),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            "Akkauntni o'chirish",
            style: PremiumTokens.body(
              size: 13,
              weight: FontWeight.w500,
              color: const Color(0xFFE05A4A),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seller pending banner
// ---------------------------------------------------------------------------

class _SellerPendingBanner extends StatelessWidget {
  const _SellerPendingBanner();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PremiumTokens.accent.withValues(alpha: 0.3)),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PremiumTokens.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 22,
              color: PremiumTokens.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ko'rib chiqilmoqda",
                  style: PremiumTokens.body(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Arizangiz 24 soat ichida ko'rib chiqiladi.",
                  style: PremiumTokens.body(
                    size: 13,
                    color: pt.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Static data
// ---------------------------------------------------------------------------

class _MenuEntry {
  const _MenuEntry({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

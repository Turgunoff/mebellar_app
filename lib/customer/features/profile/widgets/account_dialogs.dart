import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/sign_out.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../../orders/cubit/profile_orders_cubit.dart';

/// Confirms sign-out, then runs the push-cleanup sign-out flow.
Future<void> showSignOutDialog(BuildContext context) async {
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
              style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.4),
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
  if (confirmed == true && context.mounted) {
    await signOutWithPushCleanup(Supabase.instance.client);
  }
}

/// Account-deletion flow: blocks when active orders exist, otherwise shows a
/// type-to-confirm dialog and hard-deletes the account.
Future<void> confirmAccountDeletion(BuildContext context) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  final s = context.read<ProfileOrdersCubit>().state;
  final activeCount = s.pendingCount + s.processingCount + s.deliveringCount;
  if (activeCount > 0) {
    _showActiveOrdersWarning(context);
    return;
  }

  final pt = PremiumTokens.of(context);
  final ctrl = TextEditingController();
  bool isLoading = false;

  final rootNav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => Dialog(
        backgroundColor: pt.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: SingleChildScrollView(
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
                style:
                    PremiumTokens.body(size: 13, color: pt.grey, height: 1.45),
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
                enabled: !isLoading,
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
                      onPressed: isLoading ? null : rootNav.pop,
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
                                  await Supabase.instance.client.rpc(
                                    'delete_user_account',
                                  );
                                  await _clearLocalAfterDelete();
                                  rootNav.pop();
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
                                  setStateDialog(() => isLoading = false);
                                  messenger.showSnackBar(
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
}

/// Modal explaining why account deletion is blocked while orders are active.
void _showActiveOrdersWarning(BuildContext context) {
  final pt = PremiumTokens.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        0,
        28,
        MediaQuery.paddingOf(ctx).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 28),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: pt.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0x1AE05A4A),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: Color(0xFFE05A4A),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Amalni bajarib bo'lmaydi",
            style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "Sizda faol buyurtmalar mavjud. Akkauntni o'chirish uchun "
            "avval ularni qabul qiling yoki bekor qiling.",
            textAlign: TextAlign.center,
            style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.55),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: PremiumTokens.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Tushunarli',
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Best-effort local cleanup after a successful server-side account delete.
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
    talker.warning('Local cleanup after delete failed', e, st);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/auth/sign_out.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/woody_api_client.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../orders/cubit/profile_orders_cubit.dart';

/// Confirms sign-out, then runs the push-cleanup sign-out flow. [authRepository]
/// is nullable — not every scope registers one — mirroring the old
/// `sl.isRegistered<AuthRepository>()` guard.
Future<void> showSignOutDialog(
  BuildContext context, {
  required AuthRepository? authRepository,
}) async {
  final pt = PremiumTokens.of(context);
  final dangerColor = Theme.of(context).colorScheme.error;
  // Bottom sheet (not a centered Dialog) to match the app's other confirm
  // sheets — `_showDeletionBlockedSheet` below and Settings' analytics info
  // sheet — instead of a one-off dialog shape.
  final confirmed = await showModalBottomSheet<bool>(
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
        8,
        28,
        MediaQuery.paddingOf(ctx).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Theme already draws the drag handle (`showDragHandle: true` in
        // app_theme.dart) — don't add a second bar here or the sheet shows
        // two stacked dashes.
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: dangerColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Iconsax.logout_copy, size: 30, color: dangerColor),
          ),
          const SizedBox(height: 20),
          Text(
            tr('profile.sign_out_title'),
            style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            tr('profile.sign_out_confirm'),
            textAlign: TextAlign.center,
            style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.55),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: dangerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                tr('profile.sign_out_action'),
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: pt.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                tr('profile.cancel'),
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w600,
                  color: pt.dark,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (confirmed == true && context.mounted) {
    if (authRepository != null) {
      await signOutWithPushCleanup(authRepository);
    }
  }
}

/// Account-deletion flow: blocks when active orders exist, otherwise shows a
/// type-to-confirm dialog and soft-deletes the account via `DELETE /me`.
Future<void> confirmAccountDeletion(
  BuildContext context, {
  required AuthRepository? authRepository,
  required WoodyApiClient api,
}) async {
  if (authRepository == null || !authRepository.isAuthenticated) {
    return;
  }

  final s = context.read<ProfileOrdersCubit>().state;
  final activeCount = s.pendingCount + s.processingCount + s.deliveringCount;
  if (activeCount > 0) {
    _showDeletionBlockedSheet(
      context,
      message: _deletionBlockedMessage('has_active_orders')!,
    );
    return;
  }

  final pt = PremiumTokens.of(context);
  final ctrl = TextEditingController();
  bool isLoading = false;

  // Captured on the context ambient to `showModalBottomSheet` (NOT
  // rootNavigator — the sheet route lives on the nearest Navigator by
  // default) so it stays valid to pop from inside the async onPressed below,
  // after `ctx` may no longer be safe to use across the `await` gaps.
  final sheetNav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final dangerColor = Theme.of(context).colorScheme.error;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateSheet) => Container(
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          28,
          8,
          28,
          MediaQuery.viewInsetsOf(ctx).bottom +
              MediaQuery.paddingOf(ctx).bottom +
              28,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Theme already draws the drag handle (`showDragHandle: true` in
            // app_theme.dart) — don't add a second bar here or the sheet
            // shows two stacked dashes.
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: dangerColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Iconsax.trash, size: 30, color: dangerColor),
              ),
              const SizedBox(height: 20),
              Text(
                tr('profile.delete_account_title'),
                style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                tr('profile.delete_account_body'),
                textAlign: TextAlign.center,
                style: PremiumTokens.body(
                  size: 13.5,
                  color: pt.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('profile.delete_account_type_confirm'),
                  style: PremiumTokens.body(size: 13, color: pt.dark),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                enabled: !isLoading,
                style: PremiumTokens.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: dangerColor,
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
                    borderSide: BorderSide(color: dangerColor, width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: pt.divider, width: 1),
                  ),
                ),
                onChanged: (_) => setStateSheet(() {}),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: ctrl,
                  builder: (_, val, _) => FilledButton(
                    onPressed: val.text == 'DELETE' && !isLoading
                        ? () async {
                            setStateSheet(() => isLoading = true);
                            try {
                              await api.delete<void>('/me');
                              await _clearLocalAfterDelete();
                              sheetNav.pop();
                              await signOutWithPushCleanup(authRepository);
                              appLog.info('Account soft-deleted successfully');
                            } catch (e, st) {
                              // The server has the final say — an order went
                              // active, or a seller's wallet isn't settled,
                              // between the local checks and this call. Map
                              // the known 409 block codes to a sheet and
                              // crucially DO NOT sign out.
                              if (e is ApiError) {
                                final blockedMessage = _deletionBlockedMessage(
                                  e.code,
                                );
                                if (blockedMessage != null) {
                                  appLog.info(
                                    'Account deletion blocked: ${e.code}',
                                  );
                                  sheetNav.pop();
                                  if (context.mounted) {
                                    _showDeletionBlockedSheet(
                                      context,
                                      message: blockedMessage,
                                    );
                                  }
                                  return;
                                }
                              }
                              appLog.error('Account deletion failed', e, st);
                              setStateSheet(() => isLoading = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tr(
                                      'profile.delete_account_error',
                                      namedArgs: {'error': '$e'},
                                    ),
                                    style: PremiumTokens.body(
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: dangerColor,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: dangerColor,
                      disabledBackgroundColor: dangerColor.withValues(
                        alpha: 0.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            tr('profile.confirm'),
                            style: PremiumTokens.body(
                              size: 15,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: isLoading ? null : sheetNav.pop,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: pt.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    tr('profile.cancel'),
                    style: PremiumTokens.body(
                      size: 15,
                      weight: FontWeight.w600,
                      color: pt.dark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Localized reason for each `DELETE /me` 409 block code, or null when the
/// code isn't a deletion-block reason (caller falls back to the generic error
/// snackbar). Hardcoded Uzbek to match the rest of this account flow.
String? _deletionBlockedMessage(String code) => switch (code) {
  'has_active_orders' => tr('profile.delete_blocked_active_orders'),
  'has_debt' => tr('profile.delete_blocked_has_debt'),
  'has_unwithdrawn_funds' => tr('profile.delete_blocked_unwithdrawn_funds'),
  _ => null,
};

/// Modal explaining why account deletion is blocked (active orders, wallet
/// debt, or unwithdrawn funds). The title is generic; [message] carries the
/// specific reason.
void _showDeletionBlockedSheet(
  BuildContext context, {
  required String message,
}) {
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
        8,
        28,
        MediaQuery.paddingOf(ctx).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Theme already draws the drag handle (`showDragHandle: true` in
        // app_theme.dart) — don't add a second bar here or the sheet shows
        // two stacked dashes.
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            tr('profile.action_blocked_title'),
            style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
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
                tr('profile.understood'),
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
    appLog.warning('Local cleanup after delete failed', e, st);
  }
}

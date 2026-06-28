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
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Iconsax.logout_copy,
                size: 24,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('profile.sign_out_title'),
              style: PremiumTokens.display(size: 20, letterSpacing: -0.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              tr('profile.sign_out_confirm'),
              style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: _cancelButtonStyle(pt),
                    child: _buttonLabel(tr('profile.cancel'), color: pt.dark),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: _dangerButtonStyle(Theme.of(ctx).colorScheme.error),
                    child: _buttonLabel(
                      tr('profile.sign_out_action'),
                      color: Colors.white,
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
    if (sl.isRegistered<AuthRepository>()) {
      await signOutWithPushCleanup(sl<AuthRepository>());
    }
  }
}

/// Account-deletion flow: blocks when active orders exist, otherwise shows a
/// type-to-confirm dialog and soft-deletes the account via `DELETE /me`.
Future<void> confirmAccountDeletion(BuildContext context) async {
  if (!sl.isRegistered<AuthRepository>() ||
      !sl<AuthRepository>().isAuthenticated) {
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

  final rootNav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final dangerColor = Theme.of(context).colorScheme.error;

  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => Dialog(
        backgroundColor: pt.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Iconsax.trash,
                  size: 22,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tr('profile.delete_account_title'),
                style: PremiumTokens.display(size: 20, letterSpacing: -0.2),
              ),
              const SizedBox(height: 10),
              Text(
                tr('profile.delete_account_body'),
                style: PremiumTokens.body(
                  size: 13,
                  color: pt.grey,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('profile.delete_account_type_confirm'),
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
                  color: Theme.of(context).colorScheme.error,
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
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
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
                      style: _cancelButtonStyle(pt),
                      child: _buttonLabel(tr('profile.cancel'), color: pt.dark),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: ctrl,
                      builder: (_, val, _) => FilledButton(
                        onPressed: val.text == 'DELETE' && !isLoading
                            ? () async {
                                setStateDialog(() => isLoading = true);
                                try {
                                  await sl<WoodyApiClient>().delete<void>(
                                    '/me',
                                  );
                                  await _clearLocalAfterDelete();
                                  rootNav.pop();
                                  await signOutWithPushCleanup(
                                    sl<AuthRepository>(),
                                  );
                                  appLog.info(
                                    'Account soft-deleted successfully',
                                  );
                                } catch (e, st) {
                                  // The server has the final say — an order
                                  // went active, or a seller's wallet isn't
                                  // settled, between the local checks and this
                                  // call. Map the known 409 block codes to a
                                  // sheet and crucially DO NOT sign out.
                                  if (e is ApiError) {
                                    final blockedMessage =
                                        _deletionBlockedMessage(e.code);
                                    if (blockedMessage != null) {
                                      appLog.info(
                                        'Account deletion blocked: ${e.code}',
                                      );
                                      rootNav.pop();
                                      if (context.mounted) {
                                        _showDeletionBlockedSheet(
                                          context,
                                          message: blockedMessage,
                                        );
                                      }
                                      return;
                                    }
                                  }
                                  appLog.error(
                                    'Account deletion failed',
                                    e,
                                    st,
                                  );
                                  setStateDialog(() => isLoading = false);
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
                        style: _dangerButtonStyle(
                          Theme.of(context).colorScheme.error,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : _buttonLabel(
                                tr('profile.confirm'),
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
    ),
  );
}

/// Localized reason for each `DELETE /me` 409 block code, or null when the
/// code isn't a deletion-block reason (caller falls back to the generic error
/// snackbar). Hardcoded Uzbek to match the rest of this account flow.
String? _deletionBlockedMessage(String code) => switch (code) {
  'has_active_orders' =>
    tr('profile.delete_blocked_active_orders'),
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

// Default M3 button padding (24px) wraps "Tasdiqlash" onto two lines inside
// the narrow dialog — compact padding + a scale-down label keep one line.
ButtonStyle _cancelButtonStyle(PremiumTokens pt) => OutlinedButton.styleFrom(
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 10),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  side: BorderSide(color: pt.divider),
);

ButtonStyle _dangerButtonStyle(Color danger) => FilledButton.styleFrom(
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 10),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: danger,
  disabledBackgroundColor: danger.withValues(alpha: 0.3),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

Widget _buttonLabel(String text, {required Color color}) => FittedBox(
  fit: BoxFit.scaleDown,
  child: Text(
    text,
    maxLines: 1,
    style: PremiumTokens.body(size: 14, weight: FontWeight.w600, color: color),
  ),
);

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

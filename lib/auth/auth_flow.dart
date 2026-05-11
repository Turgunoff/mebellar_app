import 'package:flutter/material.dart';

import '../config/app_mode.dart';
import '../core/auth/auth_repository.dart';
import '../core/di/service_locator.dart';
import 'login_screen.dart';
import 'widgets/mode_chooser_bottom_sheet.dart';

/// Open the login flow as a fullscreen modal route. Resolves to `true` when
/// the user successfully authenticated, `false` if they dismissed the modal.
///
/// On success, if the freshly fetched profile shows an approved seller
/// account, prompts the user with the mode chooser. Picking seller triggers
/// `switchAppMode` (with Phoenix rebirth); customer just closes the modal.
Future<bool> showAuthFlow(BuildContext context) async {
  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => const LoginScreen(),
    ),
  );
  if (ok != true || !context.mounted) return false;

  if (!sl.isRegistered<AuthRepository>()) return true;
  try {
    final me = await sl<AuthRepository>().fetchMe();
    if (me.sellerProfile?.isApproved == true && context.mounted) {
      final pick = await showModeChooserBottomSheet(context);
      if (pick == AppMode.seller && context.mounted) {
        await switchAppMode(context, AppMode.seller);
      }
    }
  } catch (_) {
    // Profile lookup is best-effort here; the user is signed in either way.
  }
  return true;
}

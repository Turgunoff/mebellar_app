import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/premium_tokens.dart';

/// Sign-out button at the bottom of the profile screen. Account deletion
/// lives in [SettingsScreen] alongside the app's other account-level actions.
class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onSignOut,
        icon: Icon(Iconsax.logout_copy, size: 18, color: pt.dark),
        label: Text(
          tr('profile.sign_out_action'),
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../home/widgets/premium/premium_tokens.dart';

/// Sign-out button + destructive "delete account" link at the bottom of the
/// profile screen.
class DangerZone extends StatelessWidget {
  const DangerZone({
    super.key,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

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

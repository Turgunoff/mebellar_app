import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Small red pill showing an unread count — used on the profile "Suhbatlar"
/// rows. Renders nothing when [count] is zero so callers can drop it in
/// unconditionally. Caps at "99+".
class UnreadCountBadge extends StatelessWidget {
  const UnreadCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      constraints: const BoxConstraints(minWidth: 22),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.15,
        ),
      ),
    );
  }
}

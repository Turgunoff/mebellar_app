import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'auth_sheet_kit.dart';

/// Header row: optional back button, centred 3-dot step indicator, optional
/// close button.
class AuthSheetHeader extends StatelessWidget {
  const AuthSheetHeader({super.key, required this.step, this.onBack, this.onClose});

  final AuthStep step;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _IconBtn(icon: Iconsax.arrow_left_2_copy, onTap: onBack!),
            ),
          if (onClose != null)
            Align(
              alignment: Alignment.centerRight,
              child: _IconBtn(icon: Icons.close_rounded, onTap: onClose!),
            ),
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final active = i == step.index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? kTerracotta : t.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    return Material(
      color: t.fieldFill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: t.textPrimary),
        ),
      ),
    );
  }
}

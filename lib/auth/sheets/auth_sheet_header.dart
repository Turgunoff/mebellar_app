import 'package:flutter/material.dart';

import 'auth_sheet_kit.dart';

/// Drag-handle pill at the top of the sheet.
class AuthGrabber extends StatelessWidget {
  const AuthGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: kBorder,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Header row: optional back button, centred 3-dot step indicator, optional
/// close button.
class AuthSheetHeader extends StatelessWidget {
  const AuthSheetHeader({super.key, required this.step, this.onBack, this.onClose});

  final AuthStep step;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _IconBtn(icon: Icons.arrow_back_rounded, onTap: onBack!),
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
                    color: active ? kTerracotta : kBorder,
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
    return Material(
      color: kFieldFill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: kTextPrimary),
        ),
      ),
    );
  }
}

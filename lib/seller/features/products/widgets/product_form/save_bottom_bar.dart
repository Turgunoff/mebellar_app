import 'package:flutter/material.dart';

import '../../../../../core/theme/app_fonts.dart';

/// Sticky bottom CTA for the product form ("Saqlash va e'lon qilish").
class SaveBottomBar extends StatelessWidget {
  const SaveBottomBar({
    super.key,
    required this.enabled,
    required this.busy,
    required this.onSave,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled && !busy ? onSave : null,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Saqlash va e'lon qilish"),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';

/// The three "gold rules" shown before the AR scan camera opens — a clean
/// background, good lighting, and three distinct angles materially improve the
/// Meshy 3D result, so we surface them every time before capture.
const _rules = <(String, String)>[
  (
    'Toza fon',
    'Mahsulot atrofini bo‘shating — ortda ortiqcha narsa bo‘lmasin.',
  ),
  (
    'Yaxshi yoritish',
    'Xona yorug‘ bo‘lsin, qattiq soyalar va orqadan tushgan nurdan saqlaning.',
  ),
  (
    '3 xil burchakdan oling',
    'Old, yon va tepa-orqa tomonlardan to‘liq va aniq suratga oling.',
  ),
];

/// Shows the AR-scan onboarding sheet. Returns `true` when the seller taps
/// "Boshlash" (proceed to the camera), `false` if they dismiss it (swipe /
/// back / tap outside) — the caller must abort the camera push on `false`.
///
/// Uzbek-only with seller-local tokens, matching the rest of the add-product /
/// AR surface. Deliberately glyph-free (numbered badges, no [Icon]s) so it rides
/// a Shorebird OTA patch cleanly — new icon glyphs would not be in the shipped
/// tree-shaken font.
Future<bool> showArScanOnboardingSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Mount on the ROOT navigator — the same one the camera is pushed onto.
    // Otherwise this sheet lands on the seller shell's branch navigator while
    // the camera goes to root, and the cross-navigator split lets exiting the
    // camera tear down the product-detail route underneath ("over-pop"). One
    // navigator for the whole confirm → rules → camera sequence.
    useRootNavigator: true,
    routeSettings: const RouteSettings(name: '/ar-scan-onboarding'),
    builder: (_) => const _ArScanOnboardingSheet(),
  );
  return ok ?? false;
}

class _ArScanOnboardingSheet extends StatelessWidget {
  const _ArScanOnboardingSheet();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '3D skan qoidalari',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sifatli 3D model olish uchun 3 ta oddiy qoidaga amal qiling.',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12.5,
                color: c.grey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < _rules.length; i++) ...[
              _RuleRow(step: i + 1, title: _rules[i].$1, body: _rules[i].$2),
              if (i < _rules.length - 1) const SizedBox(height: 14),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                child: const Text('Boshlash'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.step, required this.title, required this.body});

  final int step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Numbered badge — no icon glyph, so the sheet stays OTA-patch safe.
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: c.primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12.5,
                  color: c.grey,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

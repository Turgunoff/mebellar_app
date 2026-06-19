import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/theme/app_colors.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/core/theme/app_theme_extension.dart';

/// Guards the customer theme's registered [ThemeExtension]s.
///
/// Regression for the "white cards in dark mode" bug: a few customer screens
/// (product detail, shop profile) reuse seller-mode preview cards that read
/// `SellerColors.of(context)`. If [SellerColors] is not registered on the
/// customer theme it silently falls back to [SellerColors.light] (white
/// surfaces) and never flips to dark — so we assert the brightness-matched set
/// is present on both customer themes.
void main() {
  Future<({SellerColors seller, AppCustomColors custom})> resolveUnder(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    late SellerColors seller;
    late AppCustomColors custom;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            seller = SellerColors.of(context);
            custom = Theme.of(context).extension<AppCustomColors>()!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return (seller: seller, custom: custom);
  }

  testWidgets('customer light theme resolves the light seller surface set', (
    tester,
  ) async {
    final r = await resolveUnder(tester, AppTheme.lightTheme);
    expect(r.seller.surface, AppColors.sellerSurface);
    expect(r.seller.ink, AppColors.sellerInk);
    expect(r.custom.successContainer, AppColors.successContainer);
    expect(r.custom.warningContainer, AppColors.warningContainer);
  });

  testWidgets('customer dark theme resolves the DARK seller surface set', (
    tester,
  ) async {
    final r = await resolveUnder(tester, AppTheme.darkTheme);
    // The bug surfaced exactly here: without registration this was the light
    // white surface even in dark mode.
    expect(r.seller.surface, AppColors.sellerSurfaceDark);
    expect(r.seller.ink, AppColors.sellerInkDark);
    expect(r.custom.successContainer, AppColors.successContainerDark);
    expect(r.custom.warningContainer, AppColors.warningContainerDark);
  });
}

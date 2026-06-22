import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/shared/widgets/premium_empty_state.dart';

/// Centring guard for [PremiumEmptyState].
///
/// The empty state must float dead-centre within the available body height —
/// the area between the header/status bar and the bottom nav, NOT the physical
/// screen centre. These tests pin that: the content sits at the body midpoint
/// regardless of how much chrome (bottom nav, notch) is reserved around it.
void main() {
  // Renders the widget inside a top-anchored body of [bodyHeight] on a screen
  // of [screenHeight], then returns the vertical midpoint of the rendered
  // content (icon top → subtitle bottom).
  Future<double> contentCentre(
    WidgetTester tester, {
    required double screenHeight,
    required double bodyHeight,
  }) async {
    // The default test surface is 800x600, which would clamp a taller body —
    // size the render surface to the screen so the body gets its full height.
    await tester.binding.setSurfaceSize(Size(400, screenHeight));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(400, screenHeight)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: AppTheme.lightTheme,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: bodyHeight,
                width: 400,
                child: const PremiumEmptyState(
                  icon: Icons.shopping_bag,
                  title: 'Empty',
                  subtitle: 'Nothing here',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final iconTop = tester.getTopLeft(find.byIcon(Icons.shopping_bag)).dy;
    final subtitleBottom = tester.getBottomLeft(find.text('Nothing here')).dy;
    return (iconTop + subtitleBottom) / 2;
  }

  testWidgets('centres at the body midpoint when body == screen', (
    tester,
  ) async {
    // body == screen → content sits at the body centre (~400).
    final centre = await contentCentre(
      tester,
      screenHeight: 800,
      bodyHeight: 800,
    );
    expect(centre, closeTo(400, 20));
  });

  testWidgets('centres within the body, not the screen, when nav reserves '
      'space below', (tester) async {
    // body (600) shorter than screen (800): the content must centre on the body
    // midpoint (~300), NOT drift toward the physical screen centre (400). The
    // body height is all the widget is given, so that midpoint is the true
    // centre between header and bottom nav.
    final centre = await contentCentre(
      tester,
      screenHeight: 800,
      bodyHeight: 600,
    );
    expect(centre, closeTo(300, 20));
  });

  testWidgets('centres within the safe body on a notched phone', (
    tester,
  ) async {
    // Faithful notch geometry: 844-tall screen, 47 top inset, ~83 flush bottom
    // nav. The body the Scaffold hands down (no extendBody) is screen - nav,
    // and SafeArea(bottom:false) consumes the 47 top inset. The content centre
    // must land on the midpoint of the safe body — topInset + (body - topInset)
    // / 2 == 404 — i.e. dead-centre between the status bar and the nav.
    const screenH = 844.0;
    const topInset = 47.0;
    const navBar = 83.0;
    const bodyH = screenH - navBar;
    await tester.binding.setSurfaceSize(const Size(390, screenH));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, screenH),
          viewPadding: EdgeInsets.only(top: topInset),
          padding: EdgeInsets.only(top: topInset),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: AppTheme.lightTheme,
            child: Align(
              alignment: Alignment.topCenter,
              child: const SizedBox(
                height: bodyH,
                width: 390,
                child: SafeArea(
                  bottom: false,
                  child: PremiumEmptyState(
                    icon: Icons.shopping_bag,
                    title: 'Empty',
                    subtitle: 'Nothing here',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final iconTop = tester.getTopLeft(find.byIcon(Icons.shopping_bag)).dy;
    final subtitleBottom = tester.getBottomLeft(find.text('Nothing here')).dy;
    final centre = (iconTop + subtitleBottom) / 2;
    expect(centre, closeTo(topInset + (bodyH - topInset) / 2, 14));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/dashboard/data/dashboard_mock.dart';
import 'package:woody_app/seller/features/dashboard/screens/achievements_screen.dart';
import 'package:woody_app/seller/features/dashboard/widgets/achievements_strip.dart';
import 'package:woody_app/seller/features/dashboard/widgets/dashboard_kit.dart';
import 'package:woody_app/seller/features/dashboard/widgets/hero_sales_card.dart';
import 'package:woody_app/seller/features/dashboard/widgets/kpi_card.dart';
import 'package:woody_app/seller/features/dashboard/widgets/seller_leaderboard.dart';
import 'package:woody_app/seller/features/dashboard/widgets/top_products_card.dart';

/// These pump the redesigned dashboard sections against realistic mock data
/// and assert they render without layout exceptions (overflow / unbounded
/// constraints) — the main risk for a multi-section scroll view with nested
/// horizontal lists and custom painters. They run without DI/auth because the
/// rich sections are mock-driven, not cubit-driven.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('HeroSalesCard renders the week revenue and a delta', (
    tester,
  ) async {
    await pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(20),
        child: HeroSalesCard(
          weekRevenue: 42300000,
          series: DashboardMock.mockRevenueSeries,
          weekdayLabels: DashboardMock.mockWeekdayLabels,
          deltaPercent: DashboardMock.mockSalesDeltaPercent,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Bu hafta savdo'), findsOneWidget);
    expect(find.text('+18.4%'), findsOneWidget);
    // Every weekday label paints under the sparkline.
    for (final d in DashboardMock.mockWeekdayLabels) {
      expect(find.text(d), findsOneWidget);
    }
  });

  testWidgets('KPI card shows a delta trend chip when given one', (
    tester,
  ) async {
    await pump(
      tester,
      const SizedBox(
        width: 180,
        height: 160,
        child: SellerKpiCard(
          icon: Icons.shopping_bag,
          title: 'Bugungi orderlar',
          value: '12',
          delta: 12.0,
        ),
      ),
    );
    expect(find.text('+12.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SellerLeaderboard highlights the current shop', (tester) async {
    await pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(20),
        child: SellerLeaderboard(entries: DashboardMock.mockLeaderboard),
      ),
    );
    // The current shop shows its real name + the "Siz" tag.
    expect(find.text('Zumar Mebel'), findsOneWidget);
    expect(find.text('Siz'), findsOneWidget);
    // Competitors are anonymised — the full name must NOT appear.
    expect(find.text('Bravo Mebel'), findsNothing);
    expect(find.text('B•••• M••••'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AchievementsStrip scrolls a row of badges without overflow', (
    tester,
  ) async {
    await pump(
      tester,
      const SizedBox(
        height: 132,
        child: AchievementsStrip(achievements: DashboardMock.mockAchievements),
      ),
    );
    expect(find.text('Birinchi savdo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TopProductsCard renders ranked rows', (tester) async {
    await pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(20),
        child: TopProductsCard(products: DashboardMock.mockTopProducts),
      ),
    );
    expect(find.text('Burchakli divan "Modern"'), findsOneWidget);
    expect(find.text('14 dona'), findsOneWidget);
    // Trend chip instead of a fill bar.
    expect(find.text('+24.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('DashKit.money groups thousands with thin spaces', () {
    expect(DashKit.money(9650000), '9 650 000');
    expect(DashKit.money(0), '0');
    expect(DashKit.money(640), '640');
  });

  test('DashKit.compactMoney abbreviates large sums', () {
    expect(DashKit.compactMoney(33600000), '33.6 mln');
    expect(DashKit.compactMoney(9800000), '9.8 mln');
    expect(DashKit.compactMoney(640), '640');
  });

  test('LeaderboardEntry.displayName masks competitors, not the owner', () {
    const me = LeaderboardEntry(
      rank: 4,
      shopName: 'Zumar Mebel',
      revenue: 1,
      deltaPercent: 0,
      isMe: true,
    );
    const other = LeaderboardEntry(
      rank: 1,
      shopName: 'Bravo Mebel',
      revenue: 1,
      deltaPercent: 0,
    );
    expect(me.displayName, 'Zumar Mebel');
    expect(other.displayName, 'B•••• M••••');
  });

  test('Achievement.progress is current / target, clamped to 1', () {
    const a = Achievement(
      icon: Icons.star,
      title: 't',
      caption: 'c',
      current: 18,
      target: 50,
      unlocked: false,
      reward: 'r',
    );
    expect(a.progress, closeTo(0.36, 1e-9));
    const done = Achievement(
      icon: Icons.star,
      title: 't',
      caption: 'c',
      current: 10,
      target: 10,
      unlocked: true,
      reward: 'r',
    );
    expect(done.progress, 1.0);
  });

  testWidgets('AchievementsScreen lists earned + locked goals with rewards', (
    tester,
  ) async {
    // Tall viewport so the whole list lays out without scrolling off-screen
    // children into existence.
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AchievementsScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Overall progress header (2 of 6 unlocked in the mock).
    expect(find.text('2 / 6 yutuq'), findsOneWidget);
    // Both group labels render.
    expect(find.text("Qo'lga kiritilgan"), findsOneWidget);
    expect(find.text('Davom etmoqda'), findsOneWidget);
    // A reward panel is shown for the cards.
    expect(find.text('Mukofot'), findsWidgets);
    // A locked goal shows its "x / y" progress counter.
    expect(find.text('18 / 50'), findsOneWidget);
  });
}

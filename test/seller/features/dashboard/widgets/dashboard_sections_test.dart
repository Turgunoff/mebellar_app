import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:woody_app/seller/features/dashboard/data/dashboard_models.dart';
import 'package:woody_app/seller/features/dashboard/screens/achievements_screen.dart';
import 'package:woody_app/seller/features/dashboard/widgets/achievements_strip.dart';
import 'package:woody_app/seller/features/dashboard/widgets/dashboard_kit.dart';
import 'package:woody_app/seller/features/dashboard/widgets/hero_sales_card.dart';
import 'package:woody_app/seller/features/dashboard/widgets/kpi_card.dart';
import 'package:woody_app/seller/features/dashboard/widgets/seller_leaderboard.dart';
import 'package:woody_app/seller/features/dashboard/widgets/top_products_card.dart';
import 'package:woody_app/shared/models/dashboard_snapshot.dart';

/// These pump the dashboard sections against realistic sample data and assert
/// they render without layout exceptions (overflow / unbounded constraints) —
/// the main risk for a multi-section scroll view with nested horizontal lists
/// and custom painters. They run without DI/auth: the sections are pure
/// widgets fed view-models, decoupled from the cubit.
///
/// Leaderboard names are pre-masked here on purpose — anonymisation moved to
/// the backend (`SellerLeaderboardRepository`), so the client now trusts the
/// `shop_name` it receives verbatim.
const _series = <double>[
  3200000,
  4750000,
  4100000,
  6900000,
  5400000,
  8300000,
  9650000,
];
const _labels = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

const _leaderboard = <LeaderboardEntry>[
  LeaderboardEntry(rank: 1, shopName: 'B•••• M••••', revenue: 84300000),
  LeaderboardEntry(rank: 2, shopName: 'S•••• H•••', revenue: 71900000),
  LeaderboardEntry(
    rank: 4,
    shopName: 'Zumar Mebel',
    revenue: 42300000,
    deltaPercent: 18.4,
    isMe: true,
  ),
];

final _strip = <Achievement>[
  Achievement(
    icon: FontAwesomeIcons.star,
    title: 'Birinchi savdo',
    caption: 'Bajarildi',
    current: 1,
    target: 1,
    unlocked: true,
    reward: 'r',
  ),
];

const _topProducts = <TopProduct>[
  TopProduct(
    name: 'Burchakli divan "Modern"',
    imageUrl: null,
    unitsSold: 14,
    revenue: 33600000,
    deltaPercent: 24.0,
  ),
];

Achievement _ach(
  String title, {
  required int current,
  required int target,
  required bool unlocked,
}) => Achievement(
  icon: FontAwesomeIcons.star,
  title: title,
  caption: unlocked ? 'Bajarildi' : 'Davom etmoqda',
  current: current,
  target: target,
  unlocked: unlocked,
  reward: 'Mukofot matni',
);

final _screenAchievements = <Achievement>[
  _ach('Birinchi savdo', current: 1, target: 1, unlocked: true),
  _ach('10 ta buyurtma', current: 10, target: 10, unlocked: true),
  _ach('Reyting yulduzi', current: 48, target: 50, unlocked: false),
  _ach('50 ta mahsulot', current: 18, target: 50, unlocked: false),
  _ach('Tez yetkazuvchi', current: 7, target: 10, unlocked: false),
  _ach('Aylanma', current: 2, target: 5, unlocked: false),
];

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
          series: _series,
          weekdayLabels: _labels,
          deltaPercent: 18.4,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Bu hafta savdo'), findsOneWidget);
    expect(find.text('+18.4%'), findsOneWidget);
    for (final d in _labels) {
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
        child: SellerLeaderboard(entries: _leaderboard),
      ),
    );
    // The current shop shows its real name + the "Siz" tag.
    expect(find.text('Zumar Mebel'), findsOneWidget);
    expect(find.text('Siz'), findsOneWidget);
    // Competitor rows render the server-masked name verbatim.
    expect(find.text('B•••• M••••'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AchievementsStrip scrolls a row of badges without overflow', (
    tester,
  ) async {
    await pump(
      tester,
      SizedBox(height: 132, child: AchievementsStrip(achievements: _strip)),
    );
    expect(find.text('Birinchi savdo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TopProductsCard renders ranked rows', (tester) async {
    await pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(20),
        child: TopProductsCard(products: _topProducts),
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

  test('LeaderboardEntry.displayName trusts the server-provided name', () {
    // Anonymisation is the server's job now — the client shows what it gets.
    const me = LeaderboardEntry(rank: 4, shopName: 'Zumar Mebel', revenue: 1, isMe: true);
    const other = LeaderboardEntry(rank: 1, shopName: 'B•••• M••••', revenue: 1);
    expect(me.displayName, 'Zumar Mebel');
    expect(other.displayName, 'B•••• M••••');
  });

  test('Achievement.progress is current / target, clamped to 1', () {
    const a = Achievement(
      icon: FontAwesomeIcons.star,
      title: 't',
      caption: 'c',
      current: 18,
      target: 50,
      unlocked: false,
      reward: 'r',
    );
    expect(a.progress, closeTo(0.36, 1e-9));
    const done = Achievement(
      icon: FontAwesomeIcons.star,
      title: 't',
      caption: 'c',
      current: 10,
      target: 10,
      unlocked: true,
      reward: 'r',
    );
    expect(done.progress, 1.0);
  });

  test('Achievement.fromProgress collapses revenue goals to millions', () {
    final a = Achievement.fromProgress(
      const AchievementProgress(
        code: 'revenue_5m',
        titleUz: '5 mln aylanma',
        titleRu: 'Оборот 5 млн',
        icon: 'wallet',
        requirementType: 'revenue_realized',
        threshold: 5000000,
        progress: 2400000,
        unlocked: false,
      ),
    );
    // 2.4M / 5M → a clean "2 / 5" counter.
    expect(a.current, 2);
    expect(a.target, 5);
    expect(a.unlocked, isFalse);
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

    await tester.pumpWidget(
      MaterialApp(home: AchievementsScreen(achievements: _screenAchievements)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Overall progress header (2 of 6 unlocked).
    expect(find.text('2 / 6 yutuq'), findsOneWidget);
    // Both group labels render.
    expect(find.text("Qo'lga kiritilgan"), findsOneWidget);
    expect(find.text('Davom etmoqda'), findsWidgets);
    // A reward panel is shown for the locked cards.
    expect(find.text('Mukofot'), findsWidgets);
    // A locked goal shows its "x / y" progress counter.
    expect(find.text('18 / 50'), findsOneWidget);
  });
}

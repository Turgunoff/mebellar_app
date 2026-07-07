// Showcase data layer for the landing-page screenshot run
// (`screenshot_generator_test.dart`). The production catalog is empty
// pre-launch, so these fakes shadow the Woody data sources inside a dedicated
// GetIt scope and feed the UI hand-curated, real-looking content: Uzbek
// product names, verified Unsplash furniture photography, and a seller
// dashboard with a believable week of trading. Nothing here ships in the app
// binary — `integration_test/` targets are compiled only by `flutter drive`.

import 'dart:async';

import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/shared/models/banner.dart';
import 'package:woody_app/shared/models/dashboard_snapshot.dart';
import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/models/order_status.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/models/review.dart';
import 'package:woody_app/shared/models/tariff.dart';
import 'package:woody_app/shared/repositories/banner_repository.dart';
import 'package:woody_app/shared/repositories/customer_reviews_repository.dart';
import 'package:woody_app/shared/repositories/product_data_source.dart';
import 'package:woody_app/shared/repositories/seller_dashboard_repository.dart';

import '../test/fixtures/mocks/mock/mock_orders_data.dart';

String _unsplash(String id) =>
    'https://images.unsplash.com/photo-$id?w=1400&q=80';

// ─────────────────────────── Products ───────────────────────────

final List<ProductModel> showcaseProducts = [
  ProductModel(
    id: 'show-1',
    categoryId: 'show-cat-sofa',
    categoryName: 'Divanlar',
    name: 'Milan burchak divani',
    description: "Wood Line · premium velvet, dub oyoqlar",
    price: 4890000,
    discountPrice: 3990000,
    images: [
      _unsplash('1555041469-a586c61ea9bc'),
      _unsplash('1493663284031-b7e3aefcae8e'),
      _unsplash('1567538096630-e0c55bd6374c'),
    ],
    attributes: {
      'Material': 'Velvet, dub',
      'O‘rindiqlar': '4–5 kishi',
      'Eni': '280 sm',
      'Rang': 'Tungi ko‘k',
    },
    stock: 8,
    hasDelivery: true,
    deliveryPrice: 0,
    hasInstallation: true,
    installationPrice: 150000,
    warrantyMonths: 24,
    shopName: 'Wood Line',
    createdAt: DateTime(2026, 5, 28),
  ),
  ProductModel(
    id: 'show-2',
    categoryId: 'show-cat-bed',
    categoryName: 'Yotoqxona',
    name: 'Skandinaviya krovati 160×200',
    description: 'Mebel House · tabiiy qayin, boks bilan',
    price: 5490000,
    images: [
      _unsplash('1505693416388-ac5ce068fe85'),
      _unsplash('1567016432779-094069958ea5'),
    ],
    attributes: {
      'Material': 'Qayin yog‘ochi',
      'O‘lchami': '160×200 sm',
      'Boks': '2 ta tortma',
    },
    stock: 5,
    hasDelivery: true,
    deliveryPrice: 200000,
    hasInstallation: true,
    installationPrice: 250000,
    warrantyMonths: 18,
    shopName: 'Mebel House',
    createdAt: DateTime(2026, 5, 25),
  ),
  ProductModel(
    id: 'show-3',
    categoryId: 'show-cat-table',
    categoryName: 'Oshxona',
    name: 'Loft oshxona stoli',
    description: 'Casa Mebel · massiv dub, 6–8 kishilik',
    price: 2750000,
    images: [_unsplash('1449247709967-d4461a6a6103')],
    attributes: {
      'Material': 'Massiv dub',
      'O‘lchami': '160–240 sm',
      'Sig‘imi': '6–8 kishi',
    },
    stock: 7,
    hasDelivery: true,
    deliveryPrice: 150000,
    warrantyMonths: 12,
    shopName: 'Casa Mebel',
    createdAt: DateTime(2026, 5, 22),
  ),
  ProductModel(
    id: 'show-4',
    categoryId: 'show-cat-chair',
    categoryName: 'Kreslolar',
    name: 'Siena kreslosi',
    description: 'Wood Line · baxmal, yong‘oq oyoqlar',
    price: 1850000,
    discountPrice: 1480000,
    images: [_unsplash('1586023492125-27b2c045efd7')],
    attributes: {
      'Material': 'Baxmal',
      'Oyoqlar': 'Yong‘oq',
      'Rang': 'Zumrad yashil',
    },
    stock: 12,
    hasDelivery: true,
    deliveryPrice: 100000,
    warrantyMonths: 12,
    shopName: 'Wood Line',
    createdAt: DateTime(2026, 5, 20),
  ),
  ProductModel(
    id: 'show-5',
    categoryId: 'show-cat-sofa',
    categoryName: 'Divanlar',
    name: 'Tokio divan-krovat',
    description: 'Mebel House · kulrang lyon, yig‘iladigan',
    price: 3650000,
    images: [_unsplash('1567538096630-e0c55bd6374c')],
    attributes: {
      'Material': 'Lyon mato',
      'Mexanizm': 'Evroknijka',
      'Uxlash joyi': '140×200 sm',
    },
    stock: 6,
    hasDelivery: true,
    deliveryPrice: 150000,
    warrantyMonths: 12,
    shopName: 'Mebel House',
    createdAt: DateTime(2026, 5, 18),
  ),
  ProductModel(
    id: 'show-6',
    categoryId: 'show-cat-bed',
    categoryName: 'Yotoqxona',
    name: 'Verona yotoq garnituri',
    description: 'Casa Mebel · krovat + shkaf + tryumo',
    price: 8900000,
    images: [_unsplash('1538688525198-9b88f6f53126')],
    attributes: {
      'To‘plam': 'Krovat, shkaf, tryumo',
      'Material': 'MDF, shpon',
      'Krovat': '180×200 sm',
    },
    stock: 3,
    hasDelivery: true,
    deliveryPrice: 0,
    hasInstallation: true,
    installationPrice: 400000,
    warrantyMonths: 24,
    shopName: 'Casa Mebel',
    createdAt: DateTime(2026, 5, 15),
  ),
  ProductModel(
    id: 'show-7',
    categoryId: 'show-cat-table',
    categoryName: 'Ish stollari',
    name: 'Minimal ish stoli',
    description: 'Wood Line · eman, kabel kanali bilan',
    price: 1290000,
    images: [_unsplash('1524758631624-e2822e304c36')],
    attributes: {'Material': 'Eman', 'O‘lchami': '120×60 sm'},
    stock: 15,
    hasDelivery: true,
    deliveryPrice: 100000,
    warrantyMonths: 12,
    shopName: 'Wood Line',
    createdAt: DateTime(2026, 5, 12),
  ),
  ProductModel(
    id: 'show-8',
    categoryId: 'show-cat-chair',
    categoryName: 'Stullar',
    name: 'Oslo stuli',
    description: 'Mebel House · minimalist dizayn',
    price: 540000,
    images: [_unsplash('1592078615290-033ee584e267')],
    attributes: {'Material': 'Bук, charm', 'Rang': 'Qora'},
    stock: 24,
    hasDelivery: true,
    deliveryPrice: 80000,
    warrantyMonths: 6,
    shopName: 'Mebel House',
    createdAt: DateTime(2026, 5, 10),
  ),
];

class ShowcaseProductDataSource extends ProductDataSource {
  @override
  Future<ProductFeedPage> listByCategory({
    required String categoryId,
    String? subcategoryId,
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = kCategoryPageSize,
    int offset = 0,
  }) async {
    final results = showcaseProducts
        .where((p) => p.categoryId == categoryId)
        .toList();
    final page = results.skip(offset).take(limit).toList(growable: false);
    return ProductFeedPage(items: page, total: results.length);
  }

  @override
  Future<ProductFeedPage> listFeed({
    int limit = kHomeFeedPageSize,
    int offset = 0,
    HomeFeedSort sort = HomeFeedSort.recommended,
    List<String> excludeIds = const [],
  }) async {
    final sorted = [...showcaseProducts];
    switch (sort) {
      case HomeFeedSort.recommended:
      case HomeFeedSort.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case HomeFeedSort.popular:
        sorted.sort((a, b) => b.stock.compareTo(a.stock));
      case HomeFeedSort.discount:
        sorted.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    }
    var filtered = sorted;
    if (excludeIds.isNotEmpty) {
      final skip = excludeIds.toSet();
      filtered = sorted.where((p) => !skip.contains(p.id)).toList();
    }
    final page = filtered.skip(offset).take(limit).toList(growable: false);
    return ProductFeedPage(items: page, total: filtered.length);
  }

  @override
  Future<HomeForYouPage> fetchForYou({int limit = kHomeForYouLimit}) async {
    final items = showcaseProducts.take(limit).toList(growable: false);
    return HomeForYouPage(items: items, personalized: false);
  }

  @override
  Future<List<ProductModel>> listBySubcategory({
    required String subcategoryId,
  }) async => showcaseProducts;

  @override
  Future<ProductModel> getById(String id) async => showcaseProducts.firstWhere(
    (p) => p.id == id,
    orElse: () => showcaseProducts.first,
  );

  @override
  Future<List<ProductModel>> search(
    String query, {
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = 30,
  }) async => showcaseProducts
      .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
      .toList();

  @override
  Future<List<ProductModel>> listSimilar(
    String productId, {
    int limit = 10,
  }) async =>
      showcaseProducts.where((p) => p.id != productId).take(limit).toList();
}

// ─────────────────────────── Banners ───────────────────────────

class ShowcaseBannerRepository extends BannerRepository {
  @override
  Future<List<HomeBanner>> list() async => const [
    HomeBanner(
      id: 'show-b1',
      imageUrl:
          'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?w=1200&q=80',
      title: MultilingualText(
        uz: 'YOZGI AKSIYA',
        ru: 'ЛЕТНЯЯ АКЦИЯ',
        en: 'SUMMER SALE',
      ),
      subtitle: MultilingualText(
        uz: '30% gacha chegirma',
        ru: 'Скидки до 30%',
        en: 'Up to 30% off',
      ),
    ),
    HomeBanner(
      id: 'show-b2',
      imageUrl:
          'https://images.unsplash.com/photo-1554995207-c18c203602cb?w=1200&q=80',
      title: MultilingualText(
        uz: 'YANGI KOLLEKSIYA',
        ru: 'НОВАЯ КОЛЛЕКЦИЯ',
        en: 'NEW COLLECTION',
      ),
      subtitle: MultilingualText(
        uz: 'Premium mebel 2026',
        ru: 'Премиум мебель 2026',
        en: 'Premium furniture 2026',
      ),
    ),
    HomeBanner(
      id: 'show-b3',
      imageUrl:
          'https://images.unsplash.com/photo-1631679706909-1844bbd07221?w=1200&q=80',
      title: MultilingualText(
        uz: 'BEPUL YETKAZISH',
        ru: 'БЕСПЛАТНАЯ ДОСТАВКА',
        en: 'FREE DELIVERY',
      ),
      subtitle: MultilingualText(
        uz: "5 mln so'mdan yuqori buyurtmalarda",
        ru: 'При заказе от 5 млн сум',
        en: 'On orders above 5M UZS',
      ),
    ),
  ];
}

// ─────────────────────────── Reviews ───────────────────────────

class ShowcaseReviewsRepository implements CustomerReviewsRepository {
  @override
  Future<Result<ProductReviewSummary>> reviewsForProduct(
    String productId,
  ) async {
    final now = DateTime.now();
    return Result.ok(
      ProductReviewSummary(
        average: 4.8,
        count: 24,
        reviews: [
          Review(
            id: 'show-r1',
            productId: productId,
            productName: '',
            productImage: '',
            customerName: 'Dilnoza A.',
            rating: 5,
            comment:
                'Sifati zo‘r ekan, rasmdagidan ham chiroyli. Yetkazib berish '
                'ham tez bo‘ldi, rahmat!',
            createdAt: now.subtract(const Duration(days: 3)),
          ),
          Review(
            id: 'show-r2',
            productId: productId,
            productName: '',
            productImage: '',
            customerName: 'Sardor M.',
            rating: 5,
            comment: 'Narxiga arziydi. O‘rnatish xizmati ham bor ekan.',
            createdAt: now.subtract(const Duration(days: 9)),
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<Map<String, Review>>> reviewsForOrder(String orderId) async =>
      const Result.ok({});

  @override
  Future<Result<Review>> submitReview({
    required String orderItemId,
    required String orderId,
    required String productId,
    required int rating,
    String? comment,
  }) async => throw UnsupportedError('showcase');

  @override
  Future<Result<Review>> updateReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) async => throw UnsupportedError('showcase');
}

// ─────────────────────────── Seller dashboard ───────────────────────────

class ShowcaseSellerDashboardRepository implements SellerDashboardRepository {
  @override
  Future<({String? sellerName, String? shopName})> identity() async =>
      (sellerName: 'Bekzod', shopName: 'Wood Line');

  @override
  Stream<Order> newOrders() => const Stream.empty();

  @override
  Future<DashboardSnapshot> snapshot() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // A believable trading week, oldest → newest, ending today.
    const weekAmounts = <num>[
      1150000,
      1780000,
      950000,
      2310000,
      1540000,
      2870000,
      2450000,
    ];
    final weekly = WeeklySales(
      points: [
        for (var i = 0; i < 7; i++)
          DailyRevenuePoint(
            date: today.subtract(Duration(days: 6 - i)),
            amount: weekAmounts[i],
          ),
      ],
      total: weekAmounts.fold<num>(0, (a, b) => a + b),
      deltaPercent: 18.4,
    );

    final base = MockOrdersData.orders.first;
    Order order(
      String suffix,
      OrderStatus status,
      Duration age,
      num grandTotal,
    ) => Order(
      id: 'show-ord-$suffix',
      orderNumber: 'M-2026-$suffix',
      shop: base.shop,
      items: base.items,
      address: base.address,
      deliveryMethod: base.deliveryMethod,
      paymentMethod: base.paymentMethod,
      status: status,
      itemsTotal: grandTotal,
      deliveryFee: 0,
      servicesFee: 0,
      grandTotal: grandTotal,
      createdAt: now.subtract(age),
      timeline: [
        OrderStatusEvent(status: status, timestamp: now.subtract(age)),
      ],
    );

    return DashboardSnapshot(
      todaysOrders: 7,
      todaysRevenue: 2450000,
      pendingOrdersCount: 3,
      activeProductsCount: 24,
      tariff: TariffSnapshot(
        plan: TariffPlan.pro,
        activeProductsCount: 24,
        startedAt: now.subtract(const Duration(days: 7)),
        expiresAt: now.add(const Duration(days: 23)),
      ),
      recentOrders: [
        order(
          '1042',
          OrderStatus.pending,
          const Duration(minutes: 35),
          3990000,
        ),
        order('1041', OrderStatus.shipped, const Duration(hours: 3), 1480000),
        order(
          '1038',
          OrderStatus.delivered,
          const Duration(hours: 26),
          5490000,
        ),
      ],
      last30Days: const [],
      weekly: weekly,
      kpiDeltas: const KpiDeltas(revenue: 12.4, orders: 8.3, pending: -25.0),
      achievements: [
        const AchievementProgress(
          code: 'first_sale',
          titleUz: 'Birinchi savdo',
          titleRu: 'Первая продажа',
          descriptionUz: 'Profil nishoni ochiladi',
          icon: 'medal',
          requirementType: 'orders_delivered',
          threshold: 1,
          progress: 1,
          unlocked: true,
        ),
        const AchievementProgress(
          code: 'ten_orders',
          titleUz: '10 buyurtma',
          titleRu: '10 заказов',
          descriptionUz: 'Ishonchli sotuvchi belgisi',
          icon: 'box_tick',
          requirementType: 'orders_delivered',
          threshold: 10,
          progress: 10,
          unlocked: true,
        ),
        const AchievementProgress(
          code: 'rev_5m',
          titleUz: '5 mln aylanma',
          titleRu: '5 млн оборота',
          descriptionUz: 'Reklama bonusi ochiladi',
          icon: 'wallet',
          requirementType: 'revenue_realized',
          threshold: 5000000,
          progress: 3200000,
        ),
        const AchievementProgress(
          code: 'fifty_orders',
          titleUz: '50 buyurtma',
          titleRu: '50 заказов',
          descriptionUz: 'TOP sotuvchilar safiga qo‘shilasiz',
          icon: 'cup',
          requirementType: 'orders_delivered',
          threshold: 50,
          progress: 23,
        ),
      ],
      leaderboard: const [
        LeaderboardStanding(
          rank: 1,
          shopName: 'A*** Mebel',
          revenue: 18400000,
          deltaPercent: 6.0,
        ),
        LeaderboardStanding(
          rank: 2,
          shopName: 'Wood Line',
          revenue: 13050000,
          deltaPercent: 18.4,
          isMe: true,
        ),
        LeaderboardStanding(
          rank: 3,
          shopName: 'M*** House',
          revenue: 11200000,
          deltaPercent: -3.2,
        ),
        LeaderboardStanding(
          rank: 4,
          shopName: 'D*** Design',
          revenue: 9800000,
          deltaPercent: 4.1,
        ),
        LeaderboardStanding(
          rank: 5,
          shopName: 'S*** Stil',
          revenue: 7400000,
          deltaPercent: 1.5,
        ),
      ],
      topProducts: [
        TopProductStat(
          productId: 'show-1',
          name: 'Milan burchak divani',
          image: _unsplash('1555041469-a586c61ea9bc'),
          unitsSold: 12,
          revenue: 47880000,
          deltaPercent: 24.0,
        ),
        TopProductStat(
          productId: 'show-2',
          name: 'Skandinaviya krovati 160×200',
          image: _unsplash('1505693416388-ac5ce068fe85'),
          unitsSold: 8,
          revenue: 43920000,
          deltaPercent: 12.0,
        ),
        TopProductStat(
          productId: 'show-4',
          name: 'Siena kreslosi',
          image: _unsplash('1586023492125-27b2c045efd7'),
          unitsSold: 7,
          revenue: 10360000,
          deltaPercent: -5.0,
        ),
      ],
    );
  }
}

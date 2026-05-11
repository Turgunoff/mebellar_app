import '../models/banner.dart';
import '../models/category.dart';
import '../models/multilingual_text.dart';
import '../models/product.dart';
import '../models/shop.dart';
import '../models/shop_service.dart';

/// Centralised mock dataset used by the `Mock*Repository` classes when the
/// app boots with `USE_MOCKS=true`. Designed to look believable in the UI:
/// localised names, mixed sale prices, varied stock, repeating shop ids.
class MockData {
  const MockData._();

  // ------- helpers --------------------------------------------------------

  static const _sofaImg = 'https://picsum.photos/seed/sofa/600/600';
  static const _sofa2Img = 'https://picsum.photos/seed/sofa2/600/600';
  static const _chairImg = 'https://picsum.photos/seed/chair/600/600';
  static const _tableImg = 'https://picsum.photos/seed/table/600/600';
  static const _bedImg = 'https://picsum.photos/seed/bed/600/600';
  static const _wardrobeImg =
      'https://picsum.photos/seed/wardrobe/600/600';
  static const _kitchenImg = 'https://picsum.photos/seed/kitchen/600/600';
  static const _kidsImg = 'https://picsum.photos/seed/kids/600/600';
  static const _gardenImg = 'https://picsum.photos/seed/garden/600/600';

  /// Synthesise an extra image URL family from a base seed so the product
  /// gallery has 3-4 images instead of one. Picsum returns deterministic
  /// frames per seed which is enough for visual variety in mocks.
  static List<String> _gallery(String seed) {
    return [
      'https://picsum.photos/seed/$seed-1/800/800',
      'https://picsum.photos/seed/$seed-2/800/800',
      'https://picsum.photos/seed/$seed-3/800/800',
      'https://picsum.photos/seed/$seed-4/800/800',
    ];
  }

  static MultilingualText _ml(String uz, String ru, String en) =>
      MultilingualText(uz: uz, ru: ru, en: en);

  // ------- shops ----------------------------------------------------------

  static final List<Shop> shops = [
    Shop(
      id: 'shop-mh',
      slug: 'mebel-house',
      name: _ml('Mebel House', 'Mebel House', 'Mebel House'),
      description: _ml(
        'Yevropadan import qilingan zamonaviy mebellar',
        'Современная мебель из Европы',
        'Modern furniture imported from Europe',
      ),
      logoUrl: 'https://picsum.photos/seed/shop1/200/200',
      contactPhone: '+998901112233',
      telegramUsername: 'mebelhouse',
      isVerified: true,
    ),
    Shop(
      id: 'shop-ch',
      slug: 'comfort-home',
      name: _ml('ComfortHome', 'ComfortHome', 'ComfortHome'),
      description: _ml(
        'Uy uchun qulay va arzon mebellar',
        'Удобная и доступная мебель для дома',
        'Comfortable and affordable home furniture',
      ),
      logoUrl: 'https://picsum.photos/seed/shop2/200/200',
      contactPhone: '+998902223344',
      isVerified: true,
    ),
    Shop(
      id: 'shop-rm',
      slug: 'royal-mebel',
      name: _ml('Royal Mebel', 'Royal Mebel', 'Royal Mebel'),
      description: _ml(
        'Premium klassik mebellar',
        'Премиум классическая мебель',
        'Premium classic furniture',
      ),
      logoUrl: 'https://picsum.photos/seed/shop3/200/200',
      contactPhone: '+998903334455',
      telegramUsername: 'royalmebel',
      isVerified: true,
    ),
    Shop(
      id: 'shop-zm',
      slug: 'zamonaviy-mebel',
      name: _ml('Zamonaviy Mebel', 'Современная мебель', 'Modern Furniture'),
      logoUrl: 'https://picsum.photos/seed/shop4/200/200',
      contactPhone: '+998904445566',
      isVerified: false,
    ),
    Shop(
      id: 'shop-ks',
      slug: 'klassik-style',
      name: _ml('Klassik Style', 'Классик стиль', 'Classic Style'),
      logoUrl: 'https://picsum.photos/seed/shop5/200/200',
      contactPhone: '+998905556677',
      isVerified: true,
    ),
  ];

  static Shop? shopById(String id) =>
      shops.where((s) => s.id == id).firstOrNull;

  // ------- categories -----------------------------------------------------

  static final List<Category> categoriesTree = [
    Category(
      id: 'cat-sofas',
      slug: 'sofas',
      name: _ml('Divan va kreslolar', 'Диваны и кресла', 'Sofas & Armchairs'),
      productCount: 12,
      children: [
        Category(
          id: 'cat-sofas-corner',
          slug: 'corner-sofas',
          name: _ml('Burchakli divanlar', 'Угловые диваны', 'Corner sofas'),
          parentSlug: 'sofas',
          productCount: 5,
        ),
        Category(
          id: 'cat-sofas-bed',
          slug: 'sofa-beds',
          name: _ml('Yotoq divanlar', 'Диваны-кровати', 'Sofa beds'),
          parentSlug: 'sofas',
          productCount: 4,
        ),
        Category(
          id: 'cat-armchairs',
          slug: 'armchairs',
          name: _ml('Kreslolar', 'Кресла', 'Armchairs'),
          parentSlug: 'sofas',
          productCount: 3,
        ),
      ],
    ),
    Category(
      id: 'cat-tables',
      slug: 'tables',
      name: _ml('Stollar', 'Столы', 'Tables'),
      productCount: 10,
      children: [
        Category(
          id: 'cat-tables-dining',
          slug: 'dining-tables',
          name: _ml('Oshxona stollari', 'Обеденные столы', 'Dining tables'),
          parentSlug: 'tables',
          productCount: 4,
        ),
        Category(
          id: 'cat-tables-desk',
          slug: 'desks',
          name: _ml('Yozuv stollari', 'Письменные столы', 'Desks'),
          parentSlug: 'tables',
          productCount: 3,
        ),
        Category(
          id: 'cat-tables-coffee',
          slug: 'coffee-tables',
          name: _ml('Jurnal stollari', 'Журнальные столы', 'Coffee tables'),
          parentSlug: 'tables',
          productCount: 3,
        ),
      ],
    ),
    Category(
      id: 'cat-beds',
      slug: 'beds',
      name: _ml('Karavotlar', 'Кровати', 'Beds'),
      productCount: 8,
      children: [
        Category(
          id: 'cat-beds-single',
          slug: 'single-beds',
          name: _ml('1 kishilik', '1-местные', 'Single'),
          parentSlug: 'beds',
          productCount: 3,
        ),
        Category(
          id: 'cat-beds-double',
          slug: 'double-beds',
          name: _ml('2 kishilik', '2-местные', 'Double'),
          parentSlug: 'beds',
          productCount: 5,
        ),
      ],
    ),
    Category(
      id: 'cat-wardrobes',
      slug: 'wardrobes',
      name: _ml('Shkaflar', 'Шкафы', 'Wardrobes'),
      productCount: 6,
    ),
    Category(
      id: 'cat-kitchen',
      slug: 'kitchen',
      name: _ml('Kuxnya mebellari', 'Кухонная мебель', 'Kitchen furniture'),
      productCount: 7,
    ),
    Category(
      id: 'cat-kids',
      slug: 'kids',
      name: _ml('Bolalar mebeli', 'Детская мебель', 'Kids furniture'),
      productCount: 5,
    ),
    Category(
      id: 'cat-office',
      slug: 'office',
      name: _ml('Ofis mebeli', 'Офисная мебель', 'Office furniture'),
      productCount: 4,
    ),
    Category(
      id: 'cat-garden',
      slug: 'garden',
      name: _ml('Bog\' mebeli', 'Садовая мебель', 'Garden furniture'),
      productCount: 3,
    ),
  ];

  static List<Category> _flatten(List<Category> tree) {
    final out = <Category>[];
    void walk(Category c) {
      out.add(c);
      for (final ch in c.children) {
        walk(ch);
      }
    }
    for (final c in tree) {
      walk(c);
    }
    return out;
  }

  static List<Category> get allCategories => _flatten(categoriesTree);

  static Category? categoryBySlug(String slug) =>
      allCategories.where((c) => c.slug == slug).firstOrNull;

  // ------- banners --------------------------------------------------------

  static final List<HomeBanner> banners = [
    HomeBanner(
      id: 'b1',
      imageUrl: 'https://picsum.photos/seed/banner-sofas/1200/600',
      title: _ml(
        'Yangi yil chegirmasi 30%',
        'Новогодняя скидка 30%',
        'New Year sale 30%',
      ),
      linkType: 'category',
      linkTarget: 'sofas',
    ),
    HomeBanner(
      id: 'b2',
      imageUrl: 'https://picsum.photos/seed/banner-kids/1200/600',
      title: _ml(
        'Bolalar mebeli — eng yaxshi narxlar',
        'Детская мебель — лучшие цены',
        'Kids furniture — best prices',
      ),
      linkType: 'category',
      linkTarget: 'kids',
    ),
    HomeBanner(
      id: 'b3',
      imageUrl: 'https://picsum.photos/seed/banner-premium/1200/600',
      title: _ml(
        'Premium kreslolar — Royal Mebel',
        'Премиум кресла — Royal Mebel',
        'Premium armchairs — Royal Mebel',
      ),
      linkType: 'shop',
      linkTarget: 'royal-mebel',
    ),
  ];

  // ------- products -------------------------------------------------------

  static final List<Product> products = [
    // SOFAS / corner sofas
    _p(
      id: 'p1',
      slug: 'corner-sofa-luxury',
      name: _ml('Burchakli divan "Luxury"', 'Угловой диван "Luxury"',
          'Corner sofa "Luxury"'),
      price: 8500000,
      oldPrice: 11000000,
      categorySlug: 'corner-sofas',
      shopId: 'shop-mh',
      img: _sofaImg,
      stock: 5,
    ),
    _p(
      id: 'p2',
      slug: 'corner-sofa-modern',
      name: _ml(
        'Burchakli divan "Modern"',
        'Угловой диван "Modern"',
        'Corner sofa "Modern"',
      ),
      price: 6900000,
      categorySlug: 'corner-sofas',
      shopId: 'shop-zm',
      img: _sofa2Img,
      stock: 12,
    ),
    _p(
      id: 'p3',
      slug: 'sofa-bed-comfort',
      name: _ml('Divan-karavot "Comfort"', 'Диван-кровать "Comfort"',
          'Sofa-bed "Comfort"'),
      price: 4500000,
      oldPrice: 5200000,
      categorySlug: 'sofa-beds',
      shopId: 'shop-ch',
      img: _sofaImg,
      stock: 3,
    ),
    _p(
      id: 'p4',
      slug: 'armchair-velvet',
      name: _ml('Velvet kresla', 'Велюровое кресло', 'Velvet armchair'),
      price: 1850000,
      categorySlug: 'armchairs',
      shopId: 'shop-rm',
      img: _chairImg,
      stock: 8,
    ),
    _p(
      id: 'p5',
      slug: 'armchair-leather',
      name: _ml('Charm kresla', 'Кожаное кресло', 'Leather armchair'),
      price: 3200000,
      oldPrice: 3800000,
      categorySlug: 'armchairs',
      shopId: 'shop-rm',
      img: _chairImg,
      stock: 6,
    ),

    // TABLES
    _p(
      id: 'p10',
      slug: 'dining-table-oak',
      name: _ml('Oshxona stoli "Oak"', 'Обеденный стол "Oak"', 'Dining table "Oak"'),
      price: 2400000,
      categorySlug: 'dining-tables',
      shopId: 'shop-ks',
      img: _tableImg,
      stock: 10,
    ),
    _p(
      id: 'p11',
      slug: 'dining-table-glass',
      name: _ml('Shisha oshxona stoli', 'Стеклянный обеденный стол',
          'Glass dining table'),
      price: 3100000,
      oldPrice: 3500000,
      categorySlug: 'dining-tables',
      shopId: 'shop-zm',
      img: _tableImg,
      stock: 4,
    ),
    _p(
      id: 'p12',
      slug: 'desk-office',
      name: _ml('Yozuv stoli "Office"', 'Письменный стол "Office"',
          'Office desk'),
      price: 1450000,
      categorySlug: 'desks',
      shopId: 'shop-ch',
      img: _tableImg,
      stock: 15,
    ),
    _p(
      id: 'p13',
      slug: 'coffee-table-marble',
      name: _ml('Marmar jurnal stoli', 'Мраморный журнальный столик',
          'Marble coffee table'),
      price: 1900000,
      oldPrice: 2300000,
      categorySlug: 'coffee-tables',
      shopId: 'shop-rm',
      img: _tableImg,
      stock: 2,
    ),

    // BEDS
    _p(
      id: 'p20',
      slug: 'double-bed-king',
      name: _ml('2 kishilik karavot "King"', '2-местная кровать "King"',
          'Double bed "King"'),
      price: 5800000,
      oldPrice: 6500000,
      categorySlug: 'double-beds',
      shopId: 'shop-mh',
      img: _bedImg,
      stock: 4,
    ),
    _p(
      id: 'p21',
      slug: 'double-bed-modern',
      name: _ml('Zamonaviy 2 kishilik karavot',
          'Современная двуспальная кровать', 'Modern double bed'),
      price: 4200000,
      categorySlug: 'double-beds',
      shopId: 'shop-zm',
      img: _bedImg,
      stock: 7,
    ),
    _p(
      id: 'p22',
      slug: 'single-bed-classic',
      name: _ml('1 kishilik karavot "Classic"', '1-местная кровать "Classic"',
          'Single bed "Classic"'),
      price: 2100000,
      categorySlug: 'single-beds',
      shopId: 'shop-ks',
      img: _bedImg,
      stock: 9,
    ),

    // WARDROBES
    _p(
      id: 'p30',
      slug: 'wardrobe-3-doors',
      name: _ml('3 eshikli shkaf', 'Шкаф 3-дверный', 'Wardrobe 3-door'),
      price: 3700000,
      categorySlug: 'wardrobes',
      shopId: 'shop-ch',
      img: _wardrobeImg,
      stock: 6,
    ),
    _p(
      id: 'p31',
      slug: 'wardrobe-sliding',
      name: _ml(
        'Coupe shkaf',
        'Шкаф-купе',
        'Sliding wardrobe',
      ),
      price: 4900000,
      oldPrice: 5500000,
      categorySlug: 'wardrobes',
      shopId: 'shop-mh',
      img: _wardrobeImg,
      stock: 3,
    ),

    // KITCHEN
    _p(
      id: 'p40',
      slug: 'kitchen-set-modern',
      name: _ml(
        'Kuxnya jihozlari "Modern"',
        'Кухонный гарнитур "Modern"',
        'Kitchen set "Modern"',
      ),
      price: 12500000,
      oldPrice: 14200000,
      categorySlug: 'kitchen',
      shopId: 'shop-rm',
      img: _kitchenImg,
      stock: 1,
    ),
    _p(
      id: 'p41',
      slug: 'kitchen-set-classic',
      name: _ml(
        'Klassik kuxnya jihozlari',
        'Классический кухонный гарнитур',
        'Classic kitchen set',
      ),
      price: 9800000,
      categorySlug: 'kitchen',
      shopId: 'shop-ks',
      img: _kitchenImg,
      stock: 2,
    ),

    // KIDS
    _p(
      id: 'p50',
      slug: 'kids-bed-car',
      name: _ml(
        'Bolalar mashina karavoti',
        'Детская кровать-машина',
        'Kids car bed',
      ),
      price: 2800000,
      oldPrice: 3200000,
      categorySlug: 'kids',
      shopId: 'shop-ch',
      img: _kidsImg,
      stock: 4,
    ),
    _p(
      id: 'p51',
      slug: 'kids-desk',
      name: _ml(
        'Bolalar yozuv stoli',
        'Детский письменный стол',
        'Kids desk',
      ),
      price: 1200000,
      categorySlug: 'kids',
      shopId: 'shop-zm',
      img: _kidsImg,
      stock: 8,
    ),

    // GARDEN
    _p(
      id: 'p60',
      slug: 'garden-set-rattan',
      name: _ml(
        'Rattan bog\' to\'plami',
        'Ротанговый набор для сада',
        'Rattan garden set',
      ),
      price: 5400000,
      categorySlug: 'garden',
      shopId: 'shop-mh',
      img: _gardenImg,
      stock: 2,
    ),
  ];

  static Product _p({
    required String id,
    required String slug,
    required MultilingualText name,
    required num price,
    num? oldPrice,
    required String categorySlug,
    required String shopId,
    required String img,
    int stock = 5,
  }) {
    final shop = shopById(shopId);
    final services = _servicesForShop(shopId);
    return Product(
      id: id,
      slug: slug,
      name: name,
      description: _descriptionFor(slug, name),
      price: price,
      oldPrice: oldPrice,
      categorySlug: categorySlug,
      shop: shop,
      images: [img, ..._gallery(slug)],
      primaryImage: img,
      attributes: _attributesFor(categorySlug),
      shopServices: services,
      stock: stock,
    );
  }

  /// Per-shop service mix. Verified flagship shops bundle more perks; smaller
  /// shops keep the list short. Tweak when you want a specific product to
  /// look richer or sparser.
  static List<ShopService> _servicesForShop(String shopId) {
    return switch (shopId) {
      'shop-mh' => const [
          ShopService.freeDelivery,
          ShopService.assembly,
          ShopService.warranty,
          ShopService.installment,
        ],
      'shop-ch' => const [
          ShopService.freeDelivery,
          ShopService.warranty,
        ],
      'shop-rm' => const [
          ShopService.assembly,
          ShopService.warranty,
          ShopService.installment,
          ShopService.customOrder,
        ],
      'shop-zm' => const [
          ShopService.express,
          ShopService.assembly,
        ],
      'shop-ks' => const [
          ShopService.freeDelivery,
          ShopService.warranty,
          ShopService.installment,
        ],
      _ => const [],
    };
  }

  /// Lightweight category-shaped attribute set. Real backend will return per
  /// category schema; here we just want the UI to have something to render.
  static Map<String, dynamic> _attributesFor(String categorySlug) {
    final cat = categoryBySlug(categorySlug);
    final parent = cat?.parentSlug ?? categorySlug;
    return switch (parent) {
      'sofas' => {
          'material': 'Charm + yog\'och karkas',
          'seats': '4',
          'color': 'Bej',
          'dimensions': '230 × 95 × 90 sm',
        },
      'tables' => {
          'material': 'Massiv yog\'och',
          'shape': 'To\'g\'ri to\'rtburchak',
          'seats': '6',
          'dimensions': '160 × 80 × 75 sm',
        },
      'beds' => {
          'material': 'MDF + LDSP',
          'mattress_size': '180 × 200 sm',
          'storage': 'Bor',
        },
      'wardrobes' => {
          'material': 'LDSP',
          'doors': '3',
          'mirror': 'Bor',
          'dimensions': '180 × 220 × 60 sm',
        },
      'kitchen' => {
          'material': 'MDF + akril',
          'length': '3 metr',
          'color': 'Oq glyans',
        },
      'kids' => {
          'material': 'MDF (xavfsiz)',
          'age': '3-12 yosh',
          'color': 'Ko\'k',
        },
      'garden' => {
          'material': 'Rattan',
          'weatherproof': 'Ha',
        },
      _ => const {
          'material': 'Yog\'och',
          'color': 'Universal',
        },
    };
  }

  static MultilingualText _descriptionFor(String slug, MultilingualText name) {
    final base = name.uz ?? slug;
    return MultilingualText(
      uz:
          '$base — sifatli materiallardan ishlangan, zamonaviy dizayn. Yetkazib berish va yig\'ish xizmati mavjud.',
      ru:
          '$base — изготовлено из качественных материалов, современный дизайн. Доступны доставка и сборка.',
      en:
          '$base — crafted from quality materials with a modern design. Delivery and assembly available.',
    );
  }

  static List<Product> get featuredProducts =>
      products.where((p) => p.isOnSale).take(8).toList();

  static List<Shop> get featuredShops =>
      shops.where((s) => s.isVerified).toList();
}

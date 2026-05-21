import 'dart:math' as math;

import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/seller_product.dart';

/// Seed catalog for the seller dashboard. We hand-craft 12 products covering
/// every status (draft / pending / approved / rejected / archived) so the
/// status filter chips in the products list always have something to show.
class MockSellerProducts {
  const MockSellerProducts._();

  static final _baseTime = DateTime.now().subtract(const Duration(days: 30));

  static MultilingualText _ml(String uz, String ru, String en) =>
      MultilingualText(uz: uz, ru: ru, en: en);

  static List<SellerProductImage> _images(String seed, int count) {
    return [
      for (var i = 0; i < count; i++)
        SellerProductImage(
          id: '$seed-img-$i',
          remoteUrl:
              'https://picsum.photos/seed/seller-$seed-$i/800/800',
        ),
    ];
  }

  static SellerProduct _p({
    required String id,
    required MultilingualText name,
    required MultilingualText description,
    required String categorySlug,
    required num price,
    num? oldPrice,
    required int stock,
    required String sku,
    int images = 4,
    Map<String, dynamic> attributes = const {},
    num? lengthCm,
    num? widthCm,
    num? heightCm,
    num? weightKg,
    required SellerProductStatus status,
    String? rejectionReason,
    int dayOffset = 0,
  }) {
    final imgs = _images(id, images);
    return SellerProduct(
      id: id,
      name: name,
      description: description,
      categorySlug: categorySlug,
      price: price,
      oldPrice: oldPrice,
      stock: stock,
      sku: sku,
      images: imgs,
      primaryImageId: imgs.isEmpty ? null : imgs.first.id,
      attributes: attributes,
      lengthCm: lengthCm,
      widthCm: widthCm,
      heightCm: heightCm,
      weightKg: weightKg,
      status: status,
      rejectionReason: rejectionReason,
      createdAt: _baseTime.add(Duration(days: dayOffset)),
      updatedAt: _baseTime.add(Duration(days: dayOffset, hours: 4)),
    );
  }

  static final List<SellerProduct> products = [
    _p(
      id: 'sp-1',
      name: _ml('Burchakli divan "Modern"', 'Угловой диван "Modern"',
          'Corner sofa "Modern"'),
      description: _ml(
        'Charm va to\'qima qoplama, qulay yotoq holatiga aylantirish imkoniyati.',
        'Кожа и ткань, удобное превращение в спальное место.',
        'Leather and fabric upholstery, converts to a sleeping place.',
      ),
      categorySlug: 'corner-sofas',
      price: 8500000,
      oldPrice: 11000000,
      stock: 5,
      sku: 'MH-CSF-001',
      attributes: {
        'material': 'Charm + yog\'och karkas',
        'color': 'Bej',
        'seats': '4',
      },
      lengthCm: 230,
      widthCm: 95,
      heightCm: 90,
      weightKg: 75,
      status: SellerProductStatus.approved,
      dayOffset: 25,
    ),
    _p(
      id: 'sp-2',
      name: _ml('Klassik kresla', 'Классическое кресло', 'Classic armchair'),
      description: _ml(
        'Yog\'och oyoqlar, qattiq orqalik, qadimiy stilda.',
        'Деревянные ножки, твёрдая спинка, классический стиль.',
        'Wooden legs, firm back, classic style.',
      ),
      categorySlug: 'armchairs',
      price: 1850000,
      stock: 8,
      sku: 'MH-ARM-002',
      attributes: {
        'material': 'Yog\'och + velour',
        'color': 'To\'q yashil',
      },
      status: SellerProductStatus.approved,
      dayOffset: 22,
    ),
    _p(
      id: 'sp-3',
      name: _ml(
        '2 kishilik karavot "King"',
        '2-местная кровать "King"',
        'Double bed "King"',
      ),
      description: _ml(
        'Saqlash joyi bilan, MDF ramka.',
        'С местом для хранения, рамка из МДФ.',
        'With storage, MDF frame.',
      ),
      categorySlug: 'double-beds',
      price: 5800000,
      oldPrice: 6500000,
      stock: 4,
      sku: 'MH-BED-003',
      attributes: {'material': 'MDF', 'mattress_size': '180x200'},
      status: SellerProductStatus.approved,
      dayOffset: 20,
    ),
    _p(
      id: 'sp-4',
      name: _ml('Shisha oshxona stoli', 'Стеклянный обеденный стол',
          'Glass dining table'),
      description: _ml(
        '8 mm shisha + metal oyoqlar.',
        '8 мм стекло + металлические ножки.',
        '8 mm glass + metal legs.',
      ),
      categorySlug: 'dining-tables',
      price: 3100000,
      stock: 4,
      sku: 'MH-DIN-004',
      attributes: {'material': 'Shisha + metall', 'shape': 'To\'g\'ri to\'rtburchak'},
      status: SellerProductStatus.pendingReview,
      dayOffset: 5,
    ),
    _p(
      id: 'sp-5',
      name: _ml('Yumshoq kresla "Velvet"', 'Мягкое кресло "Velvet"',
          'Soft armchair "Velvet"'),
      description: _ml(
        'Velour qoplama, qulay tutqich.',
        'Велюровая обивка, удобный подлокотник.',
        'Velour upholstery, comfortable armrest.',
      ),
      categorySlug: 'armchairs',
      price: 2400000,
      stock: 0,
      sku: 'MH-ARM-005',
      attributes: {'color': 'Pushti'},
      status: SellerProductStatus.draft,
      dayOffset: 2,
    ),
    _p(
      id: 'sp-6',
      name: _ml('Bolalar yozuv stoli', 'Детский письменный стол',
          'Kids desk'),
      description: _ml(
        'Balandlik moslashadigan, ergonomik.',
        'Регулируемая высота, эргономичный.',
        'Adjustable height, ergonomic.',
      ),
      categorySlug: 'kids',
      price: 1200000,
      stock: 0,
      sku: 'MH-KID-006',
      status: SellerProductStatus.draft,
      dayOffset: 1,
    ),
    _p(
      id: 'sp-7',
      name: _ml('Eski tip stol', 'Стол старого образца',
          'Old-style table'),
      description: _ml(
        'Eski stildagi mahsulot.',
        'Изделие в старом стиле.',
        'Old-style product.',
      ),
      categorySlug: 'dining-tables',
      price: 1500000,
      stock: 2,
      sku: 'MH-DIN-007',
      status: SellerProductStatus.rejected,
      rejectionReason: 'Rasmlar sifati past — yorqinroq fonda qayta suratga oling',
      dayOffset: 8,
    ),
    _p(
      id: 'sp-8',
      name: _ml('Diqqat: arxiv', 'Архив: для теста', 'Archived: test'),
      description: _ml(
        'Bu mahsulot arxivlangan.',
        'Этот товар в архиве.',
        'This product is archived.',
      ),
      categorySlug: 'wardrobes',
      price: 4900000,
      stock: 0,
      sku: 'MH-WAR-008',
      status: SellerProductStatus.archived,
      dayOffset: 28,
    ),
    _p(
      id: 'sp-9',
      name: _ml('Marmar jurnal stoli', 'Мраморный журнальный столик',
          'Marble coffee table'),
      description: _ml(
        'Tabiiy marmar yuza, mustahkam metall karkas.',
        'Натуральная мраморная поверхность, прочный металлический каркас.',
        'Natural marble surface, sturdy metal frame.',
      ),
      categorySlug: 'coffee-tables',
      price: 1900000,
      oldPrice: 2300000,
      stock: 2,
      sku: 'MH-COF-009',
      status: SellerProductStatus.approved,
      dayOffset: 18,
    ),
    _p(
      id: 'sp-10',
      name: _ml('Klassik kuxnya jihozlari', 'Классический кухонный гарнитур',
          'Classic kitchen set'),
      description: _ml(
        '3 metr uzunlikda, MDF + akril qoplama.',
        '3 метра, МДФ + акриловое покрытие.',
        '3 meters long, MDF + acrylic finish.',
      ),
      categorySlug: 'kitchen',
      price: 9800000,
      stock: 2,
      sku: 'MH-KIT-010',
      status: SellerProductStatus.approved,
      dayOffset: 27,
    ),
    _p(
      id: 'sp-11',
      name: _ml('Kuxnya jihozlari "Modern"', 'Кухонный гарнитур "Modern"',
          'Kitchen set "Modern"'),
      description: _ml(
        'Premium klass, MDF korpus, akril fasadlar.',
        'Премиум-класс, корпус МДФ, акриловые фасады.',
        'Premium class, MDF body, acrylic facades.',
      ),
      categorySlug: 'kitchen',
      price: 12500000,
      oldPrice: 14200000,
      stock: 1,
      sku: 'MH-KIT-011',
      status: SellerProductStatus.approved,
      dayOffset: 26,
    ),
    _p(
      id: 'sp-12',
      name: _ml('3 eshikli shkaf', 'Шкаф 3-дверный', 'Wardrobe 3-door'),
      description: _ml(
        'LDSP korpus, ko\'zgu bilan.',
        'Корпус ЛДСП, с зеркалом.',
        'LDSP body, with mirror.',
      ),
      categorySlug: 'wardrobes',
      price: 3700000,
      stock: 6,
      sku: 'MH-WAR-012',
      status: SellerProductStatus.pendingReview,
      dayOffset: 12,
    ),
  ];

  /// Synthetic 30-day revenue series — random but seeded so it stays the
  /// same across hot-reloads.
  static List<({DateTime date, num amount})> revenueSeries() {
    final rand = math.Random(42);
    final now = DateTime.now();
    return [
      for (var i = 29; i >= 0; i--)
        (
          date: DateTime(now.year, now.month, now.day - i),
          amount: 200000 + rand.nextInt(2_500_000),
        ),
    ];
  }
}

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/seller/features/products/bloc/add_product_cubit.dart';
import 'package:woody_app/seller/features/products/data/add_product_repository.dart';
import 'package:woody_app/seller/features/products/data/attributes_repository.dart';
import 'package:woody_app/seller/features/products/data/exchange_rate_service.dart';
import 'package:woody_app/shared/models/attribute_definition.dart';
import 'package:woody_app/shared/models/category_model.dart';
import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/seller_product.dart';

class _MockAddProductRepo extends Mock implements AddProductRepository {}

class _MockAttributesRepo extends Mock implements AttributesRepository {}

class _MockExchangeRates extends Mock implements ExchangeRateService {}

class _MockShopContext extends Mock implements AddProductShopContext {}

_MockShopContext _context({required bool canAddMore}) {
  final ctx = _MockShopContext();
  when(() => ctx.canAddMoreProducts).thenReturn(canAddMore);
  when(() => ctx.shopId).thenReturn('shop-1');
  when(() => ctx.activeProductsCount).thenReturn(2);
  when(() => ctx.maxImages).thenReturn(5);
  return ctx;
}

AttributeDefinition _def(
  String key, {
  bool isRequired = false,
  AttributeDataType type = AttributeDataType.text,
  String? categoryId,
  String? subcategoryId,
}) {
  return AttributeDefinition(
    id: 'def-$key',
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    key: key,
    labelUz: key,
    labelRu: key,
    dataType: type,
    unit: null,
    isRequired: isRequired,
    sortOrder: 10,
  );
}

AddProductCubit _cubit(
  _MockAddProductRepo repo, {
  _MockAttributesRepo? attrsRepo,
  ExchangeRateService? rates,
}) {
  return AddProductCubit(
    repository: repo,
    attributesRepository: attrsRepo ?? _MockAttributesRepo(),
    exchangeRates: rates,
  );
}

void main() {
  late _MockAddProductRepo repo;

  setUpAll(() {
    registerFallbackValue(<FormImage>[]);
    registerFallbackValue(
      const AddProductInput(
        sellerId: '',
        shopId: '',
        name: '',
        description: '',
        categoryId: '',
        subcategoryId: null,
        price: 0,
        discountPercent: 0,
        sku: '',
        colorSlugs: [],
        colorNames: [],
        attributes: {},
        productionTimeDays: null,
        hasDelivery: false,
        deliveryPrice: 0,
        hasInstallation: false,
        installationPrice: 0,
        warrantyMonths: 0,
        images: [],
      ),
    );
  });

  setUp(() => repo = _MockAddProductRepo());

  blocTest<AddProductCubit, AddProductState>(
    'loadContext emits ready when the plan allows more products',
    build: () {
      when(
        repo.loadShopContext,
      ).thenAnswer((_) async => _context(canAddMore: true));
      return _cubit(repo);
    },
    act: (cubit) => cubit.loadContext(),
    expect: () => [
      isA<AddProductState>().having(
        (s) => s.status,
        'status',
        AddProductStatus.loadingContext,
      ),
      isA<AddProductState>().having(
        (s) => s.status,
        'status',
        AddProductStatus.ready,
      ),
    ],
  );

  blocTest<AddProductCubit, AddProductState>(
    'loadContext emits tariffBlocked once the plan quota is reached',
    build: () {
      when(
        repo.loadShopContext,
      ).thenAnswer((_) async => _context(canAddMore: false));
      return _cubit(repo);
    },
    act: (cubit) => cubit.loadContext(),
    expect: () => [
      isA<AddProductState>().having(
        (s) => s.status,
        'status',
        AddProductStatus.loadingContext,
      ),
      isA<AddProductState>().having(
        (s) => s.status,
        'status',
        AddProductStatus.tariffBlocked,
      ),
    ],
  );

  blocTest<AddProductCubit, AddProductState>(
    'loadContext emits failure when the repository throws',
    build: () {
      when(repo.loadShopContext).thenThrow(Exception('context load failed'));
      return _cubit(repo);
    },
    act: (cubit) => cubit.loadContext(),
    expect: () => [
      isA<AddProductState>().having(
        (s) => s.status,
        'status',
        AddProductStatus.loadingContext,
      ),
      isA<AddProductState>()
          .having((s) => s.status, 'status', AddProductStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<AddProductCubit, AddProductState>(
    'setName updates the product name field',
    build: () => _cubit(repo),
    act: (cubit) => cubit.setName('Yumshoq divan'),
    expect: () => [
      isA<AddProductState>().having((s) => s.name, 'name', 'Yumshoq divan'),
    ],
  );

  blocTest<AddProductCubit, AddProductState>(
    'setDiscountPercent clamps values above 100',
    build: () => _cubit(repo),
    act: (cubit) => cubit.setDiscountPercent(150),
    expect: () => [
      isA<AddProductState>().having(
        (s) => s.discountPercent,
        'discountPercent',
        100,
      ),
    ],
  );

  group('addImages', () {
    final shopContext = _context(canAddMore: true);
    File makeFile(String name) => File('/tmp/$name');
    FormImage makeImage(String name) => FormImage.local(makeFile(name));

    blocTest<AddProductCubit, AddProductState>(
      'appends all picked images when remaining quota covers them',
      build: () => _cubit(repo),
      seed: () => AddProductState(
        status: AddProductStatus.ready,
        context: shopContext,
        images: [makeImage('a.jpg')],
      ),
      act: (cubit) {
        final added = cubit.addImages([makeFile('b.jpg'), makeFile('c.jpg')]);
        expect(added, 2);
      },
      expect: () => [
        isA<AddProductState>().having(
          (s) => s.images.length,
          'images.length',
          3,
        ),
      ],
    );

    blocTest<AddProductCubit, AddProductState>(
      'trims the picked batch to the remaining tariff slots',
      build: () => _cubit(repo),
      seed: () => AddProductState(
        status: AddProductStatus.ready,
        context: shopContext,
        images: [for (var i = 0; i < 4; i++) makeImage('$i.jpg')],
      ),
      act: (cubit) {
        final added = cubit.addImages([
          makeFile('x.jpg'),
          makeFile('y.jpg'),
          makeFile('z.jpg'),
        ]);
        expect(added, 1);
      },
      expect: () => [
        isA<AddProductState>().having(
          (s) => s.images.length,
          'images.length',
          5,
        ),
      ],
    );

    blocTest<AddProductCubit, AddProductState>(
      'emits nothing when the tariff quota is already exhausted',
      build: () => _cubit(repo),
      seed: () => AddProductState(
        status: AddProductStatus.ready,
        context: shopContext,
        images: [for (var i = 0; i < 5; i++) makeImage('$i.jpg')],
      ),
      act: (cubit) {
        final added = cubit.addImages([makeFile('z.jpg')]);
        expect(added, 0);
      },
      expect: () => <AddProductState>[],
    );
  });

  blocTest<AddProductCubit, AddProductState>(
    'setHasDelivery(false) resets a previously-entered delivery price',
    build: () => _cubit(repo),
    seed: () => const AddProductState(
      status: AddProductStatus.ready,
      hasDelivery: true,
      deliveryPrice: 50000,
    ),
    act: (cubit) => cubit.setHasDelivery(false),
    expect: () => [
      isA<AddProductState>()
          .having((s) => s.hasDelivery, 'hasDelivery', false)
          .having((s) => s.deliveryPrice, 'deliveryPrice', 0),
    ],
  );

  blocTest<AddProductCubit, AddProductState>(
    'setHasInstallation(false) resets a previously-entered installation price',
    build: () => _cubit(repo),
    seed: () => const AddProductState(
      status: AddProductStatus.ready,
      hasInstallation: true,
      installationPrice: 120000,
    ),
    act: (cubit) => cubit.setHasInstallation(false),
    expect: () => [
      isA<AddProductState>()
          .having((s) => s.hasInstallation, 'hasInstallation', false)
          .having((s) => s.installationPrice, 'installationPrice', 0),
    ],
  );

  group('toggleColor', () {
    blocTest<AddProductCubit, AddProductState>(
      'adds a colour when the slug is new',
      build: () => _cubit(repo),
      act: (cubit) {
        cubit.toggleColor('white');
        cubit.toggleColor('black');
      },
      expect: () => [
        isA<AddProductState>().having((s) => s.colorSlugs, 'colorSlugs', {
          'white',
        }),
        isA<AddProductState>().having((s) => s.colorSlugs, 'colorSlugs', {
          'white',
          'black',
        }),
      ],
    );

    blocTest<AddProductCubit, AddProductState>(
      'removes a colour on second tap',
      build: () => _cubit(repo),
      seed: () => const AddProductState(colorSlugs: {'white', 'black'}),
      act: (cubit) => cubit.toggleColor('white'),
      expect: () => [
        isA<AddProductState>().having((s) => s.colorSlugs, 'colorSlugs', {
          'black',
        }),
      ],
    );
  });

  group('attributes', () {
    blocTest<AddProductCubit, AddProductState>(
      'setAttribute writes the value into the attributes map',
      build: () => _cubit(repo),
      act: (cubit) => cubit.setAttribute('fabric_type', 'velour'),
      expect: () => [
        isA<AddProductState>().having((s) => s.attributes, 'attributes', {
          'fabric_type': 'velour',
        }),
      ],
    );

    blocTest<AddProductCubit, AddProductState>(
      'setAttribute(null) removes the key from the map',
      build: () => _cubit(repo),
      seed: () => const AddProductState(
        attributes: {'fabric_type': 'velour', 'seats': 4},
      ),
      act: (cubit) => cubit.setAttribute('fabric_type', null),
      expect: () => [
        isA<AddProductState>().having((s) => s.attributes, 'attributes', {
          'seats': 4,
        }),
      ],
    );

    test(
      'selectCategory triggers schema reload and clears prior attributes',
      () async {
        final attrsRepo = _MockAttributesRepo();
        when(
          () => attrsRepo.loadForCategory(
            categoryId: any(named: 'categoryId'),
            subcategoryId: any(named: 'subcategoryId'),
          ),
        ).thenAnswer(
          (_) async => [
            _def('fabric_type', categoryId: 'cat-1', isRequired: true),
          ],
        );

        final cubit = _cubit(repo, attrsRepo: attrsRepo);
        cubit.emit(
          const AddProductState(
            status: AddProductStatus.ready,
            categoryId: 'cat-old',
            attributes: {'old_key': 'stale'},
          ),
        );

        cubit.selectCategory('cat-1');
        // Schema load is async — wait one event loop turn.
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.categoryId, 'cat-1');
        expect(cubit.state.attributes, isEmpty);
        expect(cubit.state.attributeSchema, hasLength(1));
        expect(cubit.state.attributeSchema.first.key, 'fabric_type');
      },
    );

    test(
      'selectSubcategory only prunes subcategory-scoped attribute keys',
      () async {
        final attrsRepo = _MockAttributesRepo();
        // First call returns category-level only; second returns category +
        // subcategory levels (after the user picks a subcategory).
        var callCount = 0;
        when(
          () => attrsRepo.loadForCategory(
            categoryId: any(named: 'categoryId'),
            subcategoryId: any(named: 'subcategoryId'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return [_def('fabric_type', categoryId: 'cat-1')];
          }
          return [
            _def('fabric_type', categoryId: 'cat-1'),
            _def(
              'corner_side',
              subcategoryId: 'sub-1',
              type: AttributeDataType.select,
            ),
          ];
        });

        final cubit = _cubit(repo, attrsRepo: attrsRepo);
        cubit.emit(
          const AddProductState(
            status: AddProductStatus.ready,
            categoryId: 'cat-1',
            attributeSchema: [],
            attributes: {'fabric_type': 'velour', 'corner_side': 'left'},
          ),
        );
        // Seed the schema with a known subcategory-scoped key so the pruner
        // knows what to drop.
        cubit.emit(
          cubit.state.copyWith(
            attributeSchema: [
              _def('fabric_type', categoryId: 'cat-1'),
              _def('corner_side', subcategoryId: 'sub-old'),
            ],
          ),
        );

        cubit.selectSubcategory('sub-1');
        await Future<void>.delayed(Duration.zero);

        // fabric_type (category-scoped) survives; corner_side (sub-scoped) drops.
        expect(cubit.state.attributes, equals({'fabric_type': 'velour'}));
        expect(cubit.state.subcategoryId, 'sub-1');
      },
    );

    test('canSubmit gates on required attributes', () {
      final cubit = _cubit(repo);
      cubit.emit(
        AddProductState(
          status: AddProductStatus.ready,
          context: _context(canAddMore: true),
          name: 'Divan',
          categoryId: 'cat-1',
          price: 100,
          images: [FormImage.local(File('/tmp/a.jpg'))],
          attributeSchema: [
            _def('fabric_type', isRequired: true, categoryId: 'cat-1'),
          ],
          attributes: const {},
        ),
      );
      expect(cubit.state.canSubmit, isFalse, reason: 'required attr missing');

      cubit.setAttribute('fabric_type', 'velour');
      expect(
        cubit.state.canSubmit,
        isTrue,
        reason: 'all required attrs filled',
      );
    });
  });

  group('price currency (UZS|USD)', () {
    const usdRate = 12650.43;

    blocTest<AddProductCubit, AddProductState>(
      'loadContext resolves the CBU rate in the background',
      build: () {
        final rates = _MockExchangeRates();
        when(rates.getUsdRate).thenAnswer((_) async => usdRate);
        when(
          repo.loadShopContext,
        ).thenAnswer((_) async => _context(canAddMore: true));
        return _cubit(repo, rates: rates);
      },
      act: (cubit) => cubit.loadContext(),
      expect: () => [
        isA<AddProductState>().having(
          (s) => s.status,
          'status',
          AddProductStatus.loadingContext,
        ),
        isA<AddProductState>().having((s) => s.usdRate, 'usdRate', usdRate),
        isA<AddProductState>()
            .having((s) => s.status, 'status', AddProductStatus.ready)
            .having((s) => s.usdRate, 'usdRate', usdRate),
      ],
    );

    blocTest<AddProductCubit, AddProductState>(
      'rate fetch failure leaves usdRate null and the form usable in UZS',
      build: () {
        final rates = _MockExchangeRates();
        when(rates.getUsdRate).thenAnswer((_) async => null);
        when(
          repo.loadShopContext,
        ).thenAnswer((_) async => _context(canAddMore: true));
        return _cubit(repo, rates: rates);
      },
      act: (cubit) => cubit.loadContext(),
      expect: () => [
        isA<AddProductState>().having(
          (s) => s.status,
          'status',
          AddProductStatus.loadingContext,
        ),
        isA<AddProductState>()
            .having((s) => s.status, 'status', AddProductStatus.ready)
            .having((s) => s.usdRate, 'usdRate', isNull),
      ],
    );

    blocTest<AddProductCubit, AddProductState>(
      'setPriceCurrency(usd) refuses to switch while the rate is unknown',
      build: () {
        final rates = _MockExchangeRates();
        when(rates.getUsdRate).thenAnswer((_) async => null);
        return _cubit(repo, rates: rates);
      },
      seed: () => const AddProductState(status: AddProductStatus.ready),
      act: (cubit) => cubit.setPriceCurrency(PriceCurrency.usd),
      expect: () => <AddProductState>[],
    );

    blocTest<AddProductCubit, AddProductState>(
      'setPriceCurrency keeps the typed number and flips interpretation',
      build: () => _cubit(repo),
      seed: () => const AddProductState(
        status: AddProductStatus.ready,
        price: 500,
        usdRate: usdRate,
      ),
      act: (cubit) => cubit.setPriceCurrency(PriceCurrency.usd),
      expect: () => [
        isA<AddProductState>()
            .having((s) => s.priceCurrency, 'priceCurrency', PriceCurrency.usd)
            .having((s) => s.price, 'price', 500)
            .having((s) => s.priceInUzs, 'priceInUzs', (500 * usdRate).round()),
      ],
    );

    test('priceInUzs and discountedPriceUzs convert with rounding', () {
      const usd = AddProductState(
        price: 100,
        priceCurrency: PriceCurrency.usd,
        usdRate: usdRate,
        discountPercent: 30,
      );
      expect(usd.priceInUzs, 1265043);
      // 1 265 043 × 0.7 = 885 530.1 → whole som.
      expect(usd.discountedPriceUzs, 885530);

      const uzs = AddProductState(price: 750000, discountPercent: 10);
      expect(uzs.priceInUzs, 750000);
      expect(uzs.discountedPriceUzs, 675000);
    });

    test('canSubmit blocks USD input until a rate exists', () {
      final base = AddProductState(
        status: AddProductStatus.ready,
        context: _context(canAddMore: true),
        name: 'Divan',
        categoryId: 'cat-1',
        price: 100,
        priceCurrency: PriceCurrency.usd,
        images: [FormImage.local(File('/tmp/a.jpg'))],
      );
      expect(base.canSubmit, isFalse, reason: 'no rate to convert with');
      expect(base.copyWith(usdRate: usdRate).canSubmit, isTrue);
    });

    test('submit converts USD to whole-som UZS for the backend', () async {
      final ctx = _context(canAddMore: true);
      when(() => ctx.sellerId).thenReturn('seller-1');
      when(() => repo.createProduct(any())).thenAnswer(
        (_) async => const AddProductResult(productId: 'p-1', imageUrls: []),
      );

      final cubit = _cubit(repo);
      cubit.emit(
        AddProductState(
          status: AddProductStatus.ready,
          context: ctx,
          name: 'Divan',
          categoryId: 'cat-1',
          price: 100,
          priceCurrency: PriceCurrency.usd,
          usdRate: usdRate,
          discountPercent: 30,
          images: [FormImage.local(File('/tmp/a.jpg'))],
        ),
      );

      expect(await cubit.submit(), isTrue);

      final input =
          verify(() => repo.createProduct(captureAny())).captured.single
              as AddProductInput;
      expect(input.price, 1265043, reason: 'backend receives integer UZS');
      expect(input.discountPercent, 30);
    });
  });

  group('generateFromImages (AI suggest)', () {
    _MockShopContext aiContext() {
      final ctx = _context(canAddMore: true);
      when(() => ctx.sellerId).thenReturn('seller-1');
      when(() => ctx.categories).thenReturn(const [
        CategoryModel(
          id: 'cat-1',
          name: 'Divanlar',
          sortOrder: 0,
          subcategories: [
            SubcategoryModel(
              id: 'sub-1',
              categoryId: 'cat-1',
              name: 'Burchakli',
            ),
          ],
        ),
      ]);
      return ctx;
    }

    AddProductCubit readyCubit(_MockAttributesRepo attrs) {
      final cubit = _cubit(repo, attrsRepo: attrs);
      cubit.emit(
        AddProductState(
          status: AddProductStatus.ready,
          context: aiContext(),
          images: [FormImage.local(File('/tmp/a.jpg'))],
        ),
      );
      return cubit;
    }

    test(
      'applies name, description, colours, category and attributes',
      () async {
        final attrs = _MockAttributesRepo();
        when(
          () => repo.suggestFromImages(
            sellerId: any(named: 'sellerId'),
            images: any(named: 'images'),
          ),
        ).thenAnswer(
          (_) async => (
            suggestion: const AiProductSuggestion(
              available: true,
              name: 'Burchakli divan',
              description: 'Yumshoq velür divan.',
              categoryId: 'cat-1',
              subcategoryId: 'sub-1',
              colors: ['grey', 'beige'],
              attributes: {'material': 'velür', 'bogus': 'x'},
            ),
            imageUrls: ['https://r2/a.webp'],
          ),
        );
        when(
          () => attrs.loadForCategory(
            categoryId: any(named: 'categoryId'),
            subcategoryId: any(named: 'subcategoryId'),
          ),
        ).thenAnswer((_) async => [_def('material', categoryId: 'cat-1')]);

        final cubit = readyCubit(attrs);
        final result = await cubit.generateFromImages();

        expect(result.available, isTrue);
        expect(result.sameProduct, isTrue);
        expect(cubit.state.name, 'Burchakli divan');
        expect(cubit.state.description, 'Yumshoq velür divan.');
        expect(cubit.state.categoryId, 'cat-1');
        expect(cubit.state.subcategoryId, 'sub-1');
        expect(cubit.state.colorSlugs, containsAll(['grey', 'beige']));
        // Only schema-defined keys survive — 'bogus' is dropped.
        expect(cubit.state.attributes, equals({'material': 'velür'}));
        expect(cubit.state.isAiBusy, isFalse);
      },
    );

    test('returns false and stays clean when AI is unavailable', () async {
      when(
        () => repo.suggestFromImages(
          sellerId: any(named: 'sellerId'),
          images: any(named: 'images'),
        ),
      ).thenAnswer(
        (_) async => (
          suggestion: const AiProductSuggestion(available: false),
          imageUrls: ['https://r2/a.webp'],
        ),
      );

      final cubit = readyCubit(_MockAttributesRepo());
      final result = await cubit.generateFromImages();

      expect(result.available, isFalse);
      expect(cubit.state.name, isEmpty);
      expect(cubit.state.categoryId, isNull);
      expect(cubit.state.isAiBusy, isFalse);
    });

    test('no-op when there are no images', () async {
      final cubit = _cubit(repo);
      cubit.emit(
        AddProductState(status: AddProductStatus.ready, context: aiContext()),
      );
      final result = await cubit.generateFromImages();

      expect(result.available, isFalse);
      verifyNever(
        () => repo.suggestFromImages(
          sellerId: any(named: 'sellerId'),
          images: any(named: 'images'),
        ),
      );
    });

    test('clears busy flag and returns false when the repo throws', () async {
      when(
        () => repo.suggestFromImages(
          sellerId: any(named: 'sellerId'),
          images: any(named: 'images'),
        ),
      ).thenThrow(Exception('network down'));

      final cubit = readyCubit(_MockAttributesRepo());
      final result = await cubit.generateFromImages();

      expect(result.available, isFalse);
      expect(cubit.state.isAiBusy, isFalse);
    });

    test('passes sameProduct:false through for mixed products', () async {
      when(
        () => repo.suggestFromImages(
          sellerId: any(named: 'sellerId'),
          images: any(named: 'images'),
        ),
      ).thenAnswer(
        (_) async => (
          suggestion: const AiProductSuggestion(
            available: true,
            sameProduct: false,
            name: 'Divan',
            categoryId: 'cat-1',
          ),
          imageUrls: ['https://r2/a.webp'],
        ),
      );
      final attrs = _MockAttributesRepo();
      when(
        () => attrs.loadForCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
        ),
      ).thenAnswer((_) async => const []);

      final cubit = readyCubit(attrs);
      final result = await cubit.generateFromImages();

      // Still applies the primary product; only the flag differs so the UI
      // can warn the seller to split the listing.
      expect(result.available, isTrue);
      expect(result.sameProduct, isFalse);
      expect(cubit.state.name, 'Divan');
      expect(cubit.state.categoryId, 'cat-1');
    });

    test('trims to the first 4 images before sending (backend cap)', () async {
      List<FormImage>? sentImages;
      when(
        () => repo.suggestFromImages(
          sellerId: any(named: 'sellerId'),
          images: any(named: 'images'),
        ),
      ).thenAnswer((invocation) async {
        sentImages = invocation.namedArguments[#images] as List<FormImage>;
        return (
          suggestion: const AiProductSuggestion(available: false),
          imageUrls: const <String>[],
        );
      });

      final cubit = _cubit(repo);
      cubit.emit(
        AddProductState(
          status: AddProductStatus.ready,
          context: aiContext(),
          images: [
            for (var i = 0; i < 6; i++) FormImage.local(File('/tmp/$i.jpg')),
          ],
        ),
      );
      await cubit.generateFromImages();

      expect(sentImages, isNotNull);
      expect(sentImages!.length, 4, reason: 'capped at the backend limit');
      // The form keeps all 6 — only the AI call is trimmed.
      expect(cubit.state.images.length, 6);
    });
  });

  group('edit mode', () {
    SellerProduct product() => SellerProduct(
      id: 'prod-1',
      name: const MultilingualText(uz: 'Burchakli divan'),
      description: const MultilingualText(uz: 'Yumshoq divan.'),
      categorySlug: 'cat-1',
      subcategoryId: 'sub-1',
      colors: const ['grey'],
      price: 1000000,
      discountPrice: 900000,
      sku: 'MH-2026-0001',
      images: const [
        SellerProductImage(id: 'u1', remoteUrl: 'https://r2/u1.webp'),
      ],
      attributes: const {'material': 'velür', 'bogus': 'x'},
      productionTimeDays: '5-7',
      hasDelivery: true,
      deliveryPrice: 50000,
      warrantyMonths: 6,
      status: SellerProductStatus.approved,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    _MockShopContext editContext() {
      final ctx = _context(canAddMore: false);
      when(() => ctx.sellerId).thenReturn('seller-1');
      when(() => ctx.categories).thenReturn(const [
        CategoryModel(
          id: 'cat-1',
          name: 'Divanlar',
          sortOrder: 0,
          subcategories: [
            SubcategoryModel(id: 'sub-1', categoryId: 'cat-1', name: 'Burchak'),
          ],
        ),
      ]);
      return ctx;
    }

    test('loadForEdit prefills the form and skips the tariff gate', () async {
      final attrs = _MockAttributesRepo();
      when(
        () => attrs.loadForCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
        ),
      ).thenAnswer((_) async => [_def('material', categoryId: 'cat-1')]);
      // canAddMore:false on purpose — editing must still reach `ready`.
      when(repo.loadShopContext).thenAnswer((_) async => editContext());

      final cubit = _cubit(repo, attrsRepo: attrs);
      await cubit.loadForEdit(product());

      expect(cubit.state.status, AddProductStatus.ready);
      expect(cubit.state.isEditing, isTrue);
      expect(cubit.state.editingProductId, 'prod-1');
      expect(cubit.state.name, 'Burchakli divan');
      expect(cubit.state.price, 1000000);
      expect(cubit.state.discountPercent, 10);
      expect(cubit.state.sku, 'MH-2026-0001');
      expect(cubit.state.categoryId, 'cat-1');
      expect(cubit.state.subcategoryId, 'sub-1');
      expect(cubit.state.colorSlugs, {'grey'});
      // Only schema-defined attribute keys survive the prefill.
      expect(cubit.state.attributes, equals({'material': 'velür'}));
      expect(cubit.state.images, hasLength(1));
      expect(cubit.state.images.single.url, 'https://r2/u1.webp');
      expect(cubit.state.hasDelivery, isTrue);
      expect(cubit.state.warrantyMonths, 6);
    });

    test('submit PATCHes the existing row instead of creating', () async {
      final attrs = _MockAttributesRepo();
      when(
        () => attrs.loadForCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
        ),
      ).thenAnswer((_) async => const []);
      when(repo.loadShopContext).thenAnswer((_) async => editContext());
      when(() => repo.updateProduct(any(), any())).thenAnswer((_) async {});

      final cubit = _cubit(repo, attrsRepo: attrs);
      await cubit.loadForEdit(product());
      final ok = await cubit.submit();

      expect(ok, isTrue);
      expect(cubit.state.status, AddProductStatus.success);
      verify(() => repo.updateProduct('prod-1', any())).called(1);
      verifyNever(() => repo.createProduct(any()));
    });
  });
}

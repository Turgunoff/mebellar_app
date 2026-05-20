import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/seller/features/products/bloc/add_product_cubit.dart';
import 'package:woody_app/seller/features/products/data/add_product_repository.dart';
import 'package:woody_app/seller/features/products/data/attributes_repository.dart';
import 'package:woody_app/shared/models/attribute_definition.dart';

class _MockAddProductRepo extends Mock implements AddProductRepository {}

class _MockAttributesRepo extends Mock implements AttributesRepository {}

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
}) {
  return AddProductCubit(
    repository: repo,
    attributesRepository: attrsRepo ?? _MockAttributesRepo(),
  );
}

void main() {
  late _MockAddProductRepo repo;

  setUp(() => repo = _MockAddProductRepo());

  blocTest<AddProductCubit, AddProductState>(
    'loadContext emits ready when the plan allows more products',
    build: () {
      when(repo.loadShopContext)
          .thenAnswer((_) async => _context(canAddMore: true));
      return _cubit(repo);
    },
    act: (cubit) => cubit.loadContext(),
    expect: () => [
      isA<AddProductState>()
          .having((s) => s.status, 'status', AddProductStatus.loadingContext),
      isA<AddProductState>()
          .having((s) => s.status, 'status', AddProductStatus.ready),
    ],
  );

  blocTest<AddProductCubit, AddProductState>(
    'loadContext emits tariffBlocked once the plan quota is reached',
    build: () {
      when(repo.loadShopContext)
          .thenAnswer((_) async => _context(canAddMore: false));
      return _cubit(repo);
    },
    act: (cubit) => cubit.loadContext(),
    expect: () => [
      isA<AddProductState>()
          .having((s) => s.status, 'status', AddProductStatus.loadingContext),
      isA<AddProductState>()
          .having((s) => s.status, 'status', AddProductStatus.tariffBlocked),
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
      isA<AddProductState>()
          .having((s) => s.status, 'status', AddProductStatus.loadingContext),
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
      isA<AddProductState>()
          .having((s) => s.discountPercent, 'discountPercent', 100),
    ],
  );

  group('addImages', () {
    final shopContext = _context(canAddMore: true);
    File makeFile(String name) => File('/tmp/$name');

    blocTest<AddProductCubit, AddProductState>(
      'appends all picked images when remaining quota covers them',
      build: () => _cubit(repo),
      seed: () => AddProductState(
        status: AddProductStatus.ready,
        context: shopContext,
        imageFiles: [makeFile('a.jpg')],
      ),
      act: (cubit) {
        final added = cubit.addImages([makeFile('b.jpg'), makeFile('c.jpg')]);
        expect(added, 2);
      },
      expect: () => [
        isA<AddProductState>()
            .having((s) => s.imageFiles.length, 'imageFiles.length', 3),
      ],
    );

    blocTest<AddProductCubit, AddProductState>(
      'trims the picked batch to the remaining tariff slots',
      build: () => _cubit(repo),
      seed: () => AddProductState(
        status: AddProductStatus.ready,
        context: shopContext,
        imageFiles: [for (var i = 0; i < 4; i++) makeFile('$i.jpg')],
      ),
      act: (cubit) {
        final added = cubit.addImages(
          [makeFile('x.jpg'), makeFile('y.jpg'), makeFile('z.jpg')],
        );
        expect(added, 1);
      },
      expect: () => [
        isA<AddProductState>()
            .having((s) => s.imageFiles.length, 'imageFiles.length', 5),
      ],
    );

    blocTest<AddProductCubit, AddProductState>(
      'emits nothing when the tariff quota is already exhausted',
      build: () => _cubit(repo),
      seed: () => AddProductState(
        status: AddProductStatus.ready,
        context: shopContext,
        imageFiles: [for (var i = 0; i < 5; i++) makeFile('$i.jpg')],
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
        isA<AddProductState>().having(
          (s) => s.colorSlugs,
          'colorSlugs',
          {'white'},
        ),
        isA<AddProductState>().having(
          (s) => s.colorSlugs,
          'colorSlugs',
          {'white', 'black'},
        ),
      ],
    );

    blocTest<AddProductCubit, AddProductState>(
      'removes a colour on second tap',
      build: () => _cubit(repo),
      seed: () => const AddProductState(
        colorSlugs: {'white', 'black'},
      ),
      act: (cubit) => cubit.toggleColor('white'),
      expect: () => [
        isA<AddProductState>().having(
          (s) => s.colorSlugs,
          'colorSlugs',
          {'black'},
        ),
      ],
    );
  });

  group('attributes', () {
    blocTest<AddProductCubit, AddProductState>(
      'setAttribute writes the value into the attributes map',
      build: () => _cubit(repo),
      act: (cubit) => cubit.setAttribute('fabric_type', 'velour'),
      expect: () => [
        isA<AddProductState>().having(
          (s) => s.attributes,
          'attributes',
          {'fabric_type': 'velour'},
        ),
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
        isA<AddProductState>().having(
          (s) => s.attributes,
          'attributes',
          {'seats': 4},
        ),
      ],
    );

    test('selectCategory triggers schema reload and clears prior attributes',
        () async {
      final attrsRepo = _MockAttributesRepo();
      when(() => attrsRepo.loadForCategory(
            categoryId: any(named: 'categoryId'),
            subcategoryId: any(named: 'subcategoryId'),
          )).thenAnswer((_) async => [
            _def('fabric_type', categoryId: 'cat-1', isRequired: true),
          ]);

      final cubit = _cubit(repo, attrsRepo: attrsRepo);
      cubit.emit(const AddProductState(
        status: AddProductStatus.ready,
        categoryId: 'cat-old',
        attributes: {'old_key': 'stale'},
      ));

      cubit.selectCategory('cat-1');
      // Schema load is async — wait one event loop turn.
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.categoryId, 'cat-1');
      expect(cubit.state.attributes, isEmpty);
      expect(cubit.state.attributeSchema, hasLength(1));
      expect(cubit.state.attributeSchema.first.key, 'fabric_type');
    });

    test('selectSubcategory only prunes subcategory-scoped attribute keys',
        () async {
      final attrsRepo = _MockAttributesRepo();
      // First call returns category-level only; second returns category +
      // subcategory levels (after the user picks a subcategory).
      var callCount = 0;
      when(() => attrsRepo.loadForCategory(
            categoryId: any(named: 'categoryId'),
            subcategoryId: any(named: 'subcategoryId'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return [
            _def('fabric_type', categoryId: 'cat-1'),
          ];
        }
        return [
          _def('fabric_type', categoryId: 'cat-1'),
          _def('corner_side',
              subcategoryId: 'sub-1', type: AttributeDataType.select),
        ];
      });

      final cubit = _cubit(repo, attrsRepo: attrsRepo);
      cubit.emit(const AddProductState(
        status: AddProductStatus.ready,
        categoryId: 'cat-1',
        attributeSchema: [],
        attributes: {'fabric_type': 'velour', 'corner_side': 'left'},
      ));
      // Seed the schema with a known subcategory-scoped key so the pruner
      // knows what to drop.
      cubit.emit(cubit.state.copyWith(attributeSchema: [
        _def('fabric_type', categoryId: 'cat-1'),
        _def('corner_side', subcategoryId: 'sub-old'),
      ]));

      cubit.selectSubcategory('sub-1');
      await Future<void>.delayed(Duration.zero);

      // fabric_type (category-scoped) survives; corner_side (sub-scoped) drops.
      expect(cubit.state.attributes, equals({'fabric_type': 'velour'}));
      expect(cubit.state.subcategoryId, 'sub-1');
    });

    test('canSubmit gates on required attributes', () {
      final cubit = _cubit(repo);
      cubit.emit(AddProductState(
        status: AddProductStatus.ready,
        context: _context(canAddMore: true),
        name: 'Divan',
        categoryId: 'cat-1',
        price: 100,
        imageFiles: [File('/tmp/a.jpg')],
        attributeSchema: [
          _def('fabric_type', isRequired: true, categoryId: 'cat-1'),
        ],
        attributes: const {},
      ));
      expect(cubit.state.canSubmit, isFalse, reason: 'required attr missing');

      cubit.setAttribute('fabric_type', 'velour');
      expect(cubit.state.canSubmit, isTrue,
          reason: 'all required attrs filled');
    });
  });
}

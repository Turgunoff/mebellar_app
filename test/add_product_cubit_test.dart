import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/seller/features/products/bloc/add_product_cubit.dart';
import 'package:woody_app/seller/features/products/data/add_product_repository.dart';

class _MockAddProductRepo extends Mock implements AddProductRepository {}

class _MockShopContext extends Mock implements AddProductShopContext {}

_MockShopContext _context({required bool canAddMore}) {
  final ctx = _MockShopContext();
  when(() => ctx.canAddMoreProducts).thenReturn(canAddMore);
  when(() => ctx.shopId).thenReturn('shop-1');
  when(() => ctx.activeProductsCount).thenReturn(2);
  when(() => ctx.maxImages).thenReturn(5);
  return ctx;
}

void main() {
  late _MockAddProductRepo repo;

  setUp(() => repo = _MockAddProductRepo());

  blocTest<AddProductCubit, AddProductState>(
    'loadContext emits ready when the plan allows more products',
    build: () {
      when(repo.loadShopContext)
          .thenAnswer((_) async => _context(canAddMore: true));
      return AddProductCubit(repository: repo);
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
      return AddProductCubit(repository: repo);
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
      return AddProductCubit(repository: repo);
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
    build: () => AddProductCubit(repository: repo),
    act: (cubit) => cubit.setName('Yumshoq divan'),
    expect: () => [
      isA<AddProductState>().having((s) => s.name, 'name', 'Yumshoq divan'),
    ],
  );

  blocTest<AddProductCubit, AddProductState>(
    'setDiscountPercent clamps values above 100',
    build: () => AddProductCubit(repository: repo),
    act: (cubit) => cubit.setDiscountPercent(150),
    expect: () => [
      isA<AddProductState>()
          .having((s) => s.discountPercent, 'discountPercent', 100),
    ],
  );

  blocTest<AddProductCubit, AddProductState>(
    'setHasDelivery(false) resets a previously-entered delivery price',
    build: () => AddProductCubit(repository: repo),
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
}

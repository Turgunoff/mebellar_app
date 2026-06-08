import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/customer/features/shop/cubit/shop_profile_cubit.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/models/shop_profile.dart';
import 'package:woody_app/shared/models/working_hours.dart';
import 'package:woody_app/shared/repositories/shop_repository.dart';

ShopProfile _shop() => ShopProfile(
  id: 'shop-1',
  name: 'New Mebel',
  workingHours: WeeklyHours.allClosed(),
  productCount: 2,
);

ProductModel _product(String id) => ProductModel(
  id: id,
  categoryId: 'c1',
  name: 'P$id',
  price: 100,
  images: const [],
  stock: 1,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('ShopProfileCubit', () {
    test(
      'settles on ready with the shop and its products on success',
      () async {
        final cubit = ShopProfileCubit(
          MockShopRepository(
            shop: _shop(),
            products: [_product('1'), _product('2')],
          ),
        );
        addTearDown(cubit.close);

        await cubit.load('shop-1');

        expect(cubit.state.status, ShopProfileStatus.ready);
        expect(cubit.state.shop?.id, 'shop-1');
        expect(cubit.state.products.length, 2);
      },
    );

    test('settles on error when the shop fetch fails', () async {
      final cubit = ShopProfileCubit(
        MockShopRepository(shopError: const UnknownFailure(message: 'boom')),
      );
      addTearDown(cubit.close);

      await cubit.load('shop-1');

      expect(cubit.state.status, ShopProfileStatus.error);
      expect(cubit.state.shop, isNull);
    });

    test('renders header even when only the product list is empty', () async {
      final cubit = ShopProfileCubit(
        MockShopRepository(shop: _shop(), products: const []),
      );
      addTearDown(cubit.close);

      await cubit.load('shop-1');

      expect(cubit.state.status, ShopProfileStatus.ready);
      expect(cubit.state.products, isEmpty);
    });
  });
}

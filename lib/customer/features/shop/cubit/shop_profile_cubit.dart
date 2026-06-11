import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/shop_profile.dart';
import '../../../../shared/repositories/shop_repository.dart';

enum ShopProfileStatus { loading, ready, error }

class ShopProfileState extends Equatable {
  const ShopProfileState({
    this.status = ShopProfileStatus.loading,
    this.shop,
    this.products = const [],
  });

  final ShopProfileStatus status;
  final ShopProfile? shop;
  final List<ProductModel> products;

  @override
  List<Object?> get props => [status, shop, products];
}

/// Loads a public shop profile and its product listing in one shot. The
/// products call never throws (the repo returns `[]` on failure), so a healthy
/// profile still renders its header + stats when only the listing is down.
class ShopProfileCubit extends Cubit<ShopProfileState> {
  ShopProfileCubit(this._repo) : super(const ShopProfileState());

  final ShopRepository _repo;

  Future<void> load(String shopId) async {
    emit(const ShopProfileState());
    final (shopResult, products) = await (
      _repo.shopById(shopId),
      _repo.productsByShop(shopId),
    ).wait;
    if (isClosed) return;

    shopResult.fold(
      ok: (shop) => emit(
        ShopProfileState(
          status: ShopProfileStatus.ready,
          shop: shop,
          products: products,
        ),
      ),
      err: (_) => emit(const ShopProfileState(status: ShopProfileStatus.error)),
    );
  }
}

import 'package:equatable/equatable.dart';

import 'cart_item.dart';
import 'shop.dart';

class CartShopGroup extends Equatable {
  const CartShopGroup({required this.shop, required this.items});

  final Shop shop;
  final List<CartItem> items;

  num get subtotal => items.fold<num>(0, (sum, it) => sum + it.lineTotal);
  int get unitsCount => items.fold<int>(0, (sum, it) => sum + it.quantity);

  @override
  List<Object?> get props => [shop.id, items];
}

class Cart extends Equatable {
  const Cart({this.items = const []});

  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get totalUnits => items.fold<int>(0, (sum, it) => sum + it.quantity);
  num get grandTotal => items.fold<num>(0, (sum, it) => sum + it.lineTotal);

  /// Group items by shop, preserving insertion order. Items without a shop
  /// (defensive — should not happen in production) collapse into a synthetic
  /// "Other" group so the UI never silently drops them.
  List<CartShopGroup> groupByShop() {
    final order = <String>[];
    final byId = <String, List<CartItem>>{};
    final shopById = <String, Shop>{};
    for (final it in items) {
      final shop = it.product.shop;
      if (shop == null) continue;
      if (!byId.containsKey(shop.id)) {
        order.add(shop.id);
        byId[shop.id] = [];
        shopById[shop.id] = shop;
      }
      byId[shop.id]!.add(it);
    }
    return [
      for (final id in order)
        CartShopGroup(shop: shopById[id]!, items: byId[id]!),
    ];
  }

  Cart copyWith({List<CartItem>? items}) {
    return Cart(items: items ?? this.items);
  }

  @override
  List<Object?> get props => [items];
}

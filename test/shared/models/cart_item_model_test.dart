import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';

void main() {
  group('CartItemModel.fromJson', () {
    test('reads name/image/price from the product_snapshot', () {
      final m = CartItemModel.fromJson(const {
        'id': 'row-1',
        'product_id': 'p1',
        'quantity': 3,
        'product_snapshot': {
          'id': 'p1',
          'name': "NESMA OQ yotoq to'plami",
          'image': 'https://cdn.example/img.jpg',
          'price': 450,
          'color': 'oq',
        },
      });
      expect(m.productName, "NESMA OQ yotoq to'plami");
      expect(m.productImage, 'https://cdn.example/img.jpg');
      expect(m.productPrice, 450);
      expect(m.selectedColor, 'oq');
      expect(m.lineTotal, 1350);
    });

    test('falls back to snapshot selected_color for rows written by old '
        'app builds that POSTed the colour without a full snapshot', () {
      final m = CartItemModel.fromJson(const {
        'id': 'row-1',
        'product_id': 'p1',
        'quantity': 1,
        'product_snapshot': {'selected_color': 'qora', 'name': 'Divan'},
      });
      expect(m.selectedColor, 'qora');
    });

    test('snapshot json round-trips through fromJson', () {
      const original = CartItemModel(
        id: 'p1',
        productId: 'p1',
        productName: 'Divan',
        productImage: 'https://cdn.example/d.jpg',
        productPrice: 4500000,
        quantity: 2,
        selectedColor: 'oq',
      );
      final decoded = CartItemModel.fromJson(original.toHiveJson());
      expect(decoded.productName, original.productName);
      expect(decoded.productImage, original.productImage);
      expect(decoded.productPrice, original.productPrice);
      expect(decoded.quantity, original.quantity);
      expect(decoded.selectedColor, original.selectedColor);
    });
  });
}

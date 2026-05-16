import 'package:flutter/material.dart';

/// Owns the lifecycle of the ten `TextEditingController`s the product form
/// needs. Extracted from `_ProductFormViewState` (ROADMAP B.4) so the screen
/// shell no longer carries a 10-field `initState`/`dispose` boilerplate block.
class ProductFormControllers {
  ProductFormControllers()
      : name = TextEditingController(),
        description = TextEditingController(),
        price = TextEditingController(),
        width = TextEditingController(),
        height = TextEditingController(),
        depth = TextEditingController(),
        material = TextEditingController(),
        productionDays = TextEditingController(text: '3-5'),
        deliveryPrice = TextEditingController(),
        warrantyMonths = TextEditingController(text: '12');

  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController price;
  final TextEditingController width;
  final TextEditingController height;
  final TextEditingController depth;
  final TextEditingController material;
  final TextEditingController productionDays;
  final TextEditingController deliveryPrice;
  final TextEditingController warrantyMonths;

  List<TextEditingController> get _all => [
        name,
        description,
        price,
        width,
        height,
        depth,
        material,
        productionDays,
        deliveryPrice,
        warrantyMonths,
      ];

  /// Disposes every controller. Call once from the owning `State.dispose`.
  void dispose() {
    for (final controller in _all) {
      controller.dispose();
    }
  }
}

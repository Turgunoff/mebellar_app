import 'package:flutter/material.dart';

/// Owns the lifecycle of the `TextEditingController`s the product form needs
/// outside of the dynamic-attributes engine. Specs-section controllers
/// (width/height/depth/material) were removed when those fields moved into
/// the per-category attribute schema — those values now live in cubit state
/// only and are wired through the `DynamicAttributesSection` renderer.
class ProductFormControllers {
  ProductFormControllers()
      : name = TextEditingController(),
        description = TextEditingController(),
        price = TextEditingController(),
        productionDays = TextEditingController(text: '3-5'),
        deliveryPrice = TextEditingController(),
        warrantyMonths = TextEditingController(text: '12');

  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController price;
  final TextEditingController productionDays;
  final TextEditingController deliveryPrice;
  final TextEditingController warrantyMonths;

  List<TextEditingController> get _all => [
        name,
        description,
        price,
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

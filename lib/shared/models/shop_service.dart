import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Service offered by a shop (delivery, assembly, warranty, ...).
/// V1 is mock-driven; backend will return `service_type` codes that map onto
/// the [ShopService.fromCode] constructor.
class ShopService extends Equatable {
  const ShopService({
    required this.code,
    required this.icon,
    required this.titleUz,
    required this.titleRu,
    required this.titleEn,
    this.config,
  });

  final String code;
  final IconData icon;
  final String titleUz;
  final String titleRu;
  final String titleEn;
  final Map<String, dynamic>? config;

  String title(String lang) {
    return switch (lang) {
      'ru' => titleRu,
      'en' => titleEn,
      _ => titleUz,
    };
  }

  /// Built-in services. Keeps the icon + i18n in one place so the chip list
  /// renders consistently across product detail, shop page, and checkout.
  static const ShopService freeDelivery = ShopService(
    code: 'free_delivery',
    icon: Icons.local_shipping_outlined,
    titleUz: 'Bepul yetkazib berish',
    titleRu: 'Бесплатная доставка',
    titleEn: 'Free delivery',
  );

  static const ShopService assembly = ShopService(
    code: 'assembly',
    icon: Icons.handyman_outlined,
    titleUz: 'Yig\'ish xizmati',
    titleRu: 'Сборка',
    titleEn: 'Assembly',
  );

  static const ShopService warranty = ShopService(
    code: 'warranty',
    icon: Icons.verified_user_outlined,
    titleUz: 'Kafolat',
    titleRu: 'Гарантия',
    titleEn: 'Warranty',
  );

  static const ShopService installment = ShopService(
    code: 'installment',
    icon: Icons.payments_outlined,
    titleUz: 'Bo\'lib to\'lash',
    titleRu: 'Рассрочка',
    titleEn: 'Installment',
  );

  static const ShopService express = ShopService(
    code: 'express_delivery',
    icon: Icons.flash_on_outlined,
    titleUz: 'Tezkor yetkazish',
    titleRu: 'Экспресс доставка',
    titleEn: 'Express delivery',
  );

  static const ShopService customOrder = ShopService(
    code: 'custom_order',
    icon: Icons.design_services_outlined,
    titleUz: 'Buyurtma asosida',
    titleRu: 'На заказ',
    titleEn: 'Custom order',
  );

  static ShopService? fromCode(String code) {
    return switch (code) {
      'free_delivery' => freeDelivery,
      'assembly' => assembly,
      'warranty' => warranty,
      'installment' => installment,
      'express_delivery' => express,
      'custom_order' => customOrder,
      _ => null,
    };
  }

  @override
  List<Object?> get props => [code];
}

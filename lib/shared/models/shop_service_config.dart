import 'package:equatable/equatable.dart';

import 'shop_service.dart';

/// Per-service configuration knobs the seller toggles on/off and parametrises.
/// Sprint 8 ships only the universally relevant params (min order, fee, days);
/// product-level overrides land in Sprint 11 polish.
class ShopServiceConfig extends Equatable {
  const ShopServiceConfig({
    required this.service,
    required this.enabled,
    this.minOrderAmount,
    this.feeAmount,
    this.warrantyMonths,
    this.installmentMonths,
  });

  final ShopService service;
  final bool enabled;

  /// `free_delivery`: minimum order total to qualify.
  final num? minOrderAmount;

  /// Generic fee for paid services (`assembly`, `express_delivery`).
  final num? feeAmount;

  /// `warranty` only — months of free coverage.
  final int? warrantyMonths;

  /// `installment` only — supported plan length.
  final int? installmentMonths;

  ShopServiceConfig copyWith({
    bool? enabled,
    num? minOrderAmount,
    num? feeAmount,
    int? warrantyMonths,
    int? installmentMonths,
    bool clearMinOrder = false,
    bool clearFee = false,
  }) {
    return ShopServiceConfig(
      service: service,
      enabled: enabled ?? this.enabled,
      minOrderAmount:
          clearMinOrder ? null : (minOrderAmount ?? this.minOrderAmount),
      feeAmount: clearFee ? null : (feeAmount ?? this.feeAmount),
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      installmentMonths: installmentMonths ?? this.installmentMonths,
    );
  }

  Map<String, dynamic> toJson() => {
        'service_type': service.code,
        'enabled': enabled,
        if (minOrderAmount != null) 'min_order_amount': minOrderAmount,
        if (feeAmount != null) 'fee_amount': feeAmount,
        if (warrantyMonths != null) 'warranty_months': warrantyMonths,
        if (installmentMonths != null) 'installment_months': installmentMonths,
      };

  @override
  List<Object?> get props => [
        service.code,
        enabled,
        minOrderAmount,
        feeAmount,
        warrantyMonths,
        installmentMonths,
      ];
}

import 'package:equatable/equatable.dart';

import 'region.dart';

class Address extends Equatable {
  const Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.region,
    required this.city,
    this.district,
    required this.streetLine,
    this.apartment,
    this.landmark,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  final String id;

  /// User-given label, e.g. "Uy", "Ish".
  final String label;
  final String recipientName;
  final String phone;
  final Region region;
  final Region city;
  final Region? district;
  final String streetLine;
  final String? apartment;
  final String? landmark;
  final double? lat;
  final double? lng;
  final bool isDefault;

  String formatted(String lang) {
    final parts = <String>[
      region.name.get(lang),
      city.name.get(lang),
      if (district != null) district!.name.get(lang),
      streetLine,
      if (apartment != null && apartment!.isNotEmpty) 'kv. $apartment',
    ];
    return parts.join(', ');
  }

  Address copyWith({
    String? id,
    String? label,
    String? recipientName,
    String? phone,
    Region? region,
    Region? city,
    Region? district,
    bool clearDistrict = false,
    String? streetLine,
    String? apartment,
    String? landmark,
    double? lat,
    double? lng,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      region: region ?? this.region,
      city: city ?? this.city,
      district: clearDistrict ? null : (district ?? this.district),
      streetLine: streetLine ?? this.streetLine,
      apartment: apartment ?? this.apartment,
      landmark: landmark ?? this.landmark,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  List<Object?> get props => [
        id,
        label,
        recipientName,
        phone,
        region.id,
        city.id,
        district?.id,
        streetLine,
        apartment,
        landmark,
        lat,
        lng,
        isDefault,
      ];
}

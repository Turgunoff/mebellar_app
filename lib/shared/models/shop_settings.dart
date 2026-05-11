import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'multilingual_text.dart';
import 'region.dart';
import 'working_hours.dart';

enum ShopVisibility { public, hidden }

/// What the seller can edit in shop settings — distinct from `Shop` which
/// is the read model the customer sees. We keep them separate so saving the
/// seller form doesn't accidentally leak fields the customer endpoint
/// doesn't return (e.g. `working_hours`).
class ShopSettings extends Equatable {
  const ShopSettings({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    this.logoUrl,
    this.coverUrl,
    this.contactPhone,
    this.contactEmail,
    this.telegramUsername,
    this.brandColor,
    required this.region,
    required this.city,
    this.district,
    required this.streetLine,
    this.lat,
    this.lng,
    required this.workingHours,
    this.visibility = ShopVisibility.public,
  });

  final String id;
  final String slug;
  final MultilingualText name;
  final MultilingualText description;
  final String? logoUrl;
  final String? coverUrl;
  final String? contactPhone;
  final String? contactEmail;
  final String? telegramUsername;

  /// Hex string like `#FF5733` (with leading hash). Mock data keeps it simple.
  final String? brandColor;
  final Region region;
  final Region city;
  final Region? district;
  final String streetLine;
  final double? lat;
  final double? lng;
  final WeeklyHours workingHours;
  final ShopVisibility visibility;

  bool get isPublic => visibility == ShopVisibility.public;

  Color? get brandColorValue {
    final hex = brandColor;
    if (hex == null) return null;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6) return null;
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  ShopSettings copyWith({
    MultilingualText? name,
    MultilingualText? description,
    String? logoUrl,
    String? coverUrl,
    String? contactPhone,
    String? contactEmail,
    String? telegramUsername,
    String? brandColor,
    Region? region,
    Region? city,
    Region? district,
    bool clearDistrict = false,
    String? streetLine,
    double? lat,
    double? lng,
    WeeklyHours? workingHours,
    ShopVisibility? visibility,
  }) {
    return ShopSettings(
      id: id,
      slug: slug,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      telegramUsername: telegramUsername ?? this.telegramUsername,
      brandColor: brandColor ?? this.brandColor,
      region: region ?? this.region,
      city: city ?? this.city,
      district: clearDistrict ? null : (district ?? this.district),
      streetLine: streetLine ?? this.streetLine,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      workingHours: workingHours ?? this.workingHours,
      visibility: visibility ?? this.visibility,
    );
  }

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        description,
        logoUrl,
        coverUrl,
        contactPhone,
        contactEmail,
        telegramUsername,
        brandColor,
        region.id,
        city.id,
        district?.id,
        streetLine,
        lat,
        lng,
        workingHours,
        visibility,
      ];
}

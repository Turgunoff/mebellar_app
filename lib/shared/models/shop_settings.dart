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

  /// Parses a `public.shops` row. `name`/`description`/`region`/`city`/
  /// `district`/`working_hours` are stored as embedded jsonb so the seller
  /// settings view needs no joins — see `docs/supabase_rls_policies.sql.md`.
  factory ShopSettings.fromJson(Map<String, dynamic> json) {
    return ShopSettings(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: MultilingualText.fromJson(json['name'] as Map<String, dynamic>?),
      description:
          MultilingualText.fromJson(json['description'] as Map<String, dynamic>?),
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      telegramUsername: json['telegram_username'] as String?,
      brandColor: json['brand_color'] as String?,
      region: _regionOrBlank(json['region']),
      city: _regionOrBlank(json['city']),
      district: json['district'] is Map<String, dynamic>
          ? Region.fromJson(json['district'] as Map<String, dynamic>)
          : null,
      streetLine: json['street_line'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      workingHours:
          WeeklyHours.fromJson(json['working_hours'] as Map<String, dynamic>?),
      visibility: _visibilityFromName(json['visibility'] as String?),
    );
  }

  /// Serialises the seller-editable columns of a `shops` row. Null fields are
  /// written explicitly so clearing a value (e.g. removing a logo) persists.
  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name.toJson(),
        'description': description.toJson(),
        'logo_url': logoUrl,
        'cover_url': coverUrl,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'telegram_username': telegramUsername,
        'brand_color': brandColor,
        'region': region.toJson(),
        'city': city.toJson(),
        'district': district?.toJson(),
        'street_line': streetLine,
        'lat': lat,
        'lng': lng,
        'working_hours': workingHours.toJson(),
        'visibility': visibility.name,
      };

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

const _blankRegion = Region(id: '_', code: '_', name: MultilingualText());

Region _regionOrBlank(Object? raw) =>
    raw is Map<String, dynamic> ? Region.fromJson(raw) : _blankRegion;

ShopVisibility _visibilityFromName(String? name) {
  return ShopVisibility.values.firstWhere(
    (v) => v.name == name,
    orElse: () => ShopVisibility.public,
  );
}

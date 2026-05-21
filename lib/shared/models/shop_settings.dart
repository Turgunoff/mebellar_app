import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'working_hours.dart';

enum ShopVisibility { public, hidden }

/// Seller-editable view of a `public.shops` row, plus the contact-info
/// slice of the owning `public.sellers` row.
///
/// The DB stores shop name/description as plain text (no multilingual
/// jsonb yet) and the seller's contact channels live on `sellers`, not
/// `shops` — both quirks are surfaced here so the UI form binds to a
/// single value type and the repository fans the save out to the two
/// tables it actually touches.
class ShopSettings extends Equatable {
  const ShopSettings({
    required this.id,
    required this.name,
    required this.description,
    this.logoUrl,
    this.coverUrl,
    this.contactPhone,
    this.contactEmail,
    this.telegramUsername,
    this.brandColor,
    required this.address,
    this.lat,
    this.lng,
    required this.workingHours,
    this.visibility = ShopVisibility.public,
  });

  final String id;
  final String name;
  final String description;
  final String? logoUrl;
  final String? coverUrl;

  /// `sellers.contact_phone` — edited in the same form, saved to the
  /// `sellers` row not `shops`.
  final String? contactPhone;
  final String? contactEmail;
  final String? telegramUsername;

  /// Hex string like `#FF5733` (with leading hash).
  final String? brandColor;

  /// Free-form address string. Until the schema gains region/city/district
  /// columns, the form stores everything as a single text line plus the
  /// map-picked lat/lng.
  final String address;
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

  /// Parses a `public.shops` row joined with the seller's contact slice.
  /// The repository passes the seller fields under fixed top-level keys
  /// (`seller_contact_phone` etc.) so this factory has no joined-row
  /// shape to disambiguate.
  factory ShopSettings.fromRow({
    required Map<String, dynamic> shopRow,
    Map<String, dynamic>? sellerRow,
  }) {
    return ShopSettings(
      id: shopRow['id'] as String? ?? '',
      name: (shopRow['name'] as String?)?.trim() ?? '',
      description: (shopRow['description'] as String?)?.trim() ?? '',
      logoUrl: shopRow['logo_url'] as String?,
      coverUrl: shopRow['cover_url'] as String?,
      contactPhone: sellerRow?['contact_phone'] as String?,
      contactEmail: sellerRow?['contact_email'] as String?,
      telegramUsername: sellerRow?['telegram_username'] as String?,
      brandColor: shopRow['brand_color'] as String?,
      address: (shopRow['address'] as String?) ?? '',
      lat: (shopRow['latitude'] as num?)?.toDouble(),
      lng: (shopRow['longitude'] as num?)?.toDouble(),
      workingHours: WeeklyHours.fromJson(
        shopRow['working_hours'] as Map<String, dynamic>?,
      ),
      visibility: _visibilityFromName(shopRow['visibility'] as String?),
    );
  }

  /// Serialises the seller-editable columns of a `shops` row. Null fields
  /// are written explicitly so clearing a value (e.g. removing a logo)
  /// persists. Contact fields are NOT included — those go to `sellers`.
  Map<String, dynamic> toShopJson() => {
        'name': name,
        'description': description,
        'logo_url': logoUrl,
        'cover_url': coverUrl,
        'brand_color': brandColor,
        'address': address,
        'latitude': lat,
        'longitude': lng,
        'working_hours': workingHours.toJson(),
        'visibility': visibility.name,
      };

  /// Contact-info slice destined for `public.sellers`.
  Map<String, dynamic> toSellerContactJson() => {
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'telegram_username': telegramUsername,
      };

  ShopSettings copyWith({
    String? name,
    String? description,
    String? logoUrl,
    String? coverUrl,
    String? contactPhone,
    String? contactEmail,
    String? telegramUsername,
    String? brandColor,
    String? address,
    double? lat,
    double? lng,
    WeeklyHours? workingHours,
    ShopVisibility? visibility,
  }) {
    return ShopSettings(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      telegramUsername: telegramUsername ?? this.telegramUsername,
      brandColor: brandColor ?? this.brandColor,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      workingHours: workingHours ?? this.workingHours,
      visibility: visibility ?? this.visibility,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        logoUrl,
        coverUrl,
        contactPhone,
        contactEmail,
        telegramUsername,
        brandColor,
        address,
        lat,
        lng,
        workingHours,
        visibility,
      ];
}

ShopVisibility _visibilityFromName(String? name) {
  return ShopVisibility.values.firstWhere(
    (v) => v.name == name,
    orElse: () => ShopVisibility.public,
  );
}

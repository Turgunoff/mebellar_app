import 'package:equatable/equatable.dart';

import 'working_hours.dart';

/// Public, customer-facing view of a seller's shop — the payload behind
/// `GET /catalog/shops/{id}`.
///
/// Deliberately separate from [Shop]: the public endpoint returns plain,
/// single-language strings (not [MultilingualText]) and carries aggregate
/// stats the seller-owned model never holds — [productCount] and the
/// [rating]/[reviewCount] averaged across every review the shop received.
class ShopProfile extends Equatable {
  const ShopProfile({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.brandColor,
    this.contactPhone,
    this.telegramUsername,
    this.isVerified = false,
    this.address,
    this.latitude,
    this.longitude,
    required this.workingHours,
    this.createdAt,
    this.productCount = 0,
    this.rating,
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;

  /// Optional `#RRGGBB` brand accent. Falls back to the customer terracotta
  /// when null/unparseable — see the screen's `_brandColor` resolver.
  final String? brandColor;
  final String? contactPhone;
  final String? telegramUsername;
  final bool isVerified;
  final String? address;
  final double? latitude;
  final double? longitude;
  final WeeklyHours workingHours;

  /// When the shop was created — surfaced as the "member since" year.
  final DateTime? createdAt;
  final int productCount;

  /// Average review score (1–5) across all of the shop's products, or null
  /// when the shop has no reviews yet.
  final double? rating;
  final int reviewCount;

  bool get hasPhone => (contactPhone ?? '').trim().isNotEmpty;
  bool get hasTelegram => (telegramUsername ?? '').trim().isNotEmpty;
  bool get hasAddress => (address ?? '').trim().isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;
  bool get hasRating => rating != null && reviewCount > 0;

  factory ShopProfile.fromJson(Map<String, dynamic> json) {
    String? str(String key) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return null;
    }

    final createdRaw = json['created_at'] as String?;
    return ShopProfile(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim() ?? '',
      description: str('description'),
      logoUrl: str('logo_url'),
      coverUrl: str('cover_url'),
      brandColor: str('brand_color'),
      contactPhone: str('contact_phone'),
      telegramUsername: str('telegram_username'),
      isVerified: json['is_verified'] as bool? ?? false,
      address: str('address'),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      workingHours: WeeklyHours.fromJson(
        json['working_hours'] as Map<String, dynamic>?,
      ),
      createdAt: createdRaw != null ? DateTime.tryParse(createdRaw) : null,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    isVerified,
    productCount,
    rating,
    reviewCount,
  ];
}

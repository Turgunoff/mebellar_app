import 'package:equatable/equatable.dart';

import 'multilingual_text.dart';

class Shop extends Equatable {
  const Shop({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.contactPhone,
    this.telegramUsername,
    this.isVerified = false,
    this.brandColor,
  });

  final String id;
  final String slug;
  final MultilingualText name;
  final MultilingualText? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? contactPhone;
  final String? telegramUsername;
  final bool isVerified;
  final String? brandColor;

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? json['id'] as String,
      name: MultilingualText.fromJson(json['name'] as Map<String, dynamic>?),
      description: MultilingualText.fromJson(
        json['description'] as Map<String, dynamic>?,
      ),
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      contactPhone: json['contact_phone'] as String?,
      telegramUsername: json['telegram_username'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      brandColor: json['brand_color'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, slug, isVerified];
}

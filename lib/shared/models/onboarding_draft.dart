import 'package:equatable/equatable.dart';

import 'business_type.dart';
import 'multilingual_text.dart';
import 'region.dart';

/// The full payload the onboarding wizard collects across its 6 steps.
/// Persisted to Hive `onboarding_draft` after every input change so the
/// user can close the app mid-flow and resume.
class OnboardingDraft extends Equatable {
  const OnboardingDraft({
    this.businessType,
    this.legalName,
    this.contactPhone,
    this.contactEmail,
    this.telegramUsername,
    this.shopNameUz,
    this.shopNameRu,
    this.shopNameEn,
    this.shopDescriptionUz,
    this.shopDescriptionRu,
    this.shopDescriptionEn,
    this.shopRegion,
    this.shopCity,
    this.shopDistrict,
    this.shopStreetLine,
    this.shopLandmark,
    this.shopLat,
    this.shopLng,
    this.verifyNow = true,
    this.lastStep = 0,
  });

  final BusinessType? businessType;
  final String? legalName;
  final String? contactPhone;
  final String? contactEmail;
  final String? telegramUsername;

  final String? shopNameUz;
  final String? shopNameRu;
  final String? shopNameEn;
  final String? shopDescriptionUz;
  final String? shopDescriptionRu;
  final String? shopDescriptionEn;
  final Region? shopRegion;
  final Region? shopCity;
  final Region? shopDistrict;
  final String? shopStreetLine;
  final String? shopLandmark;
  final double? shopLat;
  final double? shopLng;

  final bool verifyNow;
  final int lastStep;

  bool get hasShopName =>
      (shopNameUz?.isNotEmpty ?? false) ||
      (shopNameRu?.isNotEmpty ?? false) ||
      (shopNameEn?.isNotEmpty ?? false);

  MultilingualText get shopNameMl =>
      MultilingualText(uz: shopNameUz, ru: shopNameRu, en: shopNameEn);

  MultilingualText get shopDescriptionMl => MultilingualText(
    uz: shopDescriptionUz,
    ru: shopDescriptionRu,
    en: shopDescriptionEn,
  );

  OnboardingDraft copyWith({
    BusinessType? businessType,
    String? legalName,
    String? contactPhone,
    String? contactEmail,
    String? telegramUsername,
    String? shopNameUz,
    String? shopNameRu,
    String? shopNameEn,
    String? shopDescriptionUz,
    String? shopDescriptionRu,
    String? shopDescriptionEn,
    Region? shopRegion,
    Region? shopCity,
    Region? shopDistrict,
    bool clearDistrict = false,
    String? shopStreetLine,
    String? shopLandmark,
    double? shopLat,
    double? shopLng,
    bool? verifyNow,
    int? lastStep,
  }) {
    return OnboardingDraft(
      businessType: businessType ?? this.businessType,
      legalName: legalName ?? this.legalName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      telegramUsername: telegramUsername ?? this.telegramUsername,
      shopNameUz: shopNameUz ?? this.shopNameUz,
      shopNameRu: shopNameRu ?? this.shopNameRu,
      shopNameEn: shopNameEn ?? this.shopNameEn,
      shopDescriptionUz: shopDescriptionUz ?? this.shopDescriptionUz,
      shopDescriptionRu: shopDescriptionRu ?? this.shopDescriptionRu,
      shopDescriptionEn: shopDescriptionEn ?? this.shopDescriptionEn,
      shopRegion: shopRegion ?? this.shopRegion,
      shopCity: shopCity ?? this.shopCity,
      shopDistrict: clearDistrict ? null : (shopDistrict ?? this.shopDistrict),
      shopStreetLine: shopStreetLine ?? this.shopStreetLine,
      shopLandmark: shopLandmark ?? this.shopLandmark,
      shopLat: shopLat ?? this.shopLat,
      shopLng: shopLng ?? this.shopLng,
      verifyNow: verifyNow ?? this.verifyNow,
      lastStep: lastStep ?? this.lastStep,
    );
  }

  Map<String, dynamic> toJson() => {
    'business_type': businessType?.code,
    'legal_name': legalName,
    'contact_phone': contactPhone,
    'contact_email': contactEmail,
    'telegram_username': telegramUsername,
    'shop_name_uz': shopNameUz,
    'shop_name_ru': shopNameRu,
    'shop_name_en': shopNameEn,
    'shop_description_uz': shopDescriptionUz,
    'shop_description_ru': shopDescriptionRu,
    'shop_description_en': shopDescriptionEn,
    'shop_region_id': shopRegion?.id,
    'shop_city_id': shopCity?.id,
    'shop_district_id': shopDistrict?.id,
    'shop_street_line': shopStreetLine,
    'shop_landmark': shopLandmark,
    'shop_lat': shopLat,
    'shop_lng': shopLng,
    'verify_now': verifyNow,
    'last_step': lastStep,
  };

  /// Hive can store primitive maps but not nested Region objects, so the
  /// repository converts to/from `Map<String, dynamic>`. Region fields are
  /// stored by id and re-hydrated against the live region tree on read.
  factory OnboardingDraft.fromMap(
    Map<dynamic, dynamic> map, {
    Region? Function(String?)? findRegion,
  }) {
    Region? lookup(String key) {
      if (findRegion == null) return null;
      final id = map[key] as String?;
      if (id == null) return null;
      return findRegion(id);
    }

    return OnboardingDraft(
      businessType: BusinessType.fromCode(map['business_type'] as String?),
      legalName: map['legal_name'] as String?,
      contactPhone: map['contact_phone'] as String?,
      contactEmail: map['contact_email'] as String?,
      telegramUsername: map['telegram_username'] as String?,
      shopNameUz: map['shop_name_uz'] as String?,
      shopNameRu: map['shop_name_ru'] as String?,
      shopNameEn: map['shop_name_en'] as String?,
      shopDescriptionUz: map['shop_description_uz'] as String?,
      shopDescriptionRu: map['shop_description_ru'] as String?,
      shopDescriptionEn: map['shop_description_en'] as String?,
      shopRegion: lookup('shop_region_id'),
      shopCity: lookup('shop_city_id'),
      shopDistrict: lookup('shop_district_id'),
      shopStreetLine: map['shop_street_line'] as String?,
      shopLandmark: map['shop_landmark'] as String?,
      shopLat: (map['shop_lat'] as num?)?.toDouble(),
      shopLng: (map['shop_lng'] as num?)?.toDouble(),
      verifyNow: map['verify_now'] as bool? ?? true,
      lastStep: (map['last_step'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    businessType,
    legalName,
    contactPhone,
    contactEmail,
    telegramUsername,
    shopNameUz,
    shopNameRu,
    shopNameEn,
    shopDescriptionUz,
    shopDescriptionRu,
    shopDescriptionEn,
    shopRegion?.id,
    shopCity?.id,
    shopDistrict?.id,
    shopStreetLine,
    shopLandmark,
    shopLat,
    shopLng,
    verifyNow,
    lastStep,
  ];
}

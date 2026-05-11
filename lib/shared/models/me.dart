import 'business_type.dart';
import 'verification_status.dart';

class Me {
  const Me({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.preferredLanguage = 'uz',
    this.sellerProfile,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String preferredLanguage;
  final SellerProfile? sellerProfile;

  bool get hasSellerProfile => sellerProfile != null;

  Me copyWith({SellerProfile? sellerProfile}) {
    return Me(
      id: id,
      email: email,
      fullName: fullName,
      phone: phone,
      preferredLanguage: preferredLanguage,
      sellerProfile: sellerProfile ?? this.sellerProfile,
    );
  }

  factory Me.fromJson(Map<String, dynamic> json) {
    return Me(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      preferredLanguage: json['preferred_language'] as String? ?? 'uz',
      sellerProfile: json['seller_profile'] is Map<String, dynamic>
          ? SellerProfile.fromJson(json['seller_profile'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SellerProfile {
  const SellerProfile({
    required this.verificationStatus,
    this.businessType,
    this.legalName,
    this.contactPhone,
    this.contactEmail,
    this.telegramUsername,
    this.shopId,
    this.rejectionReason,
  });

  final VerificationStatus verificationStatus;
  final BusinessType? businessType;
  final String? legalName;
  final String? contactPhone;
  final String? contactEmail;
  final String? telegramUsername;
  final String? shopId;
  final String? rejectionReason;

  bool get isApproved => verificationStatus.isApproved;
  bool get isPending => verificationStatus.isPending;
  bool get isRejected => verificationStatus.isRejected;
  bool get hasShop => shopId != null;

  SellerProfile copyWith({
    VerificationStatus? verificationStatus,
    BusinessType? businessType,
    String? legalName,
    String? contactPhone,
    String? contactEmail,
    String? telegramUsername,
    String? shopId,
    String? rejectionReason,
    bool clearRejectionReason = false,
  }) {
    return SellerProfile(
      verificationStatus: verificationStatus ?? this.verificationStatus,
      businessType: businessType ?? this.businessType,
      legalName: legalName ?? this.legalName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      telegramUsername: telegramUsername ?? this.telegramUsername,
      shopId: shopId ?? this.shopId,
      rejectionReason:
          clearRejectionReason ? null : (rejectionReason ?? this.rejectionReason),
    );
  }

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      verificationStatus:
          VerificationStatus.fromCode(json['verification_status'] as String?),
      businessType: BusinessType.fromCode(json['business_type'] as String?),
      legalName: json['legal_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      telegramUsername: json['telegram_username'] as String?,
      shopId: json['shop_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}

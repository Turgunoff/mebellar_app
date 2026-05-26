import 'business_type.dart';
import 'verification_status.dart';

class Me {
  const Me({
    required this.id,
    this.phone,
    this.fullName,
    this.preferredLanguage = 'uz',
    this.avatarUrl,
    this.isSellerPending = false,
    this.role,
    this.sellerProfile,
  });

  final String id;
  final String? phone;
  final String? fullName;
  final String preferredLanguage;
  final String? avatarUrl;
  final bool isSellerPending;

  /// Backend-resolved role (`super_admin`, `manager`, or null for plain users).
  /// Recomputed server-side per request — never trust the JWT claim alone.
  final String? role;

  /// Seller surface — populated by a separate endpoint once approved. Until
  /// Phase 4 wires `/seller/me`, this stays null on every `/me` response.
  final SellerProfile? sellerProfile;

  bool get hasSellerProfile => sellerProfile != null;
  bool get hasProfile => fullName != null && fullName!.isNotEmpty;

  Me copyWith({
    String? fullName,
    String? preferredLanguage,
    String? avatarUrl,
    bool? isSellerPending,
    SellerProfile? sellerProfile,
  }) {
    return Me(
      id: id,
      phone: phone,
      fullName: fullName ?? this.fullName,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isSellerPending: isSellerPending ?? this.isSellerPending,
      role: role,
      sellerProfile: sellerProfile ?? this.sellerProfile,
    );
  }

  factory Me.fromJson(Map<String, dynamic> json) {
    return Me(
      id: json['id'] as String,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String?,
      preferredLanguage: json['preferred_language'] as String? ?? 'uz',
      avatarUrl: json['avatar_url'] as String?,
      isSellerPending: json['is_seller_pending'] as bool? ?? false,
      role: json['role'] as String?,
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

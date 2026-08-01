import 'business_type.dart';
import 'verification_status.dart';

class Me {
  const Me({
    required this.id,
    this.phone,
    this.fullName,
    this.email,
    this.preferredLanguage = 'uz',
    this.avatarUrl,
    this.isSellerPending = false,
    this.role,
    this.promoPushEnabled = true,
    this.orderPushEnabled = true,
    this.sellerProfile,
  });

  final String id;
  final String? phone;
  final String? fullName;
  final String? email;
  final String preferredLanguage;
  final String? avatarUrl;
  final bool isSellerPending;

  /// Backend-resolved role (`super_admin`, `manager`, or null for plain users).
  /// Recomputed server-side per request — never trust the JWT claim alone.
  final String? role;

  /// Marketing / news FCM topic preference (`profiles.promo_push_enabled`).
  final bool promoPushEnabled;

  /// Transactional order-update FCM preference (`profiles.order_push_enabled`).
  /// When false the backend still writes the in-app inbox row but skips the
  /// OS-level push.
  final bool orderPushEnabled;

  /// Seller surface — populated by a separate endpoint once approved. Until
  /// Phase 4 wires `/seller/me`, this stays null on every `/me` response.
  final SellerProfile? sellerProfile;

  bool get hasSellerProfile => sellerProfile != null;
  bool get hasProfile => fullName != null && fullName!.isNotEmpty;

  Me copyWith({
    String? fullName,
    String? email,
    String? preferredLanguage,
    String? avatarUrl,
    bool? isSellerPending,
    bool? promoPushEnabled,
    bool? orderPushEnabled,
    SellerProfile? sellerProfile,
  }) {
    return Me(
      id: id,
      phone: phone,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isSellerPending: isSellerPending ?? this.isSellerPending,
      role: role,
      promoPushEnabled: promoPushEnabled ?? this.promoPushEnabled,
      orderPushEnabled: orderPushEnabled ?? this.orderPushEnabled,
      sellerProfile: sellerProfile ?? this.sellerProfile,
    );
  }

  factory Me.fromJson(Map<String, dynamic> json) {
    return Me(
      id: json['id'] as String,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      preferredLanguage: json['preferred_language'] as String? ?? 'uz',
      avatarUrl: json['avatar_url'] as String?,
      isSellerPending: json['is_seller_pending'] as bool? ?? false,
      role: json['role'] as String?,
      promoPushEnabled: json['promo_push_enabled'] as bool? ?? true,
      orderPushEnabled: json['order_push_enabled'] as bool? ?? true,
      sellerProfile: json['seller_profile'] is Map<String, dynamic>
          ? SellerProfile.fromJson(
              json['seller_profile'] as Map<String, dynamic>,
            )
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
    this.bonusScreenSeen = false,
    this.rejectionAlertDismissed = false,
  });

  final VerificationStatus verificationStatus;
  final BusinessType? businessType;
  final String? legalName;
  final String? contactPhone;
  final String? contactEmail;
  final String? telegramUsername;
  final String? shopId;
  final String? rejectionReason;

  /// Account-lifecycle UI flags resolved server-side (backed by the `sellers`
  /// row, not local Hive — so they survive reinstall / device change).
  /// [bonusScreenSeen] gates the one-time approval-bonus celebration;
  /// [rejectionAlertDismissed] keeps a closed "Ariza rad etildi" banner closed.
  final bool bonusScreenSeen;
  final bool rejectionAlertDismissed;

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
    bool? bonusScreenSeen,
    bool? rejectionAlertDismissed,
  }) {
    return SellerProfile(
      verificationStatus: verificationStatus ?? this.verificationStatus,
      businessType: businessType ?? this.businessType,
      legalName: legalName ?? this.legalName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      telegramUsername: telegramUsername ?? this.telegramUsername,
      shopId: shopId ?? this.shopId,
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      bonusScreenSeen: bonusScreenSeen ?? this.bonusScreenSeen,
      rejectionAlertDismissed:
          rejectionAlertDismissed ?? this.rejectionAlertDismissed,
    );
  }

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      verificationStatus: VerificationStatus.fromCode(
        json['verification_status'] as String?,
      ),
      businessType: BusinessType.fromCode(json['business_type'] as String?),
      legalName: json['legal_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      telegramUsername: json['telegram_username'] as String?,
      shopId: json['shop_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      bonusScreenSeen: json['bonus_screen_seen'] as bool? ?? false,
      rejectionAlertDismissed:
          json['rejection_alert_dismissed'] as bool? ?? false,
    );
  }
}

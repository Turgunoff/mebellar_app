import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_type.dart';
import '../models/onboarding_draft.dart';
import '../models/verification_status.dart';
import 'seller_onboarding_repository.dart';

/// Real Supabase implementation of [SellerOnboardingRepository].
///
/// All seller/shop writes go through the `submit_seller_onboarding(payload jsonb)`
/// RPC — the function is SECURITY DEFINER and owns the multi-table upsert
/// (sellers + shops + profiles.is_seller_pending), so the client only needs
/// to upload the passport images and forward their storage paths in the
/// payload. The previous direct `.insert()` / `.upsert()` against `shops`
/// broke because the live schema is flat (`name`, `description`, `address`)
/// rather than the legacy multilingual + region tree the client was sending.
class SupabaseSellerOnboardingRepository implements SellerOnboardingRepository {
  SupabaseSellerOnboardingRepository({
    required SupabaseClient supabase,
    required Box draftBox,
  }) : _supabase = supabase,
       _draftBox = draftBox;

  final SupabaseClient _supabase;
  final Box _draftBox;
  static const _draftKey = 'draft';
  static const _documentsBucket = 'seller-documents';
  static const _submitRpc = 'submit_seller_onboarding';

  @override
  OnboardingDraft loadDraft() {
    final raw = _draftBox.get(_draftKey);
    if (raw is Map) return OnboardingDraft.fromMap(raw);
    return const OnboardingDraft();
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) =>
      _draftBox.put(_draftKey, draft.toJson());

  @override
  Future<void> clearDraft() => _draftBox.delete(_draftKey);

  /// Pull the user's existing seller + shop rows back into an
  /// [OnboardingDraft]. Used for resubmit-after-rejection so the wizard
  /// arrives pre-filled with what the moderator already saw. Region/city/
  /// district are intentionally left null — the live `shops` schema is flat
  /// (`address` text) and doesn't store the structured tree the wizard
  /// originally collected. The user can adjust the street + map pin again
  /// if needed; the address text we put back into `shopStreetLine` is what
  /// they (or the geocoder) entered last time.
  @override
  Future<OnboardingDraft?> loadRemoteDraft() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final sellerFuture = _supabase
        .from('sellers')
        .select(
          'business_type, legal_name, contact_phone, contact_email, '
          'telegram_username',
        )
        .eq('id', userId)
        .maybeSingle();
    final shopFuture = _supabase
        .from('shops')
        .select('name, description, address, latitude, longitude')
        .eq('seller_id', userId)
        .maybeSingle();

    final results = await Future.wait<dynamic>([sellerFuture, shopFuture]);
    final seller = results[0] as Map<String, dynamic>?;
    final shop = results[1] as Map<String, dynamic>?;

    // Nothing to hydrate — first-time onboarding.
    if (seller == null && shop == null) return null;

    // Mirror the RPC's flatten-by-coalesce: store the single name/description
    // into the UZ slot so the wizard's existing UZ-first inputs show it.
    return OnboardingDraft(
      businessType: BusinessType.fromCode(seller?['business_type'] as String?),
      legalName: seller?['legal_name'] as String?,
      contactPhone: seller?['contact_phone'] as String?,
      contactEmail: seller?['contact_email'] as String?,
      telegramUsername: seller?['telegram_username'] as String?,
      shopNameUz: shop?['name'] as String?,
      shopDescriptionUz: shop?['description'] as String?,
      shopStreetLine: shop?['address'] as String?,
      shopLat: (shop?['latitude'] as num?)?.toDouble(),
      shopLng: (shop?['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  Future<OnboardingSubmissionResult> submit(
    OnboardingDraft draft, {
    String? passportFrontPath,
    String? passportBackPath,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User not authenticated');

    // Upload first so a storage failure aborts the whole submission rather
    // than leaving a DB row that points at a missing image. RLS on the
    // `seller-documents` bucket requires `{auth.uid()}/...` as the first
    // path segment, hence `$userId/...`.
    final frontStoragePath = passportFrontPath == null
        ? null
        : await _uploadDocument(
            userId: userId,
            objectName: 'passport_front',
            localPath: passportFrontPath,
          );
    final backStoragePath = passportBackPath == null
        ? null
        : await _uploadDocument(
            userId: userId,
            objectName: 'passport_back',
            localPath: passportBackPath,
          );

    // Build the JSONB payload the RPC consumes. Keys mirror the columns
    // `submit_seller_onboarding` reads via `payload->>'<key>'`. Empty
    // values are passed as `null` so the RPC's `NULLIF` keeps existing
    // values during a resubmit. Region/city/district aren't sent — the
    // current shop schema doesn't carry them.
    final payload = <String, dynamic>{
      'business_type': draft.businessType?.code,
      'legal_name': draft.legalName,
      'contact_phone': draft.contactPhone,
      'contact_email': draft.contactEmail,
      'telegram_username': draft.telegramUsername,
      'shop_name': _firstNonEmpty([
        draft.shopNameUz,
        draft.shopNameRu,
        draft.shopNameEn,
      ]),
      'shop_description': _firstNonEmpty([
        draft.shopDescriptionUz,
        draft.shopDescriptionRu,
        draft.shopDescriptionEn,
      ]),
      'shop_address': _composeAddress(
        streetLine: draft.shopStreetLine,
        landmark: draft.shopLandmark,
      ),
      'shop_lat': draft.shopLat?.toString(),
      'shop_lng': draft.shopLng?.toString(),
      'passport_front_path': frontStoragePath,
      'passport_back_path': backStoragePath,
    };

    final raw = await _supabase.rpc(
      _submitRpc,
      params: {'payload': payload},
    );

    if (raw is! Map) {
      throw StateError(
        'Unexpected response from $_submitRpc: ${raw.runtimeType}',
      );
    }
    final result = Map<String, dynamic>.from(raw);

    final shopId = result['shop_id'] as String?;
    final sellerProfileId = result['seller_profile_id'] as String? ?? userId;
    if (shopId == null) {
      throw StateError('$_submitRpc returned no shop_id');
    }

    return OnboardingSubmissionResult(
      sellerProfileId: sellerProfileId,
      shopId: shopId,
      verificationStatus: VerificationStatus.fromCode(
        result['verification_status'] as String?,
      ),
    );
  }

  /// Uploads to `{userId}/{objectName}.{ext}` with `upsert=true` so retries
  /// overwrite rather than accumulating orphan files. Bucket is private; the
  /// returned value is the storage path — clients fetch via signed URLs.
  Future<String> _uploadDocument({
    required String userId,
    required String objectName,
    required String localPath,
  }) async {
    final extension = _extensionOf(localPath);
    final objectPath = '$userId/$objectName.$extension';

    await _supabase.storage
        .from(_documentsBucket)
        .upload(
          objectPath,
          File(localPath),
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeFor(extension),
            cacheControl: '3600',
          ),
        );

    return objectPath;
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// Combine the structured address into the single `shops.address` column the
  /// live schema exposes. Landmark is appended in parens so the reviewer
  /// still sees it, since the schema dropped landmark/region columns.
  static String? _composeAddress({String? streetLine, String? landmark}) {
    final street = streetLine?.trim();
    final mark = landmark?.trim();
    final hasStreet = street != null && street.isNotEmpty;
    final hasMark = mark != null && mark.isNotEmpty;
    if (hasStreet && hasMark) return '$street ($mark)';
    if (hasStreet) return street;
    if (hasMark) return mark;
    return null;
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  String _contentTypeFor(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}

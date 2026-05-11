import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_draft.dart';
import '../models/region.dart';
import '../models/verification_status.dart';

/// Submission payload returned from `POST /seller/onboarding`. Mock variant
/// fills it with synthetic ids; real backend will mirror the same shape.
class OnboardingSubmissionResult {
  const OnboardingSubmissionResult({
    required this.sellerProfileId,
    required this.shopId,
    required this.verificationStatus,
  });

  final String sellerProfileId;
  final String shopId;
  final VerificationStatus verificationStatus;
}

abstract class SellerOnboardingRepository {
  /// Read the draft from local persistence. Returns an empty [OnboardingDraft]
  /// when the user has never started the wizard.
  OnboardingDraft loadDraft();

  /// Persist the draft after every meaningful change so the user can resume
  /// after closing the app mid-flow.
  Future<void> saveDraft(OnboardingDraft draft);

  /// Wipe the draft once the form has been submitted successfully.
  Future<void> clearDraft();

  Future<OnboardingSubmissionResult> submit(OnboardingDraft draft);
}

/// Real backend stub. Sprint 6 will wire it once the endpoints are live.
class RemoteSellerOnboardingRepository implements SellerOnboardingRepository {
  RemoteSellerOnboardingRepository({
    required Dio dio,
    required Box draftBox,
    required this.findRegionById,
    this.supabase,
  }) : _dio = dio,
       _draftBox = draftBox;

  final Dio _dio;
  final Box _draftBox;
  final Region? Function(String id) findRegionById;
  final SupabaseClient? supabase;

  static const _draftKey = 'draft';

  @override
  OnboardingDraft loadDraft() {
    final raw = _draftBox.get(_draftKey);
    if (raw is Map) {
      return OnboardingDraft.fromMap(
        raw,
        findRegion: (id) => id == null ? null : findRegionById(id),
      );
    }
    return const OnboardingDraft();
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    await _draftBox.put(_draftKey, draft.toJson());
  }

  @override
  Future<void> clearDraft() async {
    await _draftBox.delete(_draftKey);
  }

  @override
  Future<OnboardingSubmissionResult> submit(OnboardingDraft draft) async {
    // If Supabase is available, use it. Otherwise fall back to HTTP.
    if (supabase != null && supabase!.auth.currentUser != null) {
      return _submitToSupabase(draft, supabase!);
    }

    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/seller/onboarding',
      data: draft.toJson(),
    );
    final data = res.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Onboarding submit: unexpected response');
    }
    return OnboardingSubmissionResult(
      sellerProfileId: data['seller_profile_id'] as String,
      shopId: data['shop_id'] as String,
      verificationStatus: VerificationStatus.fromCode(
        data['verification_status'] as String?,
      ),
    );
  }

  Future<OnboardingSubmissionResult> _submitToSupabase(
    OnboardingDraft draft,
    SupabaseClient client,
  ) async {
    final userId = client.auth.currentUser!.id;

    // Insert into shops table
    final shopResponse = await client.from('shops').insert({
      'user_id': userId,
      'name_uz': draft.shopNameUz,
      'name_ru': draft.shopNameRu,
      'name_en': draft.shopNameEn,
      'description_uz': draft.shopDescriptionUz,
      'description_ru': draft.shopDescriptionRu,
      'description_en': draft.shopDescriptionEn,
      'street_line': draft.shopStreetLine,
      'landmark': draft.shopLandmark,
      'region_id': draft.shopRegion?.id,
      'city_id': draft.shopCity?.id,
      'district_id': draft.shopDistrict?.id,
      'latitude': draft.shopLat,
      'longitude': draft.shopLng,
      'status': 'pending_documents', // Initial KYC status
    }).select();

    if (shopResponse.isEmpty) {
      throw StateError('Failed to insert shop into Supabase');
    }

    final shopId = shopResponse[0]['id'] as String;

    // Insert into seller_profiles table
    final profileResponse = await client.from('seller_profiles').insert({
      'user_id': userId,
      'shop_id': shopId,
      'legal_name': draft.legalName,
      'contact_phone': draft.contactPhone,
      'contact_email': draft.contactEmail,
      'telegram_username': draft.telegramUsername,
      'business_type': draft.businessType?.code,
      'verification_status':
          'pending', // Can be 'pending', 'verified', 'rejected'
    }).select();

    if (profileResponse.isEmpty) {
      throw StateError('Failed to insert seller_profile into Supabase');
    }

    final profileId = profileResponse[0]['id'] as String;

    return OnboardingSubmissionResult(
      sellerProfileId: profileId,
      shopId: shopId,
      verificationStatus: VerificationStatus.pending,
    );
  }
}

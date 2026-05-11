import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_draft.dart';
import '../models/verification_status.dart';
import 'seller_onboarding_repository.dart';

class SupabaseSellerOnboardingRepository implements SellerOnboardingRepository {
  SupabaseSellerOnboardingRepository({
    required SupabaseClient supabase,
    required Box draftBox,
  }) : _supabase = supabase,
       _draftBox = draftBox;

  final SupabaseClient _supabase;
  final Box _draftBox;
  static const _draftKey = 'draft';

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

  @override
  Future<OnboardingSubmissionResult> submit(OnboardingDraft draft) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User not authenticated');

    // 1. Upsert seller profile — idempotent for re-submissions.
    await _supabase.from('sellers').upsert({
      'id': userId,
      'business_type': draft.businessType?.code,
      'legal_name': draft.legalName,
      'contact_phone': draft.contactPhone,
      'contact_email': draft.contactEmail,
      'telegram_username': draft.telegramUsername,
      'verification_status': 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 2. Upsert shop with full details (seller_id is UNIQUE so conflict = update).
    final shopRes = await _supabase
        .from('shops')
        .upsert({
          'seller_id': userId,
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
          'status': 'pending_documents', // KYC status for document upload phase
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'seller_id')
        .select('id')
        .single();

    final shopId = shopRes['id'] as String;

    // 3. Mark profile so the customer UI shows "pending" banner immediately.
    await _supabase
        .from('profiles')
        .update({
          'is_seller_pending': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);

    return OnboardingSubmissionResult(
      sellerProfileId: userId,
      shopId: shopId,
      verificationStatus: VerificationStatus.pending,
    );
  }
}

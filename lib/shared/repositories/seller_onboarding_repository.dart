import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

  /// Hydrate an [OnboardingDraft] from the user's existing sellers + shops
  /// rows. Used for the resubmit-after-rejection flow so the wizard isn't
  /// blank when the user taps "Edit application". Returns `null` when no
  /// remote record exists (first-time onboarding) or when the user isn't
  /// authenticated, in which case the caller should fall back to
  /// [loadDraft].
  Future<OnboardingDraft?> loadRemoteDraft();

  /// Persist the draft after every meaningful change so the user can resume
  /// after closing the app mid-flow.
  Future<void> saveDraft(OnboardingDraft draft);

  /// Wipe the draft once the form has been submitted successfully.
  Future<void> clearDraft();

  /// Submit the completed onboarding form. When [passportFrontPath] and/or
  /// [passportBackPath] are provided, the implementation is expected to upload
  /// those files to storage and persist their paths alongside the rest of the
  /// onboarding data. Paths are local filesystem paths from the image picker.
  Future<OnboardingSubmissionResult> submit(
    OnboardingDraft draft, {
    String? passportFrontPath,
    String? passportBackPath,
  });
}

/// Real backend stub. Sprint 6 will wire it once the endpoints are live.
class RemoteSellerOnboardingRepository implements SellerOnboardingRepository {
  RemoteSellerOnboardingRepository({
    required Dio dio,
    required Box draftBox,
    required this.findRegionById,
  }) : _dio = dio,
       _draftBox = draftBox;

  final Dio _dio;
  final Box _draftBox;
  final Region? Function(String id) findRegionById;

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

  /// Stub class — Sprint 6 will replace it once the HTTP backend is live.
  /// No remote draft hydration is possible without a finalised contract, so
  /// callers should fall back to [loadDraft].
  @override
  Future<OnboardingDraft?> loadRemoteDraft() async => null;

  @override
  Future<OnboardingSubmissionResult> submit(
    OnboardingDraft draft, {
    String? passportFrontPath,
    String? passportBackPath,
  }) async {
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
}

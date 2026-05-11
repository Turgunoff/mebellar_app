import 'package:hive_flutter/hive_flutter.dart';

import '../models/onboarding_draft.dart';
import '../models/region.dart';
import '../models/verification_status.dart';
import '../repositories/seller_onboarding_repository.dart';
import 'mock_seller_state.dart';

class MockSellerOnboardingRepository implements SellerOnboardingRepository {
  MockSellerOnboardingRepository({
    required Box draftBox,
    required this.findRegionById,
  }) : _draftBox = draftBox;

  final Box _draftBox;
  final Region? Function(String id) findRegionById;

  static const _draftKey = 'draft';
  static const _delay = Duration(milliseconds: 350);

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

  /// Mock submit: persists the form into [MockSellerState] so subsequent
  /// `fetchMe()` calls (and the seller dashboard) can see the new pending
  /// profile. Returns synthetic ids that look believable.
  @override
  Future<OnboardingSubmissionResult> submit(OnboardingDraft draft) async {
    await Future<void>.delayed(_delay);
    final initialStatus = draft.verifyNow
        ? VerificationStatus.pending
        : VerificationStatus.none;
    MockSellerState.instance.recordOnboarding(
      draft: draft,
      initialStatus: initialStatus,
    );
    return OnboardingSubmissionResult(
      sellerProfileId: 'sp-mock-${DateTime.now().millisecondsSinceEpoch}',
      shopId: MockSellerState.instance.shopId!,
      verificationStatus: initialStatus,
    );
  }
}

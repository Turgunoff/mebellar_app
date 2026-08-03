import '../models/onboarding_draft.dart';
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
    String? contractVersion,
  });
}

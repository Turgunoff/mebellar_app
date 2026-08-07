import '../../core/result/result.dart';
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

/// Seller onboarding — money/verification command surface (T-10 `Result<T>`
/// migration). Every method is `Result`-typed for boundary-test homogeneity,
/// including the two local-Hive draft methods ([loadDraft]/[saveDraft]),
/// which in practice never fail (a corrupt draft degrades to an empty one
/// rather than throwing) but must not be the odd `throw`-typed member out in
/// an otherwise-`Result` file.
abstract class SellerOnboardingRepository {
  /// Read the draft from local persistence. `Ok` wraps an empty
  /// [OnboardingDraft] when the user has never started the wizard.
  Result<OnboardingDraft> loadDraft();

  /// Hydrate an [OnboardingDraft] from the user's existing sellers + shops
  /// rows. Used for the resubmit-after-rejection flow so the wizard isn't
  /// blank when the user taps "Edit application". `Ok(null)` covers BOTH "no
  /// remote record exists yet" (first-time onboarding) and "request failed"
  /// (network/auth/parse) — the caller falls back to [loadDraft] either way,
  /// so this never needs to distinguish the two to behave correctly.
  Future<Result<OnboardingDraft?>> loadRemoteDraft();

  /// Persist the draft after every meaningful change so the user can resume
  /// after closing the app mid-flow.
  Future<Result<void>> saveDraft(OnboardingDraft draft);

  /// Wipe the draft once the form has been submitted successfully.
  Future<Result<void>> clearDraft();

  /// Submit the completed onboarding form. When [passportFrontPath] and/or
  /// [passportBackPath] are provided, the implementation is expected to upload
  /// those files to storage and persist their paths alongside the rest of the
  /// onboarding data. Paths are local filesystem paths from the image picker.
  /// A money/verification command — returns `Err` (never throws) on failure.
  Future<Result<OnboardingSubmissionResult>> submit(
    OnboardingDraft draft, {
    String? passportFrontPath,
    String? passportBackPath,
    String? contractVersion,
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/seller/features/onboarding/bloc/onboarding_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_regions.dart';
import '../../../../fixtures/mocks/mock/mock_seller_onboarding_repository.dart';
import '../../../../fixtures/mocks/mock/mock_seller_state.dart';
import 'package:woody_app/shared/models/business_type.dart';
import 'package:woody_app/shared/models/onboarding_draft.dart';
import 'package:woody_app/shared/models/verification_status.dart';
import 'package:woody_app/shared/repositories/seller_onboarding_repository.dart';

class _MockOnboardingRepo extends Mock implements SellerOnboardingRepository {}

void main() {
  late Box draftBox;

  setUpAll(() async {
    Hive.init('./test/.hive');
    registerFallbackValue(const OnboardingDraft());
  });

  setUp(() async {
    draftBox = await Hive.openBox(
      'test_onboarding_draft_${DateTime.now().millisecondsSinceEpoch}',
    );
    MockSellerState.instance.resetForTests();
  });

  tearDown(() async {
    await draftBox.clear();
    await draftBox.close();
  });

  MockSellerOnboardingRepository newRepo() => MockSellerOnboardingRepository(
    draftBox: draftBox,
    findRegionById: MockRegions.findById,
  );

  // `OnboardingState.canAdvance` blocks the businessType step on a null
  // value — a pure state-level guard, independent of the bloc/repo. Only
  // individual is pickable via the UI (see business_type_step.dart) and
  // `_onStarted` below always coerces to individual, so this path isn't
  // reachable through the wizard anymore; it still guards the very first
  // frame (before `OnboardingStarted` fires) and any future business type
  // that isn't pre-selected, so it stays covered directly.
  test('canAdvance blocks the businessType step when no type is set', () {
    const state = OnboardingState(step: OnboardingStep.businessType);
    expect(state.draft.businessType, isNull);
    expect(state.canAdvance, isFalse);
  });

  group('OnboardingBloc (mock repository)', () {
    blocTest<OnboardingBloc, OnboardingState>(
      'started -> draft loaded, defaults to welcome step',
      build: () => OnboardingBloc(newRepo()),
      act: (bloc) => bloc.add(const OnboardingStarted()),
      verify: (bloc) {
        expect(bloc.state.step, OnboardingStep.welcome);
        // _onStarted coerces a missing/non-individual businessType to
        // individual (onboarding_bloc.dart) — resubmit-after-rejection drafts
        // used to hydrate with a null business_type, which left
        // DocumentUploadStep with an empty requirements list. Only individual
        // is pickable at launch (business_type_step.dart), so this is the
        // only value a fresh draft can ever carry.
        expect(bloc.state.draft.businessType, BusinessType.individual);
      },
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'businessType is pre-filled to individual and immediately advanceable '
      'after start',
      build: () => OnboardingBloc(newRepo()),
      act: (bloc) async {
        bloc.add(const OnboardingStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OnboardingNextStep()); // welcome -> businessType
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OnboardingNextStep()); // businessType -> personalInfo
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingStep.personalInfo);
        expect(bloc.state.draft.businessType, BusinessType.individual);
      },
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'choosing business type unblocks the wizard',
      build: () => OnboardingBloc(newRepo()),
      act: (bloc) async {
        bloc.add(const OnboardingStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OnboardingNextStep()); // -> businessType
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OnboardingBusinessTypeChanged(BusinessType.individual));
      },
      verify: (bloc) {
        expect(bloc.state.draft.businessType, BusinessType.individual);
        expect(bloc.state.canAdvance, isTrue);
      },
    );
  });

  // T-10: submit() is now Result<T> — these pin the .fold() boundary in
  // _onSubmitted (repo mocked via mocktail so both arms are reachable, unlike
  // MockSellerOnboardingRepository which always succeeds).
  group('OnboardingBloc submit (Result<T> boundary, T-10)', () {
    late _MockOnboardingRepo repo;

    setUp(() {
      repo = _MockOnboardingRepo();
      when(() => repo.clearDraft()).thenAnswer((_) async => const Ok(null));
      // OnboardingBloc.close() flushes a best-effort saveDraft on disposal.
      when(() => repo.saveDraft(any())).thenAnswer((_) async => const Ok(null));
    });

    blocTest<OnboardingBloc, OnboardingState>(
      'Ok submission -> submitted status, clears the draft',
      build: () {
        when(() => repo.submit(
              any(),
              passportFrontPath: any(named: 'passportFrontPath'),
              passportBackPath: any(named: 'passportBackPath'),
              contractVersion: any(named: 'contractVersion'),
            )).thenAnswer(
          (_) async => const Ok(
            OnboardingSubmissionResult(
              sellerProfileId: 'sp-1',
              shopId: 'shop-1',
              verificationStatus: VerificationStatus.pending,
            ),
          ),
        );
        return OnboardingBloc(repo);
      },
      seed: () => const OnboardingState(step: OnboardingStep.contract),
      act: (bloc) => bloc.add(const OnboardingSubmitted(contractVersion: '1.1')),
      expect: () => [
        const OnboardingState(
          status: OnboardingStatus.submitting,
          step: OnboardingStep.contract,
        ),
        const OnboardingState(
          status: OnboardingStatus.submitted,
          step: OnboardingStep.done,
          resultStatus: VerificationStatus.pending,
          shopId: 'shop-1',
        ),
      ],
      verify: (_) => verify(() => repo.clearDraft()).called(1),
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'Err submission -> failure status carries Failure.message, draft NOT cleared',
      build: () {
        when(() => repo.submit(
              any(),
              passportFrontPath: any(named: 'passportFrontPath'),
              passportBackPath: any(named: 'passportBackPath'),
              contractVersion: any(named: 'contractVersion'),
            )).thenAnswer(
          (_) async => const Err(ServerFailure(message: 'Server xatoligi')),
        );
        return OnboardingBloc(repo);
      },
      seed: () => const OnboardingState(step: OnboardingStep.contract),
      act: (bloc) => bloc.add(const OnboardingSubmitted(contractVersion: '1.1')),
      expect: () => [
        const OnboardingState(
          status: OnboardingStatus.submitting,
          step: OnboardingStep.contract,
        ),
        const OnboardingState(
          status: OnboardingStatus.failure,
          step: OnboardingStep.contract,
          error: 'Server xatoligi',
        ),
      ],
      verify: (_) => verifyNever(() => repo.clearDraft()),
    );
  });
}

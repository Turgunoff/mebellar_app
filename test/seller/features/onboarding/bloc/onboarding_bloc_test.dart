import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:woody_app/seller/features/onboarding/bloc/onboarding_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_regions.dart';
import '../../../../fixtures/mocks/mock/mock_seller_onboarding_repository.dart';
import '../../../../fixtures/mocks/mock/mock_seller_state.dart';
import 'package:woody_app/shared/models/business_type.dart';

void main() {
  late Box draftBox;

  setUpAll(() async {
    Hive.init('./test/.hive');
  });

  setUp(() async {
    draftBox = await Hive.openBox('test_onboarding_draft_${DateTime.now().millisecondsSinceEpoch}');
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

  group('OnboardingBloc (mock repository)', () {
    blocTest<OnboardingBloc, OnboardingState>(
      'started -> draft loaded, defaults to welcome step',
      build: () => OnboardingBloc(newRepo()),
      act: (bloc) => bloc.add(const OnboardingStarted()),
      verify: (bloc) {
        expect(bloc.state.step, OnboardingStep.welcome);
        expect(bloc.state.draft.businessType, isNull);
      },
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'business type missing blocks advance from businessType step',
      build: () => OnboardingBloc(newRepo()),
      act: (bloc) async {
        bloc.add(const OnboardingStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OnboardingNextStep()); // welcome -> businessType
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const OnboardingNextStep()); // blocked
      },
      verify: (bloc) {
        expect(bloc.state.step, OnboardingStep.businessType);
        expect(bloc.state.canAdvance, isFalse);
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
}

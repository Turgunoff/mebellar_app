import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/verification/bloc/verification_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_seller_state.dart';
import '../../../../fixtures/mocks/mock/mock_seller_verification_repository.dart';
import 'package:woody_app/shared/models/business_type.dart';
import 'package:woody_app/shared/models/onboarding_draft.dart';
import 'package:woody_app/shared/models/verification_document.dart';
import 'package:woody_app/shared/models/verification_status.dart';

/// We don't need a real file on disk — `MockSellerVerificationRepository`
/// only stashes the path. A non-existent path is fine for state assertions.
File _fakeFile(String suffix) => File('./test/.fake/$suffix.jpg');

void main() {
  setUp(() => MockSellerState.instance.resetForTests());

  group('VerificationBloc (mock repository)', () {
    blocTest<VerificationBloc, VerificationState>(
      'individual seller requires only the 3 personal docs',
      build: () => VerificationBloc(MockSellerVerificationRepository()),
      act: (bloc) => bloc.add(const VerificationRequested(
        businessType: BusinessType.individual,
        status: VerificationStatus.none,
      )),
      verify: (bloc) {
        expect(bloc.state.requiredDocuments.length, 3);
        expect(bloc.state.requiredDocuments,
            contains(VerificationDocumentType.passportFront));
        expect(bloc.state.requiredDocuments,
            isNot(contains(VerificationDocumentType.taxId)));
      },
    );

    blocTest<VerificationBloc, VerificationState>(
      'LLC seller picks up 2 extra business docs',
      build: () => VerificationBloc(MockSellerVerificationRepository()),
      act: (bloc) => bloc.add(const VerificationRequested(
        businessType: BusinessType.llc,
        status: VerificationStatus.none,
      )),
      verify: (bloc) {
        expect(bloc.state.requiredDocuments.length, 5);
        expect(bloc.state.requiredDocuments,
            contains(VerificationDocumentType.businessCertificate));
        expect(bloc.state.requiredDocuments,
            contains(VerificationDocumentType.taxId));
      },
    );

    blocTest<VerificationBloc, VerificationState>(
      'submit transitions status none -> pending',
      build: () => VerificationBloc(MockSellerVerificationRepository()),
      act: (bloc) async {
        bloc.add(const VerificationRequested(
          businessType: BusinessType.individual,
          status: VerificationStatus.none,
        ));
        for (final type in [
          VerificationDocumentType.passportFront,
          VerificationDocumentType.passportBack,
          VerificationDocumentType.selfieWithPassport,
        ]) {
          bloc.add(VerificationDocumentUploadStarted(
            type: type,
            file: _fakeFile(type.code),
            fileExtension: 'jpg',
          ));
          // Allow the mock 600ms upload to complete.
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
        // Seed the seller state so submit() finds a profile to mutate.
        MockSellerState.instance.recordOnboarding(
          draft: const OnboardingDraft(
            businessType: BusinessType.individual,
            legalName: 'Test',
          ),
          initialStatus: VerificationStatus.none,
        );
        bloc.add(const VerificationSubmitted());
        await Future<void>.delayed(const Duration(milliseconds: 800));
      },
      verify: (bloc) {
        expect(bloc.state.flowStatus, VerificationFlowStatus.submitted);
        expect(bloc.state.status, VerificationStatus.pending);
      },
    );
  });
}


import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';

import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/shared/models/verification_document.dart';
import 'package:woody_app/shared/models/verification_status.dart';
import 'package:woody_app/shared/repositories/seller_verification_repository.dart';
import 'mock_seller_state.dart';

class MockSellerVerificationRepository
    implements SellerVerificationRepository {
  MockSellerVerificationRepository();

  static const _uploadDelay = Duration(milliseconds: 600);
  static const _submitDelay = Duration(milliseconds: 700);

  @override
  List<VerificationDocument> get documents =>
      MockSellerState.instance.documents;

  @override
  Stream<List<VerificationDocument>> watchDocuments() =>
      MockSellerState.instance.documentsStream;

  /// Pretend to upload to Supabase Storage. We persist the local file path
  /// as the synthetic `remoteUrl` so the verification screen can preview the
  /// image without ever touching the network.
  @override
  Future<Result<VerificationDocument>> uploadDocument({
    required VerificationDocumentType type,
    required File file,
    required String fileExtension,
  }) async {
    // Mark as uploading so the UI can show a per-tile progress overlay.
    MockSellerState.instance.upsertDocument(VerificationDocument(
      type: type,
      localPath: file.path,
      uploading: true,
    ));
    await Future<void>.delayed(_uploadDelay);
    final ts = clock.now().millisecondsSinceEpoch;
    final fakeUrl = 'verification/${type.code}-$ts.$fileExtension';
    final updated = VerificationDocument(
      type: type,
      localPath: file.path,
      remoteUrl: fakeUrl,
    );
    MockSellerState.instance.upsertDocument(updated);
    return Ok(updated);
  }

  @override
  Future<Result<void>> removeDocument(VerificationDocumentType type) async {
    MockSellerState.instance.removeDocument(type);
    return const Ok<void>(null);
  }

  @override
  Future<Result<VerificationStatus>> submit() async {
    await Future<void>.delayed(_submitDelay);
    MockSellerState.instance.setStatus(VerificationStatus.pending);
    // Simulate the admin moving the case to "in_review" after a short delay
    // so testers can see the banner transition without manual intervention.
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (MockSellerState.instance.profile?.verificationStatus ==
          VerificationStatus.pending) {
        MockSellerState.instance.setStatus(VerificationStatus.inReview);
      }
    });
    return Ok(VerificationStatus.pending);
  }

  @override
  Stream<VerificationStatus> watchStatus() =>
      MockSellerState.instance.profileStream
          .map((p) => p?.verificationStatus ?? VerificationStatus.none);
}

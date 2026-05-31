import 'dart:io';

import '../../core/result/result.dart';
import '../models/verification_document.dart';
import '../models/verification_status.dart';

/// Seller KYC verification — document upload + status polling.
///
/// ROADMAP B.1 — migrated to the `Result<T, Failure>` contract. The two
/// realtime-ish feeds ([watchDocuments], [watchStatus]) stay plain `Stream`s.
abstract class SellerVerificationRepository {
  /// Current set of documents for the seller — uploaded or in-flight.
  Stream<List<VerificationDocument>> watchDocuments();
  List<VerificationDocument> get documents;

  /// Uploads a single document to the private `verification-docs` bucket.
  /// Resolves to the document with its storage path populated.
  Future<Result<VerificationDocument>> uploadDocument({
    required VerificationDocumentType type,
    required File file,
    required String fileExtension,
  });

  Future<Result<void>> removeDocument(VerificationDocumentType type);

  /// Submits the verification request; resolves to the new status.
  Future<Result<VerificationStatus>> submit();

  Stream<VerificationStatus> watchStatus();
}

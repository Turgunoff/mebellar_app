import 'dart:io';

import '../../core/error/failure.dart';
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

/// Legacy Dio stub — superseded by `SupabaseSellerVerificationRepository`.
/// Kept so the `RepositoryResolver` remote branch still resolves on
/// non-Supabase builds; every call returns an [Err].
class RemoteSellerVerificationRepository
    implements SellerVerificationRepository {
  RemoteSellerVerificationRepository(this._dio);

  // ignore: unused_field — superseded by the Supabase implementation.
  final Object? _dio;

  static const Failure _unavailable = UnknownFailure(
    message: 'Remote verification — use the Supabase repository',
  );

  @override
  List<VerificationDocument> get documents => const [];

  @override
  Stream<List<VerificationDocument>> watchDocuments() => const Stream.empty();

  @override
  Future<Result<VerificationDocument>> uploadDocument({
    required VerificationDocumentType type,
    required File file,
    required String fileExtension,
  }) async =>
      const Err(_unavailable);

  @override
  Future<Result<void>> removeDocument(VerificationDocumentType type) async =>
      const Err(_unavailable);

  @override
  Future<Result<VerificationStatus>> submit() async =>
      const Err(_unavailable);

  @override
  Stream<VerificationStatus> watchStatus() => const Stream.empty();
}

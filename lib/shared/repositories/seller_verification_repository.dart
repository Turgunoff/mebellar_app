import 'dart:io';

import 'package:dio/dio.dart';

import '../models/verification_document.dart';
import '../models/verification_status.dart';

abstract class SellerVerificationRepository {
  /// Current set of documents for the seller — uploaded or in-flight.
  Stream<List<VerificationDocument>> watchDocuments();
  List<VerificationDocument> get documents;

  /// Upload a single document to private storage. Returns the document with
  /// `remoteUrl` populated.
  Future<VerificationDocument> uploadDocument({
    required VerificationDocumentType type,
    required File file,
    required String fileExtension,
  });

  Future<void> removeDocument(VerificationDocumentType type);

  /// Submits the verification request. Mock variant flips status through
  /// pending → in_review (after a short delay) so the UI can render the
  /// banner transitions without a real backend.
  Future<VerificationStatus> submit();

  Stream<VerificationStatus> watchStatus();
}

class RemoteSellerVerificationRepository
    implements SellerVerificationRepository {
  RemoteSellerVerificationRepository(this._dio);

  // ignore: unused_field — Sprint 6 backend wires Supabase storage in
  final Dio _dio;

  @override
  List<VerificationDocument> get documents => const [];

  @override
  Stream<List<VerificationDocument>> watchDocuments() =>
      const Stream.empty();

  @override
  Future<VerificationDocument> uploadDocument({
    required VerificationDocumentType type,
    required File file,
    required String fileExtension,
  }) async {
    throw UnimplementedError('Remote verification — Sprint 6 backend');
  }

  @override
  Future<void> removeDocument(VerificationDocumentType type) async {
    throw UnimplementedError('Remote verification — Sprint 6 backend');
  }

  @override
  Future<VerificationStatus> submit() async {
    throw UnimplementedError('Remote verification — Sprint 6 backend');
  }

  @override
  Stream<VerificationStatus> watchStatus() => const Stream.empty();
}

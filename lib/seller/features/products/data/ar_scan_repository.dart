import 'dart:typed_data';

import '../../../../core/network/woody_api_client.dart';
import '../../../../core/storage/r2_upload_client.dart';

/// Outcome of an AR scan upload — the (future) public video URL the backend
/// composed and the resulting pipeline status (always `processing` on success,
/// the AI engine moves it on from there).
class ArScanUploadResult {
  const ArScanUploadResult({required this.videoUrl, required this.arStatus});
  final String videoUrl;
  final String arStatus;
}

/// Data layer for the seller "Video-to-3D" scan. Two-step, mirroring the image
/// upload but against the dedicated AR endpoint:
///   1. POST /seller/products/{id}/ar-scan/upload-url → presigned PUT + marks
///      the product `processing`.
///   2. PUT the compressed video bytes straight to R2 (no proxy hop).
///
/// The model is generated server-side by an external AI engine and reviewed by
/// an admin — this repo only kicks the pipeline off.
class ArScanRepository {
  ArScanRepository({required WoodyApiClient api, required R2UploadClient uploads})
    : _api = api,
      _uploads = uploads;

  final WoodyApiClient _api;
  final R2UploadClient _uploads;

  Future<ArScanUploadResult> uploadScan({
    required String productId,
    required Uint8List bytes,
    String contentType = 'video/mp4',
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/seller/products/$productId/ar-scan/upload-url',
      body: {'content_type': contentType},
    );
    final uploadUrl = res['upload_url'];
    if (uploadUrl is! String || uploadUrl.isEmpty) {
      throw StateError('Empty AR upload URL from ar-scan/upload-url');
    }

    await _uploads.putToPresignedUrl(
      url: uploadUrl,
      bytes: bytes,
      contentType: contentType,
    );

    final videoUrl = res['video_url'];
    final arStatus = res['ar_status'];
    return ArScanUploadResult(
      videoUrl: videoUrl is String ? videoUrl : '',
      arStatus: arStatus is String ? arStatus : 'processing',
    );
  }
}

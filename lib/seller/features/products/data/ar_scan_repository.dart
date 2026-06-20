import 'dart:typed_data';

import '../../../../core/network/woody_api_client.dart';
import '../../../../core/storage/r2_upload_client.dart';

/// Outcome of an AR scan photo upload — the pipeline status (always
/// `processing` on success) and the Meshy task id the backend is now polling.
class ArScanUploadResult {
  const ArScanUploadResult({required this.arStatus, required this.taskId});
  final String arStatus;
  final String taskId;
}

/// Data layer for the seller "Photos-to-3D" scan. Abstract interface so the
/// capture wizard depends on the contract, not the REST impl, and tests mock it.
///
/// The three guided JPEGs are uploaded to the dedicated public `product-ar-scans`
/// R2 bucket (raw scan INPUT, kept apart from the generated `.glb` in
/// `product-ar-models`) via the same presigned-PUT plumbing a normal product
/// image uses; the resulting public URLs (plus the seller's dimensions) are then
/// POSTed to the dedicated AR endpoint. The 3D model is generated server-side by
/// Meshy and reviewed by an admin — this repo only kicks the pipeline off.
abstract class ArScanRepository {
  Future<ArScanUploadResult> uploadScanPhotos({
    required String productId,
    required List<Uint8List> photos,
    required int heightCm,
    required int widthCm,
    required int lengthCm,
  });
}

class WoodyArScanRepository implements ArScanRepository {
  WoodyArScanRepository({
    required WoodyApiClient api,
    required R2UploadClient uploads,
  }) : _api = api,
       _uploads = uploads;

  final WoodyApiClient _api;
  final R2UploadClient _uploads;

  @override
  Future<ArScanUploadResult> uploadScanPhotos({
    required String productId,
    required List<Uint8List> photos,
    required int heightCm,
    required int widthCm,
    required int lengthCm,
  }) async {
    final imageUrls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      // Presigned PUT into the dedicated public product-ar-scans bucket, then
      // keep the composed public URL. The key is `{productId}/...` — the first
      // segment must be the caller's own product (backend `_assert_path_owned`
      // binds it to the seller), so scans never collide across products.
      final path =
          '$productId/ar-${DateTime.now().millisecondsSinceEpoch}-$i.jpg';
      final result = await _uploads.upload(
        bucket: R2Bucket.productArScans,
        path: path,
        bytes: photos[i],
        contentType: 'image/jpeg',
      );
      final url = result.publicUrl;
      if (url == null || url.isEmpty) {
        // The product-ar-scans bucket only returns a public URL when its public
        // base is configured; without it Meshy can't fetch the photos, so fail
        // loudly rather than POST an unrenderable reference.
        throw StateError('Empty public URL from /storage/upload-url');
      }
      imageUrls.add(url);
    }

    final res = await _api.post<Map<String, dynamic>>(
      '/seller/products/$productId/ar-scan/photos',
      body: {
        'image_urls': imageUrls,
        'height_cm': heightCm,
        'width_cm': widthCm,
        'length_cm': lengthCm,
      },
    );

    final arStatus = res['ar_status'];
    final taskId = res['task_id'];
    return ArScanUploadResult(
      arStatus: arStatus is String ? arStatus : 'processing',
      taskId: taskId is String ? taskId : '',
    );
  }
}

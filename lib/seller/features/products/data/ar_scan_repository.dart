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
/// The three guided JPEGs are uploaded to the public `product-images` R2 bucket
/// via the same presigned-PUT plumbing a normal product image uses; the
/// resulting public URLs (plus the seller's dimensions) are then POSTed to the
/// dedicated AR endpoint. The 3D model is generated server-side by Meshy and
/// reviewed by an admin — this repo only kicks the pipeline off.
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
      // Mirror woody_seller_product_repository.uploadImage: presigned PUT into
      // the public product-images bucket, then keep the composed public URL.
      // Keyed under `ar_sources/` so a product's scan inputs are grouped
      // separately from its catalogue photos in the bucket.
      final path =
          'ar_sources/$productId/ar-${DateTime.now().millisecondsSinceEpoch}-$i.jpg';
      final result = await _uploads.upload(
        bucket: R2Bucket.productImages,
        path: path,
        bytes: photos[i],
        contentType: 'image/jpeg',
      );
      final url = result.publicUrl;
      if (url == null || url.isEmpty) {
        // The product-images bucket only returns a public URL when its public
        // base is configured; without it the model can't be built, so fail
        // loudly rather than POST an unrenderable reference to Meshy.
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

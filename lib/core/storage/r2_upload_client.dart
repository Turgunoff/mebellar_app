import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../network/woody_api_client.dart';

/// Buckets the mobile app uploads to. The strings match the backend
/// `StorageBucket` enum values — keep in sync with
/// `woody_backend/app/domain/storage.py`.
enum R2Bucket {
  productImages('product-images'),
  shopAssets('shop-assets'),
  chatAttachments('chat-attachments'),
  sellerDocuments('seller-documents'),
  verificationDocs('verification-docs'),
  paymentReceipts('payment-receipts');

  const R2Bucket(this.value);
  final String value;
}

/// Result of a successful upload — the path that was stored. Callers
/// persist this as the canonical reference (e.g. `products.images[]`,
/// `chat_messages.attachment_url`, `subscription_receipts.payment_screenshot_path`).
class R2UploadResult {
  const R2UploadResult({required this.bucket, required this.path});
  final R2Bucket bucket;
  final String path;
}

/// Two-step upload: request a presigned PUT URL from woody_backend, then PUT
/// the bytes directly to R2. The backend never sees the body — saves both
/// the bandwidth and the proxy hop.
///
/// The `path` argument is treated as the final R2 key — callers are
/// responsible for generating uniqueness (UUID + extension) and respecting
/// the validation rules in `validate_path` server-side (`[A-Za-z0-9._/-]`,
/// no leading `/`, no `..`).
class R2UploadClient {
  R2UploadClient({required WoodyApiClient api, Dio? rawDio})
      : _api = api,
        _rawDio = rawDio ?? Dio();

  final WoodyApiClient _api;

  /// Plain Dio (no auth interceptor) — R2 presigned PUT URLs already encode
  /// auth in the query string; an extra `Authorization` header would be a
  /// signature mismatch.
  final Dio _rawDio;

  Future<R2UploadResult> upload({
    required R2Bucket bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final presigned = await _api.post<Map<String, dynamic>>(
      '/storage/upload-url',
      body: {
        'bucket': bucket.value,
        'path': path,
        'content_type': contentType,
      },
    );
    final url = presigned['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('Empty presigned URL from /storage/upload-url');
    }
    await _rawDio.put<dynamic>(
      url,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length,
        },
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    return R2UploadResult(bucket: bucket, path: path);
  }

  /// Request a short-lived GET URL for a stored object. Used by the chat
  /// thread to render attachments without making them publicly cacheable.
  Future<String> downloadUrl({
    required R2Bucket bucket,
    required String path,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/storage/download-url',
      body: {
        'bucket': bucket.value,
        'path': path,
        // content_type is required by the body schema but unused on read.
        'content_type': 'application/octet-stream',
      },
    );
    final url = body['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('Empty presigned URL from /storage/download-url');
    }
    return url;
  }
}

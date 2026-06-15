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
  paymentReceipts('payment-receipts'),
  userAvatars('user-avatars');

  const R2Bucket(this.value);
  final String value;
}

/// Result of a successful upload — the path that was stored. Callers
/// persist this as the canonical reference (e.g. `products.images[]`,
/// `chat_messages.attachment_url`, `subscription_receipts.payment_screenshot_path`).
///
/// [publicUrl] is set only for public buckets (e.g. `user-avatars`): it's the
/// permanent, cacheable URL to persist + render directly. Null for private
/// buckets, which must go through [R2UploadClient.downloadUrl].
class R2UploadResult {
  const R2UploadResult({
    required this.bucket,
    required this.path,
    this.publicUrl,
  });
  final R2Bucket bucket;
  final String path;
  final String? publicUrl;
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

  /// PUT bytes to an already-issued presigned R2 URL. Used by flows that get
  /// their presigned URL from a dedicated endpoint rather than
  /// `/storage/upload-url` (e.g. the AR scan upload via
  /// `/seller/products/{id}/ar-scan/upload-url`). Same raw-Dio + error surface
  /// as [upload]; no auth header (the URL signs the request).
  Future<void> putToPresignedUrl({
    required String url,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await _rawDio.put<dynamic>(
        url,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': bytes.length,
          },
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data?.toString() ?? e.message ?? '';
      final snippet = body.length > 500 ? body.substring(0, 500) : body;
      throw StateError('R2 PUT rejected (status=$status): $snippet');
    }
  }

  Future<R2UploadResult> upload({
    required R2Bucket bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final presigned = await _api.post<Map<String, dynamic>>(
      '/storage/upload-url',
      body: {'bucket': bucket.value, 'path': path, 'content_type': contentType},
    );
    final url = presigned['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('Empty presigned URL from /storage/upload-url');
    }
    try {
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
    } on DioException catch (e) {
      // R2 returns an XML <Error><Code>…</Code></Error> body on a rejected
      // PUT. Surface it — "403" alone can't distinguish a token-scope
      // AccessDenied from a SignatureDoesNotMatch (e.g. a checksum/header
      // mismatch), which need different fixes.
      final status = e.response?.statusCode;
      final body = e.response?.data?.toString() ?? e.message ?? '';
      final snippet = body.length > 500 ? body.substring(0, 500) : body;
      throw StateError(
        'R2 PUT rejected (status=$status) for ${bucket.value}/$path: $snippet',
      );
    }
    final publicUrl = presigned['public_url'];
    return R2UploadResult(
      bucket: bucket,
      path: path,
      publicUrl: publicUrl is String && publicUrl.isNotEmpty ? publicUrl : null,
    );
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

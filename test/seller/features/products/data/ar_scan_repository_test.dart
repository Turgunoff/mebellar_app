import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/core/storage/r2_upload_client.dart';
import 'package:woody_app/seller/features/products/data/ar_scan_repository.dart';

class _MockApi extends Mock implements WoodyApiClient {}

class _MockUploads extends Mock implements R2UploadClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(R2Bucket.productImages);
    registerFallbackValue(Uint8List(0));
  });

  late _MockApi api;
  late _MockUploads uploads;
  late WoodyArScanRepository repo;

  setUp(() {
    api = _MockApi();
    uploads = _MockUploads();
    repo = WoodyArScanRepository(api: api, uploads: uploads);
  });

  R2UploadResult uploadOk(String url) => R2UploadResult(
        bucket: R2Bucket.productImages,
        path: 'p',
        publicUrl: url,
      );

  test('uploads each photo to product-images then POSTs the URLs + dims',
      () async {
    var i = 0;
    when(
      () => uploads.upload(
        bucket: any(named: 'bucket'),
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
        contentType: any(named: 'contentType'),
      ),
    ).thenAnswer((_) async => uploadOk('https://cdn/img-${i++}.jpg'));

    when(
      () => api.post<Map<String, dynamic>>(any(), body: any(named: 'body')),
    ).thenAnswer(
      (_) async => {'ar_status': 'processing', 'task_id': 'task-7'},
    );

    final result = await repo.uploadScanPhotos(
      productId: 'prod-1',
      photos: [Uint8List(3), Uint8List(3), Uint8List(3)],
      heightCm: 200,
      widthCm: 90,
      lengthCm: 210,
    );

    expect(result.arStatus, 'processing');
    expect(result.taskId, 'task-7');

    // Exactly three uploads, all to the public product-images bucket as JPEG.
    final captured = verify(
      () => uploads.upload(
        bucket: captureAny(named: 'bucket'),
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
        contentType: captureAny(named: 'contentType'),
      ),
    ).captured;
    expect(captured.length, 6); // 3 calls × 2 captured args
    expect(captured.whereType<R2Bucket>().toList(),
        everyElement(R2Bucket.productImages));
    expect(captured.whereType<String>().toList(),
        everyElement('image/jpeg'));

    // The POST carries the composed public URLs + the three dimensions, with
    // length mapped to depth by the backend contract (sent as length_cm).
    final body = verify(
      () => api.post<Map<String, dynamic>>(
        '/seller/products/prod-1/ar-scan/photos',
        body: captureAny(named: 'body'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(body['image_urls'], [
      'https://cdn/img-0.jpg',
      'https://cdn/img-1.jpg',
      'https://cdn/img-2.jpg',
    ]);
    expect(body['height_cm'], 200);
    expect(body['width_cm'], 90);
    expect(body['length_cm'], 210);
  });

  test('throws when the bucket returns no public URL (no POST fired)', () async {
    when(
      () => uploads.upload(
        bucket: any(named: 'bucket'),
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
        contentType: any(named: 'contentType'),
      ),
    ).thenAnswer((_) async => uploadOk(''));

    await expectLater(
      repo.uploadScanPhotos(
        productId: 'prod-1',
        photos: [Uint8List(3)],
        heightCm: 200,
        widthCm: 90,
        lengthCm: 210,
      ),
      throwsA(isA<StateError>()),
    );

    verifyNever(
      () => api.post<Map<String, dynamic>>(any(), body: any(named: 'body')),
    );
  });

  test('defaults ar_status to processing and task_id to empty on a sparse body',
      () async {
    when(
      () => uploads.upload(
        bucket: any(named: 'bucket'),
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
        contentType: any(named: 'contentType'),
      ),
    ).thenAnswer((_) async => uploadOk('https://cdn/x.jpg'));
    when(
      () => api.post<Map<String, dynamic>>(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => <String, dynamic>{});

    final result = await repo.uploadScanPhotos(
      productId: 'prod-1',
      photos: [Uint8List(3)],
      heightCm: 1,
      widthCm: 1,
      lengthCm: 1,
    );

    expect(result.arStatus, 'processing');
    expect(result.taskId, '');
  });
}

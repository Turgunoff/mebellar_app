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
        bucket: R2Bucket.productArScans,
        path: 'p',
        publicUrl: url,
      );

  test('uploads each photo to product-ar-scans then POSTs the URLs + dims',
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
      partKey: 'bed',
      label: 'Krovat',
      photos: [Uint8List(3), Uint8List(3), Uint8List(3)],
      heightCm: 200,
      widthCm: 90,
      lengthCm: 210,
    );

    expect(result.arStatus, 'processing');
    expect(result.taskId, 'task-7');

    // Exactly three uploads, all to the dedicated public product-ar-scans
    // bucket as JPEG, keyed under the caller's own product id (`{productId}/...`)
    // — never the legacy `ar_sources/` prefix that tripped the backend IDOR
    // guard with a 403.
    final captured = verify(
      () => uploads.upload(
        bucket: captureAny(named: 'bucket'),
        path: captureAny(named: 'path'),
        bytes: any(named: 'bytes'),
        contentType: captureAny(named: 'contentType'),
      ),
    ).captured;
    expect(captured.length, 9); // 3 calls × 3 captured args
    expect(captured.whereType<R2Bucket>().toList(),
        everyElement(R2Bucket.productArScans));
    final strings = captured.whereType<String>().toList();
    expect(strings.where((s) => s == 'image/jpeg').length, 3);
    final paths = strings.where((s) => s.endsWith('.jpg')).toList();
    expect(paths.length, 3);
    expect(paths, everyElement(startsWith('prod-1/')));
    expect(paths, everyElement(isNot(contains('ar_sources'))));

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
    // The part identity rides along so the backend keys the model to the right
    // component (a garnitur's bed vs wardrobe).
    expect(body['part_key'], 'bed');
    expect(body['label'], 'Krovat');
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
        partKey: 'single',
        label: 'Asosiy',
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
      partKey: 'single',
      label: 'Asosiy',
      photos: [Uint8List(3)],
      heightCm: 1,
      widthCm: 1,
      lengthCm: 1,
    );

    expect(result.arStatus, 'processing');
    expect(result.taskId, '');
  });

  test('fetchArParts maps the seller parts payload', () async {
    when(() => api.get<List<dynamic>>(any())).thenAnswer(
      (_) async => [
        {
          'id': 'part-1',
          'part_key': 'bed',
          'label': 'Krovat',
          'ar_status': 'approved',
          'ar_model_url': 'https://cdn/bed.glb',
          'is_ar_visible': true,
          'free_scan_used': true,
          'width_cm': 200,
          'height_cm': 60,
          'depth_cm': 90,
        },
        {
          'id': 'part-2',
          'part_key': 'wardrobe',
          'label': 'Shkaf',
          'ar_status': 'processing',
          'is_ar_visible': true,
          'free_scan_used': true,
        },
      ],
    );

    final parts = await repo.fetchArParts('prod-1');

    verify(() => api.get<List<dynamic>>('/seller/products/prod-1/ar-parts'))
        .called(1);
    expect(parts.length, 2);
    expect(parts.first.partKey, 'bed');
    expect(parts.first.label, 'Krovat');
    expect(parts.first.hasModel, isTrue);
    expect(parts.first.widthCm, 200);
    expect(parts[1].isProcessing, isTrue);
    expect(parts[1].hasModel, isFalse);
  });

  test('setPartVisibility PATCHes the part visibility', () async {
    when(
      () => api.patch<void>(any(), body: any(named: 'body')),
    ).thenAnswer((_) async {});

    await repo.setPartVisibility(
      productId: 'prod-1',
      partId: 'part-1',
      isVisible: false,
    );

    final body = verify(
      () => api.patch<void>(
        '/seller/products/prod-1/parts/part-1/visibility',
        body: captureAny(named: 'body'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(body['is_ar_visible'], false);
  });
}

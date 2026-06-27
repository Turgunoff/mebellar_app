import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/seller/features/products/data/ar_scan_repository.dart';

class _MockApi extends Mock implements WoodyApiClient {}

void main() {
  late _MockApi api;
  late WoodyArScanRepository repo;

  setUp(() {
    api = _MockApi();
    repo = WoodyArScanRepository(api: api);
  });

  test('requestArModel POSTs the part identity + dims and parses the parts',
      () async {
    when(
      () => api.post<List<dynamic>>(any(), body: any(named: 'body')),
    ).thenAnswer(
      (_) async => [
        {
          'id': 'part-1',
          'part_key': 'bed',
          'label': 'Krovat',
          'ar_status': 'pending',
          'is_ar_visible': true,
          'free_scan_used': true,
        },
      ],
    );

    final parts = await repo.requestArModel(
      productId: 'prod-1',
      partKey: 'bed',
      label: 'Krovat',
      heightCm: 200,
      widthCm: 90,
      lengthCm: 210,
    );

    // The request lands the part `pending` (no photos, no Meshy — an admin
    // reviews + sends to Meshy).
    expect(parts.length, 1);
    expect(parts.first.partKey, 'bed');
    expect(parts.first.isPending, isTrue);

    // The POST carries the part identity + the three dimensions, with length
    // mapped to depth by the backend contract (sent as length_cm). No image
    // URLs — the seller no longer uploads scan photos.
    final body = verify(
      () => api.post<List<dynamic>>(
        '/seller/products/prod-1/ar-request',
        body: captureAny(named: 'body'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(body.containsKey('image_urls'), isFalse);
    expect(body['part_key'], 'bed');
    expect(body['label'], 'Krovat');
    expect(body['height_cm'], 200);
    expect(body['width_cm'], 90);
    expect(body['length_cm'], 210);
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

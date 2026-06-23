import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/auth/auth_repository.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/core/storage/r2_upload_client.dart';
import 'package:woody_app/shared/models/tariff.dart';
import 'package:woody_app/shared/repositories/payment_repository.dart';
import 'package:woody_app/shared/repositories/woody_tariff_repository.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

// fetchPlans uses neither, so unstubbed mocks are enough to satisfy the ctor.
class _MockAuth extends Mock implements AuthRepository {}

class _MockUploads extends Mock implements R2UploadClient {}

const _json = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final (int, String) Function(RequestOptions options) responder;
  final List<RequestOptions> calls = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final (status, body) = responder(options);
    return ResponseBody.fromString(body, status, headers: _json);
  }
}

void main() {
  late TokenStore store;

  setUp(() async {
    final storage = _MockSecureStorage();
    final mem = <String, String>{};
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((i) async => mem[i.namedArguments[#key] as String]);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((i) async {
      mem[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((i) async {
      mem.remove(i.namedArguments[#key] as String);
    });
    store = TokenStore(storage);
    await store.write(const TokenPair(accessToken: 'A', refreshToken: 'R'));
  });

  ({WoodyTariffRepository repo, _FakeAdapter adapter}) make(
    (int, String) Function(RequestOptions) responder,
  ) {
    final adapter = _FakeAdapter(responder);
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://test.local',
        validateStatus: (s) => s != null && s < 500,
      ),
    )..httpClientAdapter = adapter;
    final api = WoodyApiClient(tokens: store, dio: dio);
    return (
      repo: WoodyTariffRepository(
        api: api,
        auth: _MockAuth(),
        uploads: _MockUploads(),
      ),
      adapter: adapter,
    );
  }

  test('fetchPlans returns Ok with the mapped plans', () async {
    final h = make(
      (_) => (
        200,
        jsonEncode([
          {
            'id': 'pl1',
            'code': 'pro',
            'name': 'Pro',
            'price_monthly': 100000,
            'is_recommended': true,
          },
        ]),
      ),
    );

    final result = await h.repo.fetchPlans();

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.single.code, 'pro');
    expect(result.valueOrNull?.single.isRecommended, isTrue);
    expect(
      h.adapter.calls.single.uri.path,
      endsWith('/seller/tariff/plans'),
    );
  });

  test('fetchPlans surfaces a server error as Err', () async {
    final h = make((_) => (500, '{"detail":"boom"}'));

    final result = await h.repo.fetchPlans();

    expect(result.isOk, isFalse);
    expect(result.valueOrNull, isNull);
  });

  test('buyPlan posts to /seller/tariff/buy and returns the checkout url + reference',
      () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'provider': 'payme',
          'checkout_url': 'https://checkout.paycom.uz/abc',
          'amount': 299000,
          'reference': 'receipt-7',
        }),
      ),
    );

    final result = await h.repo.buyPlan(
      plan: TariffPlan.pro,
      period: BillingPeriod.monthly,
      provider: PaymentProvider.payme,
    );

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.url, 'https://checkout.paycom.uz/abc');
    // The reference is surfaced so the caller can mark a pending payment.
    expect(result.valueOrNull?.reference, 'receipt-7');
    expect(h.adapter.calls.single.uri.path, endsWith('/seller/tariff/buy'));
  });

  test('buyPlan surfaces a 503 (provider unconfigured) as Err', () async {
    final h = make((_) => (503, '{"detail":"payments_unavailable"}'));

    final result = await h.repo.buyPlan(
      plan: TariffPlan.pro,
      period: BillingPeriod.yearly,
      provider: PaymentProvider.click,
    );

    expect(result.isOk, isFalse);
    expect(result.valueOrNull, isNull);
  });
}

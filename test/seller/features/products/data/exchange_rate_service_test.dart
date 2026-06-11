import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/seller/features/products/data/exchange_rate_service.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _response(dynamic data) => Response<dynamic>(
  requestOptions: RequestOptions(path: CbuExchangeRateService.ratesUrl),
  statusCode: 200,
  data: data,
);

/// Trimmed-down shape of the real CBU feed: `Rate` is a numeric string.
const _cbuPayload = [
  {'id': 21, 'Ccy': 'EUR', 'Rate': '13720.11', 'Date': '11.06.2026'},
  {'id': 69, 'Ccy': 'USD', 'Rate': '12650.43', 'Date': '11.06.2026'},
  {'id': 57, 'Ccy': 'RUB', 'Rate': '160.05', 'Date': '11.06.2026'},
];

void main() {
  group('parseCbuUsdRate', () {
    test('extracts the USD rate from the currency array', () {
      expect(parseCbuUsdRate(_cbuPayload), 12650.43);
    });

    test('decodes a raw JSON string body (text/html content type)', () {
      expect(parseCbuUsdRate(jsonEncode(_cbuPayload)), 12650.43);
    });

    test('returns null when USD is absent', () {
      expect(
        parseCbuUsdRate(const [
          {'Ccy': 'EUR', 'Rate': '13720.11'},
        ]),
        isNull,
      );
    });

    test('returns null for a non-numeric rate', () {
      expect(
        parseCbuUsdRate(const [
          {'Ccy': 'USD', 'Rate': 'N/A'},
        ]),
        isNull,
      );
    });

    test('returns null for a non-positive rate', () {
      expect(
        parseCbuUsdRate(const [
          {'Ccy': 'USD', 'Rate': '0'},
        ]),
        isNull,
      );
    });

    test('returns null for unexpected shapes', () {
      expect(parseCbuUsdRate(null), isNull);
      expect(parseCbuUsdRate('not json'), isNull);
      expect(parseCbuUsdRate(const {'Ccy': 'USD'}), isNull);
      expect(parseCbuUsdRate(const ['USD']), isNull);
    });
  });

  group('CbuExchangeRateService', () {
    late _MockDio dio;

    setUp(() => dio = _MockDio());

    test('fetches, parses and serves the cached rate within the TTL', () async {
      when(
        () => dio.get<dynamic>(any()),
      ).thenAnswer((_) async => _response(_cbuPayload));
      final service = CbuExchangeRateService(dio: dio);

      expect(await service.getUsdRate(), 12650.43);
      expect(await service.getUsdRate(), 12650.43);

      verify(() => dio.get<dynamic>(any())).called(1);
    });

    test('returns null when the request fails and nothing is cached', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: CbuExchangeRateService.ratesUrl),
        ),
      );
      final service = CbuExchangeRateService(dio: dio);

      expect(await service.getUsdRate(), isNull);
    });

    test('serves the stale cached rate when a refresh fails', () async {
      when(
        () => dio.get<dynamic>(any()),
      ).thenAnswer((_) async => _response(_cbuPayload));
      // Zero TTL forces every call through the network path.
      final service = CbuExchangeRateService(dio: dio, ttl: Duration.zero);

      expect(await service.getUsdRate(), 12650.43);

      when(() => dio.get<dynamic>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: CbuExchangeRateService.ratesUrl),
        ),
      );
      expect(
        await service.getUsdRate(),
        12650.43,
        reason: 'a stale daily rate beats no rate',
      );
    });

    test(
      'keeps the cache when a refresh returns an unusable payload',
      () async {
        when(
          () => dio.get<dynamic>(any()),
        ).thenAnswer((_) async => _response(_cbuPayload));
        final service = CbuExchangeRateService(dio: dio, ttl: Duration.zero);

        expect(await service.getUsdRate(), 12650.43);

        when(
          () => dio.get<dynamic>(any()),
        ).thenAnswer((_) async => _response('<html>maintenance</html>'));
        expect(await service.getUsdRate(), 12650.43);
      },
    );

    test('concurrent callers share a single in-flight request', () async {
      final completer = Completer<Response<dynamic>>();
      when(() => dio.get<dynamic>(any())).thenAnswer((_) => completer.future);
      final service = CbuExchangeRateService(dio: dio);

      final first = service.getUsdRate();
      final second = service.getUsdRate();
      completer.complete(_response(_cbuPayload));

      expect(await first, 12650.43);
      expect(await second, 12650.43);
      verify(() => dio.get<dynamic>(any())).called(1);
    });
  });
}

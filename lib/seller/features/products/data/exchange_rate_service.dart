import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/network_logger_interceptor.dart';

/// USD→UZS exchange rate source for the product form's currency toggle.
///
/// This is the one sanctioned exception to the "only woody_backend" rule:
/// the rate is a public, read-only feed from the Central Bank of Uzbekistan
/// and is used purely as a client-side input convenience — the backend never
/// sees USD (see `AddProductCubit.submit`, which converts before sending).
abstract class ExchangeRateService {
  /// Latest known USD→UZS rate, or null when it can't be determined.
  /// Implementations never throw — pricing degrades to UZS-only input.
  Future<double?> getUsdRate();
}

/// Fetches the official daily rate from the CBU public JSON feed and caches
/// it in memory. CBU publishes one rate per business day, so the TTL is
/// purely defensive — the goal is one network call per app session (the
/// form refetches through this cache every time it opens).
class CbuExchangeRateService implements ExchangeRateService {
  CbuExchangeRateService({Dio? dio, Duration ttl = const Duration(hours: 1)})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          ),
      _ttl = ttl {
    // Debug-only traffic logging for the CBU rate feed. Skipped when a Dio is
    // injected (tests) so mock-adapter runs stay quiet.
    if (kDebugMode && dio == null) {
      _dio.interceptors.add(const NetworkLoggerInterceptor());
    }
  }

  static const String ratesUrl = 'https://cbu.uz/oz/arkhiv-kursov-valyut/json/';

  final Dio _dio;
  final Duration _ttl;

  double? _cachedRate;
  DateTime? _fetchedAt;
  Future<double?>? _inFlight;

  @override
  Future<double?> getUsdRate() {
    final fetchedAt = _fetchedAt;
    if (_cachedRate != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _ttl) {
      return Future.value(_cachedRate);
    }
    // Concurrent callers (screen open + a retry tap) share one request.
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<double?> _fetch() async {
    try {
      final res = await _dio.get<dynamic>(ratesUrl);
      final rate = parseCbuUsdRate(res.data);
      if (rate != null) {
        _cachedRate = rate;
        _fetchedAt = DateTime.now();
        return rate;
      }
      appLog.warning('[cbu-rates] USD missing from CBU payload');
      return _cachedRate;
    } catch (e, st) {
      appLog.handle(e, st, '[cbu-rates] USD rate fetch failed');
      // A stale daily rate is still a fine approximation for the helper text.
      return _cachedRate;
    }
  }
}

/// Pulls the USD `Rate` out of the CBU feed payload — a JSON array of
/// currency objects whose `Rate` field is a numeric *string* (`"12650.43"`).
/// Returns null on any shape surprise rather than throwing.
double? parseCbuUsdRate(dynamic data) {
  var payload = data;
  if (payload is String) {
    // CBU sometimes serves the feed as text/html, leaving Dio's body undecoded.
    try {
      payload = jsonDecode(payload);
    } on FormatException {
      return null;
    }
  }
  if (payload is! List) return null;
  for (final item in payload) {
    if (item is Map && item['Ccy'] == 'USD') {
      final rate = double.tryParse(item['Rate']?.toString() ?? '');
      return (rate != null && rate > 0) ? rate : null;
    }
  }
  return null;
}

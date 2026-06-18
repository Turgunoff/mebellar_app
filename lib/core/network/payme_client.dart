import 'package:dio/dio.dart';

import '../../config/app_config.dart';

/// A card token + display metadata returned by Payme's Subscribe API.
class PaymeCard {
  const PaymeCard({
    required this.token,
    required this.maskedNumber,
    required this.recurrent,
    required this.verify,
  });

  /// The recurring-payment token. This — and ONLY this, plus the masked
  /// number — is what gets sent to the Woody backend. The raw PAN never
  /// leaves the device.
  final String token;

  /// e.g. `860006******6311`.
  final String maskedNumber;
  final bool recurrent;
  final bool verify;

  factory PaymeCard.fromCardJson(Map<String, dynamic> card) => PaymeCard(
    token: card['token'] as String? ?? '',
    maskedNumber: card['number'] as String? ?? '',
    recurrent: card['recurrent'] as bool? ?? false,
    verify: card['verify'] as bool? ?? false,
  );
}

/// The SMS-verification challenge returned by `cards.get_verify_code`.
class PaymeVerifyChallenge {
  const PaymeVerifyChallenge({required this.phone, required this.waitMs});

  /// Masked phone the OTP was sent to (e.g. `99890*****31`).
  final String phone;

  /// How long the code stays valid, in milliseconds.
  final int waitMs;
}

/// Any failure talking to Payme — transport, or a JSON-RPC `error` object.
/// `code` is Payme's negative error code when present (e.g. wrong/expired SMS
/// code), so the UI can show a specific message.
class PaymeException implements Exception {
  PaymeException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => 'PaymeException($code): $message';
}

/// Talks DIRECTLY to Payme's Subscribe API to tokenise + OTP-verify a card.
///
/// This is the *client* half of the split: it authenticates with
/// `X-Auth: {merchant_id}` (NO key) and only ever performs the three card
/// methods. The raw card number + expiry are sent straight to Payme and never
/// touch the Woody backend (PCI scope stays with Payme). The backend half
/// (cards.check/remove, receipts.*) lives in woody_backend with the key.
class PaymeClient {
  PaymeClient({String? merchantId, String? baseUrl, Dio? dio})
    : _merchantId = merchantId ?? AppConfig.paymeMerchantId,
      _dio = dio ?? _defaultDio(baseUrl ?? AppConfig.paymeApiUrl);

  final String _merchantId;
  final Dio _dio;
  int _rpcId = 0;

  static Dio _defaultDio(String baseUrl) => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      // 4xx don't throw — Payme replies 200 with a JSON-RPC error anyway, but
      // be defensive so error extraction is uniform.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  Future<Map<String, dynamic>> _rpc(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (_merchantId.isEmpty) {
      throw PaymeException('Payme is not configured');
    }
    _rpcId += 1;
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '',
        data: {
          'jsonrpc': '2.0',
          'id': _rpcId,
          'method': method,
          'params': params,
        },
        options: Options(headers: {'X-Auth': _merchantId}),
      );
    } on DioException catch (e) {
      throw PaymeException('Payme $method failed: ${e.message}');
    }

    final data = response.data;
    if (data is! Map) {
      throw PaymeException('Payme $method returned an unexpected body');
    }
    final error = data['error'];
    if (error is Map) {
      throw PaymeException(
        _extractMessage(error['message']),
        code: error['code'] as int?,
      );
    }
    final result = data['result'];
    if (result is! Map) {
      throw PaymeException('Payme $method returned no result');
    }
    return Map<String, dynamic>.from(result);
  }

  /// Payme's `error.message` is sometimes a plain string, sometimes a
  /// localised object `{uz, ru, en}`. Flatten either into a single string for
  /// logging — the UI shows its own localised copy keyed off the step/code.
  String _extractMessage(dynamic message) {
    if (message is String) return message;
    if (message is Map) {
      return (message['uz'] ?? message['ru'] ?? message['en'] ?? 'payme_error')
          .toString();
    }
    return 'payme_error';
  }

  Map<String, dynamic> _requireCard(Map<String, dynamic> result, String method) {
    final card = result['card'];
    if (card is! Map) {
      throw PaymeException('Payme $method returned no card');
    }
    return Map<String, dynamic>.from(card);
  }

  /// Step 1 — tokenise the raw card. `expire` is MMYY (e.g. `0399`). `save:true`
  /// makes the token reusable for recurring charges.
  Future<PaymeCard> createCard({
    required String number,
    required String expire,
  }) async {
    final result = await _rpc('cards.create', {
      'card': {'number': number, 'expire': expire},
      'save': true,
    });
    return PaymeCard.fromCardJson(_requireCard(result, 'cards.create'));
  }

  /// Step 2 — trigger the SMS verification code to the card's bound phone.
  Future<PaymeVerifyChallenge> getVerifyCode(String token) async {
    final result = await _rpc('cards.get_verify_code', {'token': token});
    return PaymeVerifyChallenge(
      phone: result['phone'] as String? ?? '',
      waitMs: (result['wait'] as num?)?.toInt() ?? 60000,
    );
  }

  /// Step 3 — confirm the SMS code. On success the returned card has
  /// `verify == true`; that token is what we persist on the backend.
  Future<PaymeCard> verifyCard({
    required String token,
    required String code,
  }) async {
    final result = await _rpc('cards.verify', {'token': token, 'code': code});
    return PaymeCard.fromCardJson(_requireCard(result, 'cards.verify'));
  }

  void dispose() => _dio.close(force: true);
}

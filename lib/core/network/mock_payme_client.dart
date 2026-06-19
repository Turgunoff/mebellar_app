import 'payme_client.dart';

/// In-app MOCK of [PaymeClient] — lets the full add-card + pay flow run with
/// NO real Payme credentials (demos / QA). Activated by `PAYME_MOCK=true`
/// (see `AppConfig.paymeMock`) and swapped in for the real client in
/// `core_module.dart`.
///
/// It mimics the real client's async shape on purpose — a ~1s round-trip per
/// call, a token from `cards.create`, an SMS challenge, and a `cards.verify`
/// that accepts any 6-digit code — so switching back to the real [PaymeClient]
/// (set the merchant id, drop the flag) needs no caller changes.
///
/// Implemented with `implements` (not a subclass) so it never constructs a Dio
/// or touches Payme's URL; the real client's private RPC plumbing is untouched.
class MockPaymeClient implements PaymeClient {
  MockPaymeClient({this.latency = const Duration(seconds: 1)});

  /// Simulated network round-trip per call. Makes the flow feel real in a
  /// demo; tests pass [Duration.zero].
  final Duration latency;

  /// Remembers the masked number per token so [verifyCard] can echo the same
  /// value [createCard] produced — the real client gets it back from Payme.
  final Map<String, String> _maskedByToken = {};
  int _seq = 0;

  @override
  Future<PaymeCard> createCard({
    required String number,
    required String expire,
  }) async {
    await Future<void>.delayed(latency);
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final masked = _mask(digits);
    _seq += 1;
    // Unique per card so the backend's UNIQUE(user_id, token) never collides.
    final token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}_$_seq';
    _maskedByToken[token] = masked;
    return PaymeCard(
      token: token,
      maskedNumber: masked,
      recurrent: true,
      verify: false,
    );
  }

  @override
  Future<PaymeVerifyChallenge> getVerifyCode(String token) async {
    await Future<void>.delayed(latency);
    return const PaymeVerifyChallenge(phone: '99890*****00', waitMs: 60000);
  }

  @override
  Future<PaymeCard> verifyCard({
    required String token,
    required String code,
  }) async {
    await Future<void>.delayed(latency);
    final digits = code.replaceAll(RegExp(r'\D'), '');
    // Accept ANY 6-digit code (e.g. 666666); reject anything else so the UI
    // still exercises its wrong-code path. -31103 mirrors Payme's real
    // "invalid verification code" JSON-RPC error code.
    if (digits.length != 6) {
      throw PaymeException('Invalid verification code', code: -31103);
    }
    return PaymeCard(
      token: token,
      maskedNumber: _maskedByToken[token] ?? '',
      recurrent: true,
      verify: true,
    );
  }

  @override
  void dispose() {}

  /// `8600 **** **** 1234` from the entered PAN.
  static String _mask(String digits) {
    if (digits.length < 8) return digits;
    final first = digits.substring(0, 4);
    final last = digits.substring(digits.length - 4);
    return '$first **** **** $last';
  }
}

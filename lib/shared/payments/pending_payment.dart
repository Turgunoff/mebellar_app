/// What a pending external (Payme/Click) payment settles. Each kind polls a
/// different backend status endpoint and has its own "settled" sentinel, so the
/// gateway routes on this. Scales the recovery flow across all three checkout
/// surfaces without special-casing any caller.
enum PendingPaymentKind {
  /// A customer storefront order (`GET /orders/{id}` → `payment_status`).
  order('order'),

  /// A seller AR-token top-up (`GET /seller/ar-tokens/purchases/{id}`).
  arTokens('ar_tokens'),

  /// A seller tariff subscription (`GET /seller/tariff/receipts/{id}/status`).
  subscription('subscription');

  const PendingPaymentKind(this.code);

  /// Stable string persisted in SharedPreferences — never reuse a value.
  final String code;

  static PendingPaymentKind? fromCode(String? code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// The resolved settlement of a pending payment after a status probe.
/// `unknown` is a probe that couldn't decide (network / auth / 404) — the UI
/// treats it like `pending` (never claims success on uncertainty).
enum PaymentOutcome { paid, pending, unknown }

/// A persisted marker for one in-flight external payment, written the instant
/// the app hands off to the Payme/Click app. It lets the payment be reconciled
/// when the customer returns — whether the app merely backgrounded (resume
/// polling) or the OS killed it mid-payment (cold-start recovery).
class PendingPayment {
  const PendingPayment({
    required this.kind,
    required this.reference,
    required this.createdAtMs,
  });

  final PendingPaymentKind kind;

  /// The merchant account value the provider webhook keys on (order id /
  /// ar_purchase_id / subscription receipt id) — also the id the status
  /// endpoint is fetched by.
  final String reference;

  /// Epoch millis of the hand-off, for staleness guarding.
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
    'kind': kind.code,
    'reference': reference,
    'created_at_ms': createdAtMs,
  };

  /// Parses a stored marker, or null when the payload is malformed / from a
  /// retired kind — so a bad record degrades to "nothing pending" instead of
  /// throwing during recovery.
  static PendingPayment? fromJson(Map<String, dynamic> json) {
    final kind = PendingPaymentKind.fromCode(json['kind'] as String?);
    final reference = json['reference'] as String?;
    if (kind == null || reference == null || reference.isEmpty) return null;
    return PendingPayment(
      kind: kind,
      reference: reference,
      createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

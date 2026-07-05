import '../../core/i18n/i18n.dart';

/// Whether a payment row awaits admin receipt review (P2P card + screenshot)
/// vs an in-flight Payme/Click checkout settled by webhook.
bool isManualPaymentReview({required String provider, String? status}) {
  if (provider == 'manual') return true;
  if (status == 'pending_review') return true;
  return false;
}

String pendingBannerNotice({
  required bool manualReview,
  required int amountSom,
  int? tokenCount,
}) {
  if (tokenCount != null) {
    return manualReview
        ? tr(
            'seller.ar_pending_purchase_notice',
            namedArgs: {
              'count': '$tokenCount',
              'amount': _formatSom(amountSom),
            },
          )
        : tr(
            'seller.ar_pending_online_notice',
            namedArgs: {
              'count': '$tokenCount',
              'amount': _formatSom(amountSom),
            },
          );
  }
  return manualReview
      ? tr(
          'seller.wallet_pending_topup_notice',
          namedArgs: {'amount': _formatSom(amountSom)},
        )
      : tr(
          'seller.wallet_pending_deposit_notice',
          namedArgs: {'amount': _formatSom(amountSom)},
        );
}

String pendingHeadline({required bool manualReview}) => manualReview
    ? tr('tariff.pending_headline')
    : tr('seller.pending_online_headline');

String pendingSubtitle({required bool manualReview}) => manualReview
    ? tr('tariff.pending_subtitle')
    : tr('seller.pending_online_subtitle');

/// Machine code written by the backend when a manual payment SLA lapses.
const kPaymentSlaExpiredReason = 'sla_expired';

bool isSlaExpiredCancellation(String? reason) =>
    reason == kPaymentSlaExpiredReason;

String resolvePaymentCancellationReason(String? reason) {
  if (isSlaExpiredCancellation(reason)) {
    return tr('seller.payment_sla_expired_message');
  }
  if (reason != null && reason.trim().isNotEmpty) {
    return reason.trim();
  }
  return tr('seller.manual_payment_rejected_subtitle');
}

String pendingSlaTitle({required bool manualReview}) => manualReview
    ? tr('tariff.sla_title')
    : tr('seller.pending_online_sla_title');

String _formatSom(int amount) {
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return buf.toString();
}

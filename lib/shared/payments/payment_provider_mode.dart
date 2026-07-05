/// How a checkout provider (Payme / Click) is exposed in the mobile app.
///
/// Mirrors woody_backend `PaymentProviderMode` (`app_settings.payment_methods`).
enum PaymentProviderMode {
  /// Selectable; checkout links are minted.
  enabled,

  /// Visible but greyed out with a "coming soon" badge; not selectable.
  comingSoon,

  /// Not shown in the mobile app.
  hidden,
}

/// Parses a stored `payment_methods` field value into [PaymentProviderMode].
///
/// Backward-compatible with the original bool flags: `true` → [enabled],
/// `false` → [hidden]. Unknown values fall back to [enabled].
PaymentProviderMode parsePaymentProviderMode(dynamic raw) {
  if (raw == true || raw == 'true') return PaymentProviderMode.enabled;
  if (raw == false || raw == 'false') return PaymentProviderMode.hidden;
  if (raw == 'enabled') return PaymentProviderMode.enabled;
  if (raw == 'coming_soon') return PaymentProviderMode.comingSoon;
  if (raw == 'hidden') return PaymentProviderMode.hidden;
  return PaymentProviderMode.enabled;
}

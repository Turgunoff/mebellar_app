/// Centralised font family names — single source of truth so a future font
/// swap is a one-line edit. Every `fontFamily:` in the codebase routes
/// through here; never hard-code a font name in a widget.
///
/// The matching `.ttf` files live in `assets/google_fonts/` and are bundled
/// into the app — no network fetch at runtime. See
/// [assets/google_fonts/README.md] for the bundling convention.
class AppFonts {
  const AppFonts._();

  /// Editorial / display headlines (Woody wordmark, splash, hero titles).
  static const String display = 'PlayfairDisplay';

  /// Customer-mode UI: body text, captions, buttons.
  static const String body = 'Inter';

  /// Seller-mode UI: dashboards, products, settings.
  /// Distinct from customer's [body] to give the seller surface a more
  /// "SaaS / FinTech" tone while keeping both customer and seller within
  /// a unified Woody brand language.
  static const String seller = 'PlusJakartaSans';

  /// Accent — rarely used, single-purpose helper.
  static const String accent = 'Manrope';
}

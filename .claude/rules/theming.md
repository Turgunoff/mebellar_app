# Rule card — theming

> Distilled invariants for agents and `/review`. Authoritative narrative
> is `CLAUDE.md` (§Theme tokens — never hardcode colours). `CLAUDE.md` wins.

The app has **light and dark mode**. Every surface / text / border /
field-fill colour comes from a **token bag**, never a const literal —
otherwise it won't flip in dark mode.

- **Customer screens** (home, search, chat, profile) →
  `PremiumTokens.of(context)`.
- **Auth bottom sheet** (phone / OTP / profile steps) →
  `AuthTokens.of(context)`.
- **Seller order details** → local tokens `kInk`, `kDivider`, … in
  `seller/features/orders/widgets/order_details/order_details_kit.dart`.

**Brand accents are the only constants** — `PremiumTokens.accent` and
`kTerracotta`, both `#C27A5F`. They do **not** flip in dark mode.

Checklist for any UI change:
- No `Color(0x…)` / `Colors.x` for a themed surface, text, border, or
  fill. Reach for the token bag instead.
- A new screen pumps inside the correct theme/token providers (so
  `*.of(context)` resolves — also required in widget tests).
- Fonts come from `AppFonts`; don't hardcode font families.

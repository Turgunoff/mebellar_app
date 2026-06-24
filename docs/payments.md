# Payments

> Companion to the root [`README.md`](../README.md) §3. Where the operational brain [`CLAUDE.md`](../CLAUDE.md) disagrees, it wins.

## What the app does — and does not — do

The Flutter app performs **client-side deep-link hand-off only**. It does **NOT** store cards, charge, or hold any payment secret. The removed saved-cards repository is gone.

There are **no Payme/Click webhooks or JSON-RPC methods in this repo**. The Payme Merchant webhook (`POST /webhooks/payme`, 6 RPC + fiscalization) and the Click integration live in **`woody_backend`**. The shared backend ledger settles three targets through the same `subscription_receipts`-style flow: **orders**, **AR-token purchases**, and **tariff subscriptions** — plus wallet deposits.

## Hand-off flow

```
PaymentProvider {payme, click}                 (lib/shared/repositories/payment_repository.dart; slug == name)
   │
   │  PaymentRepository.checkoutUrl()
   ▼
POST /orders/{id}/pay/{provider}
   │  ← CheckoutLink { provider, checkout_url, amount, reference }
   ▼
launchUrl(checkout_url, LaunchMode.externalApplication)   → opens the Payme/Click app
```

Errors surfaced as `ApiError`:

| Status | Meaning |
| --- | --- |
| 404 | Not your order |
| 409 | Already paid |
| 503 | Provider unconfigured |

## Checkout

`CheckoutCubit` with `CheckoutPayment {cash, payme, click}`:

- The cart **fans out into one order per shop**.
- **Multi-shop carts can only link the FIRST order** for an online payment — a documented limitation.
- The cart is **cleared before** the link is minted, so a failed hand-off can't duplicate the checkout.
- A failed mint still counts as success: the order is placed **unpaid**, because payment confirmation is a webhook concern (handled by the backend).

## Recovery (`lib/shared/payments/`, root-scoped)

Because the user leaves the app to pay, the app must reconcile state on return — even across an OS kill.

1. On hand-off, `PendingPaymentService.mark` writes a `PendingPayment { kind, reference, createdAtMs }` to `PendingPaymentStore`. This uses **SharedPreferences (not Hive)** so it survives an OS kill.
2. `PaymentRecoveryGate` (wrapped around both mode builders) resumes on return — a **resume poll** plus a **cold-start probe**.
3. `WoodyPaymentStatusGateway` routes each kind to its status endpoint:

| `PendingPaymentKind` | Status endpoint | "paid" condition |
| --- | --- | --- |
| `order` | `GET /orders/{id}` | `payment_status == 'paid'` |
| `arTokens` | `/seller/ar-tokens/purchases/{id}` | `{status, paid}` shape |
| `subscription` | `/seller/tariff/receipts/{id}/status` | `{status, paid}` shape |
| `walletDeposit` | `/seller/wallet/deposit/{id}/status` | `{status, paid}` shape |

4. Each probe maps to `PaymentOutcome {paid, pending, unknown}`. **`unknown` (network/auth/404) is treated like `pending` — it never claims success.**

## Where the rails are reused

Payme/Click also power:

- **Seller tariff upgrades** — `payment_instructions_sheet`.
- **Wallet deposits**.
- **AR-token top-ups** — `ar_token_buy_sheet`.

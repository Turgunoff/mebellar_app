# Environment Configuration

> Companion to the root [`README.md`](../README.md) §6. Where the operational brain [`CLAUDE.md`](../CLAUDE.md) disagrees, it wins.

There is **no `.env` file**. Flutter reads build-time constants injected via `--dart-define-from-file`. The contract is the single canonical file **`env/prod.json`** (gitignored), seeded from the committed template **`env/example.json`**:

```bash
cp env/example.json env/prod.json   # then fill WOODY_API_URL + YANDEX_GEOCODER_API_KEY (at minimum)
```

`AppConfig.assertConfigured()` runs at the top of `main()` and **aborts loudly** if a required key is missing — **no secret has a compiled-in default**. A build without the env file crashes before the splash paints.

## Key table

| Key | Required | Read via | Purpose | Example |
| --- | --- | --- | --- | --- |
| `WOODY_API_URL` | ✅ | `String.fromEnvironment` | Backend base URL; `WoodyApiClient` appends `/api/v1`. | `https://api.woody.uz` |
| `YANDEX_GEOCODER_API_KEY` | ✅ | `String.fromEnvironment` | Yandex Geocoder/MapKit key for the checkout map address picker. Restrict by package/referrer in the Yandex Cloud console. | `yandex-geocoder-dummy-key-0000000000000000` |
| `APP_ENV` | — | `String.fromEnvironment` | Deployment tag. `AppConfig.isProd == (APP_ENV == 'prod')` (defaults to `dev`, so `isProd` can never be true by accident). Tags the Crashlytics `environment` key. | `prod` |
| `PAYME_MERCHANT_ID` | — | not read by the app (env file only) | Vestigial Payme merchant id; the live checkout link is minted entirely by the backend (`POST /orders/{id}/pay/{provider}`). Not read via `String.fromEnvironment` and not used by native code. | `0000000000000000000000aa` |
| `PAYME_API_URL` | — | not read by the app (env file only) | Vestigial Payme base; unused by the client. | `https://checkout.test.paycom.uz` |
| `PAYME_MOCK` | — | not read by the app (env file only) | Vestigial mock flag; unused by the client. | `true` |
| `SELLER_USES_GO_ROUTER` | — | `bool.fromEnvironment` | Route seller mode through the go_router `StatefulShellRoute` (default `true`); flip OFF to fall back to legacy imperative seller navigation while debugging. | `true` |
| `SCREENSHOT_MODE` | — | `bool.fromEnvironment` (`lib/config/screenshot_mode.dart`) | Enables the integration-test showcase/screenshot pipeline that feeds the `woody_frontend` landing PNGs. | `false` |

## Notes

- The `PAYME_*` keys are present in the live `env/prod.json` but are **not read anywhere in the app** — not via `String.fromEnvironment` in `lib/config`, and not by the Android/iOS native code (`grep -rn PAYME lib/ android/ ios/` is empty). They are vestigial config left from the removed saved-cards flow; the real payment flow gets its checkout URL from the backend (`POST /orders/{id}/pay/{provider}`). They are mirrored into `env/example.json` only so a fresh `cp` matches the on-disk key set.
- Firebase config is **not** in this file — it lives in native files (`google-services.json`, `GoogleService-Info.plist` + APNs) plus `firebase_options.dart`.

## Secrets hygiene

`env/prod.json` is gitignored. Never commit it, signing keystores (`*.jks`, `key.properties`), a Firebase Admin SDK service-account key, or a `google-services.json` that carries secrets.

# Augmented Reality (AR)

> Companion to the root [`README.md`](../README.md) §3. Where the operational brain [`CLAUDE.md`](../CLAUDE.md) disagrees, it wins.

## Product → Parts mapping

A product can be a single piece or a multi-piece set (a *garnitur*). The model is **per-part**:

- **`Product.arParts`** is a `List<ArPart>` (`lib/shared/models/`).
- **`ArPart`** (`lib/shared/models/ar_part.dart`):
  `{ id, partKey ('bed'|'wardrobe'|'single'|…), label, arStatus (none|processing|approved|failed), arModelUrl, usdzUrl, arModelBytes, arUsdzBytes, isArVisible, freeScanUsed, arErrorReason, widthCm/heightCm/depthCm }`.
- A **single-piece product is one `single` part**.
- **Each part is one independently generated 3D model.**

### Two JSON shapes

| Constructor | Source | Visibility |
| --- | --- | --- |
| `ArPart.fromCustomerJson` | buyer detail `ar_parts[]` | approved + visible only |
| `ArPart.fromSellerJson` | `GET /seller/products/{id}/ar-parts` | full per-part state |

### Derived getters

| Getter | Definition |
| --- | --- |
| `Product.hasAr` | `arModelUrl` present **&&** `arStatus == 'approved'` |
| `Product.hasMultiPartAr` | `arParts.where(hasModel).length >= 2` |
| `ArViewerState.hasMultipleParts` | `parts.length > 1` (viewer-cubit state, drives the in-viewer part toggle) |
| `ArPart.hasModel` | `arModelUrl` present **&&** `arStatus == 'approved'` |

## Monetization (per-part)

Per part: **1 free scan, then an AR token** drawn from the seller's token wallet. Token purchase lives in the seller profile (`lib/seller/features/wallet/screens/ar_tokens_screen.dart`) backed by `lib/seller/features/products/data/ar_token_repository.dart` + `lib/seller/features/products/widgets/ar_token_buy_sheet.dart`, and tops up via the payment recovery rails (`PendingPaymentKind.arTokens` — see [`payments.md`](./payments.md)).

## Client viewer routing

`lib/customer/features/product_list/widgets/ar_entry_points.dart` gates entry (using `Product.hasMultiPartAr`). Routing depends on part count and device capability:

| Path | Screen | Tech |
| --- | --- | --- |
| Single-part / inline | `BuyerArViewerScreen` | `model_viewer_plus` (`<model-viewer>`), part toggle via `ArViewerCubit`, `GlbCacheService` / `glb_cache_manager` `file://` cache, watermarked save-to-gallery via `toDataURL` + JS channel + `gal` |
| Multi-part set (`hasMultiPartAr`) | `SetArViewerScreen` | **Native ARCore/ARKit** via `ar_flutter_plugin_plus` |
| Non-AR device | `fallback_2d_camera_screen.dart` | 2D sticker overlay |

### Native multi-object scene (`SetArViewerScreen`)

Hybrid placement UX: arm a piece from the bottom dock, tap the floor to drop it (cumulative add into `Map<nodeName, _PlacedNode>`). Each node is independently movable/rotatable (`handlePans` / `handleRotation`); tapping a placed node selects/deletes it (`onNodeTap`). `ar_scale.dart` scales true-to-size from real-world dimensions.

> `ar_flutter_plugin_plus` is a **native** dependency — native multi-object AR ships only in a **full store release, never a Shorebird patch**. The Dart-only 2D fallback can ride a patch.

## Device capability probe

`ArSupport` (`lib/shared/ar/ar_support.dart`) probes via `MethodChannel com.mebellar.app/ar`:

- **Android** → `PackageManager.FEATURE_CAMERA_AR`.
- **iOS** → returns true (AR Quick Look).

## Seller side — scan and manage

- `seller_ar_model_screen.dart` — compact per-part list with an eye/visibility toggle and regenerate.
- **AR scan** = a locked 3-photo camera capture → compress → upload to R2 (`product-ar-scans` bucket) → **Meshy photo-to-3D pipeline** (backend-owned; `MESHY_API_KEY` is backend-side). Per-part models auto-approve.

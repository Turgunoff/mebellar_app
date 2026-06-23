import 'package:equatable/equatable.dart';

/// One AR part of a product — a single scannable furniture component (a
/// garnitur's bed, wardrobe, …; a single-piece product is one `single` part),
/// each with its own generated 3D model, customer visibility, and free-scan
/// state.
///
/// Two shapes feed this model:
///  * the **customer** product-detail (`ar_parts[]`) carries only buyer-visible
///    (approved + visible) parts — no `ar_status`/`free_scan_used`, so those
///    default to "approved"/spent ([fromCustomerJson]);
///  * the **seller** parts endpoint (`GET /seller/products/{id}/ar-parts`)
///    carries the full per-part state the seller manages ([fromSellerJson]).
class ArPart extends Equatable {
  const ArPart({
    required this.id,
    this.partKey = 'single',
    required this.label,
    this.arStatus = 'approved',
    this.arModelUrl,
    this.usdzUrl,
    this.arModelBytes,
    this.arUsdzBytes,
    this.isArVisible = true,
    this.freeScanUsed = false,
    this.arErrorReason,
    this.widthCm,
    this.heightCm,
    this.depthCm,
  });

  final String id;

  /// Stable component key the backend keys the part by ('bed', 'wardrobe',
  /// 'single', …). Only meaningful on the seller side.
  final String partKey;

  /// Human label shown in the seller list + the customer viewer's part toggle.
  final String label;

  /// Per-part pipeline state: `none | processing | approved | failed`. Customer
  /// parts are always `approved` (the backend only sends visible+approved ones).
  final String arStatus;

  final String? arModelUrl;
  final String? usdzUrl;
  final int? arModelBytes;
  final int? arUsdzBytes;

  /// Seller-controlled customer visibility (the eye toggle).
  final bool isArVisible;

  /// True once this part's free scan is spent — the seller is warned that a
  /// rescan costs an AR token.
  final bool freeScanUsed;

  /// Machine failure reason set when [arStatus] is `failed`.
  final String? arErrorReason;

  final num? widthCm;
  final num? heightCm;
  final num? depthCm;

  /// True when a generated model is available to render (approved + a URL).
  bool get hasModel => (arModelUrl?.isNotEmpty ?? false) && arStatus == 'approved';

  /// True while this part's model is generating.
  bool get isProcessing => arStatus == 'processing';

  /// True when the last generation failed.
  bool get isFailed => arStatus == 'failed';

  ArPart copyWith({String? arStatus, bool? isArVisible, bool? freeScanUsed}) =>
      ArPart(
        id: id,
        partKey: partKey,
        label: label,
        arStatus: arStatus ?? this.arStatus,
        arModelUrl: arModelUrl,
        usdzUrl: usdzUrl,
        arModelBytes: arModelBytes,
        arUsdzBytes: arUsdzBytes,
        isArVisible: isArVisible ?? this.isArVisible,
        freeScanUsed: freeScanUsed ?? this.freeScanUsed,
        arErrorReason: arErrorReason,
        widthCm: widthCm,
        heightCm: heightCm,
        depthCm: depthCm,
      );

  /// Buyer-side: a row of the product detail's `ar_parts[]` (always approved +
  /// visible — only those are surfaced server-side).
  factory ArPart.fromCustomerJson(Map<String, dynamic> json) => ArPart(
    id: json['id'] as String,
    label: (json['label'] as String?)?.trim().isNotEmpty == true
        ? (json['label'] as String).trim()
        : 'Asosiy',
    arStatus: 'approved',
    arModelUrl: (json['ar_model_url'] as String?)?.trim().isNotEmpty == true
        ? (json['ar_model_url'] as String).trim()
        : null,
    usdzUrl: (json['ar_usdz_url'] as String?)?.trim().isNotEmpty == true
        ? (json['ar_usdz_url'] as String).trim()
        : null,
    arModelBytes: (json['ar_model_bytes'] as num?)?.toInt(),
    arUsdzBytes: (json['ar_usdz_bytes'] as num?)?.toInt(),
    widthCm: json['width_cm'] as num?,
    heightCm: json['height_cm'] as num?,
    depthCm: json['depth_cm'] as num?,
  );

  /// Seller-side: a row of `GET /seller/products/{id}/ar-parts` carrying the
  /// full per-part state the seller manages.
  factory ArPart.fromSellerJson(Map<String, dynamic> json) => ArPart(
    id: json['id'] as String,
    partKey: (json['part_key'] as String?) ?? 'single',
    label: (json['label'] as String?)?.trim().isNotEmpty == true
        ? (json['label'] as String).trim()
        : 'Asosiy',
    arStatus: (json['ar_status'] as String?) ?? 'none',
    arModelUrl: (json['ar_model_url'] as String?)?.trim().isNotEmpty == true
        ? (json['ar_model_url'] as String).trim()
        : null,
    usdzUrl: (json['ar_usdz_url'] as String?)?.trim().isNotEmpty == true
        ? (json['ar_usdz_url'] as String).trim()
        : null,
    arModelBytes: (json['ar_model_bytes'] as num?)?.toInt(),
    arUsdzBytes: (json['ar_usdz_bytes'] as num?)?.toInt(),
    isArVisible: json['is_ar_visible'] as bool? ?? true,
    freeScanUsed: json['free_scan_used'] as bool? ?? false,
    arErrorReason: json['ar_error_reason'] as String?,
    widthCm: json['width_cm'] as num?,
    heightCm: json['height_cm'] as num?,
    depthCm: json['depth_cm'] as num?,
  );

  Map<String, dynamic> toCustomerJson() => {
    'id': id,
    'label': label,
    if (arModelUrl != null) 'ar_model_url': arModelUrl,
    if (usdzUrl != null) 'ar_usdz_url': usdzUrl,
    if (arModelBytes != null) 'ar_model_bytes': arModelBytes,
    if (arUsdzBytes != null) 'ar_usdz_bytes': arUsdzBytes,
    if (widthCm != null) 'width_cm': widthCm,
    if (heightCm != null) 'height_cm': heightCm,
    if (depthCm != null) 'depth_cm': depthCm,
  };

  @override
  List<Object?> get props => [id, label, arStatus, arModelUrl, isArVisible, freeScanUsed];
}

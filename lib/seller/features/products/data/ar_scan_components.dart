import '../../../../shared/models/attribute_definition.dart';
import '../../../../shared/models/seller_product.dart';
import '../widgets/product_form/dimensions_card.dart';

/// One furniture piece offered for a 3D scan, with the real-world dimensions
/// (cm) pulled straight from the product so the seller never re-types them.
///
/// [lengthCm] is the front-to-back axis the backend persists as **depth**
/// (`/ar-scan/photos` maps `length_cm` → `products.depth_cm`): a piece's depth
/// when it has one (a wardrobe), else its length (a bed's length is its
/// footprint depth). Any axis may be null when the seller left that dimension
/// blank — [isComplete] gates whether the piece can actually be scanned, since
/// the backend requires all three to be present and positive.
class ArScanComponent {
  const ArScanComponent({
    required this.label,
    this.heightCm,
    this.widthCm,
    this.lengthCm,
  });

  final String label;
  final int? heightCm;
  final int? widthCm;
  final int? lengthCm;

  bool get isComplete =>
      (heightCm ?? 0) > 0 && (widthCm ?? 0) > 0 && (lengthCm ?? 0) > 0;

  /// Compact "200 × 90 × 210 sm" summary; missing axes show as a dash so an
  /// incomplete piece reads clearly in the picker.
  String get summary {
    String f(int? v) => (v ?? 0) > 0 ? '$v' : '—';
    return '${f(widthCm)} × ${f(heightCm)} × ${f(lengthCm)} sm';
  }
}

/// Resolves the scannable furniture pieces for a product from its dimension
/// data, newest-first preference: the per-piece set attributes
/// (`bed_*`/`wardrobe_*`/`dresser_*`, recognised by the same "Piece — measure"
/// convention the dimensions form uses) when present, otherwise a single piece
/// built from the typed width/height/length columns with the bare `*_cm`
/// attributes as a fallback.
///
/// Returns an empty list when the product carries no dimension data at all —
/// the caller surfaces that as "add dimensions first" rather than firing a
/// scan the backend would 422.
List<ArScanComponent> resolveArScanComponents({
  required List<AttributeDefinition> schema,
  required SellerProduct product,
  String locale = 'uz',
}) {
  // --- Per-piece set dimensions ("Krovat — uzunligi", "Shkaf — chuqurligi"). --
  final order = <String>[];
  final axesByPiece = <String, Map<String, int>>{};
  for (final def in schema) {
    if (!DimensionsCard.isDimensionAttribute(def)) continue;
    final axis = _axisOf(def.key);
    if (axis == null) continue;
    final piece = DimensionsCard.pieceLabel(def, locale);
    final bucket = axesByPiece.putIfAbsent(piece, () {
      order.add(piece);
      return <String, int>{};
    });
    final value = _positiveInt(product.attributes[def.key]);
    if (value != null) bucket[axis] = value;
  }
  if (order.isNotEmpty) {
    // Keep pieces that have at least one real measurement; a piece with no
    // values at all (schema-defined but never filled) isn't worth listing.
    return [
      for (final piece in order)
        if (axesByPiece[piece]!.isNotEmpty)
          _componentFrom(piece, axesByPiece[piece]!),
    ];
  }

  // --- Single product: typed columns first, then bare dimension attributes. ---
  final height = _firstPositive([
    product.heightCm,
    product.attributes['height_cm'],
  ]);
  final width = _firstPositive([
    product.widthCm,
    product.attributes['width_cm'],
  ]);
  final length = _firstPositive([
    product.lengthCm,
    product.attributes['depth_cm'],
    product.attributes['length_cm'],
    product.attributes['set_length_cm'],
  ]);
  if (height == null && width == null && length == null) return const [];
  return [
    ArScanComponent(
      label: product.name.get(locale),
      heightCm: height,
      widthCm: width,
      lengthCm: length,
    ),
  ];
}

ArScanComponent _componentFrom(String label, Map<String, int> axes) {
  return ArScanComponent(
    label: label,
    heightCm: axes['height'],
    widthCm: axes['width'],
    // The backend's length_cm IS depth — prefer a real depth, fall back to the
    // length axis (a bed declares length, not depth, but it's the same footprint).
    lengthCm: axes['depth'] ?? axes['length'],
  );
}

/// Classifies a dimension attribute key by its measured axis. Keys are suffixed
/// `*_height_cm` / `*_width_cm` / `*_depth_cm` / `*_length_cm` (set pieces) or
/// the bare forms for single products.
String? _axisOf(String key) {
  if (key.endsWith('height_cm')) return 'height';
  if (key.endsWith('width_cm')) return 'width';
  if (key.endsWith('depth_cm')) return 'depth';
  if (key.endsWith('length_cm')) return 'length';
  return null;
}

int? _positiveInt(dynamic value) {
  if (value == null) return null;
  final n = value is num
      ? value
      : num.tryParse(value.toString().trim().replaceAll(',', '.'));
  if (n == null) return null;
  final rounded = n.round();
  return rounded > 0 ? rounded : null;
}

int? _firstPositive(List<dynamic> values) {
  for (final value in values) {
    final parsed = _positiveInt(value);
    if (parsed != null) return parsed;
  }
  return null;
}

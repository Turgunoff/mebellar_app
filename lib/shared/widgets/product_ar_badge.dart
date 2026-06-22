import 'package:flutter/material.dart';

/// Compact "3D / AR available" badge overlaid on a product image when the item
/// has a QC-approved AR model.
///
/// Deliberately self-contained (`black54` + white icon) so it reads identically
/// in the customer and seller themes, independent of the active token bag. Cards
/// place it at the bottom-left of the image, where it never collides with the
/// discount chip (top-left) or the favourite heart (top-right).
class ProductArBadge extends StatelessWidget {
  const ProductArBadge({super.key, this.compact = false});

  /// Smaller variant for tight thumbnails (e.g. the seller list's 76px tile).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 4 : 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(compact ? 7 : 9),
      ),
      child: Icon(
        Icons.view_in_ar,
        size: compact ? 13 : 16,
        color: Colors.white,
      ),
    );
  }
}

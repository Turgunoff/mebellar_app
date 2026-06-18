import 'package:flutter/material.dart';

/// Payme brand mark. Rendered as a styled wordmark (no bundled logo asset) in
/// the Payme turquoise so the add-card form carries the required Payme branding
/// without shipping a third-party image.
class PaymeBadge extends StatelessWidget {
  const PaymeBadge({super.key, this.height = 40});

  /// Payme brand turquoise.
  static const Color brand = Color(0xFF33B0B9);

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.45),
      decoration: BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(height * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        'Payme',
        style: TextStyle(
          color: Colors.white,
          fontSize: height * 0.45,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

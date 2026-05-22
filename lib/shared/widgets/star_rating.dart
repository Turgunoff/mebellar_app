import 'package:flutter/material.dart';

/// Reusable 5-star rating control.
///
/// Read-only when [onChanged] is `null`; tappable (tap a star to set the
/// score 1–5) when a callback is supplied. [rating] is a `double` so the
/// same widget renders fractional averages (e.g. 4.5) with a half star.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 22,
    this.spacing = 2,
  });

  final double rating;
  final ValueChanged<int>? onChanged;
  final double size;
  final double spacing;

  static const Color _filled = Color(0xFFF5A623);
  static const Color _empty = Color(0xFFE2E2E2);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: EdgeInsets.only(right: i < 5 ? spacing : 0),
            child: GestureDetector(
              onTap: onChanged == null ? null : () => onChanged!(i),
              behavior: HitTestBehavior.opaque,
              child: Icon(
                rating >= i
                    ? Icons.star_rounded
                    : (rating >= i - 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_rounded),
                size: size,
                color: rating >= i - 0.5 ? _filled : _empty,
              ),
            ),
          ),
      ],
    );
  }
}

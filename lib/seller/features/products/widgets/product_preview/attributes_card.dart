import 'package:flutter/material.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Key/value attribute rows inside a single bordered shell.
class AttributesCard extends StatelessWidget {
  const AttributesCard({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Xususiyatlar'),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kGrey,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                        height: 1.3,
                        letterSpacing: -0.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, thickness: 1, color: kDivider),
          ],
        ],
      ),
    );
  }
}

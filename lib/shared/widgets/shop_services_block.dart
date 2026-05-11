import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../models/shop_service.dart';

/// Chip list for shop-offered services (free delivery, assembly, ...).
/// Shown on product detail and the shop page. Renders nothing when the list
/// is empty so callers don't need to guard.
class ShopServicesBlock extends StatelessWidget {
  const ShopServicesBlock({
    super.key,
    required this.services,
    this.title,
    this.dense = false,
  });

  final List<ShopService> services;
  final String? title;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title ?? tr('shop.services'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: dense ? 8 : 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final svc in services)
              Chip(
                visualDensity: dense ? VisualDensity.compact : null,
                avatar: Icon(svc.icon, size: 18, color: scheme.primary),
                label: Text(svc.title(lang)),
                backgroundColor: scheme.primaryContainer.withValues(alpha: 0.3),
                side: BorderSide(color: scheme.outlineVariant),
              ),
          ],
        ),
      ],
    );
  }
}

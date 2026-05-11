import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/tariff.dart';
import '../../tariff/screens/tariff_screen.dart';

/// Tariff guard dialog. Sprint 7 introduced the dialog with a snackbar
/// placeholder; Sprint 9 routes the CTA into the real `TariffScreen`
/// upgrade flow.
Future<void> showTariffLimitDialog(
  BuildContext context, {
  required TariffSnapshot snapshot,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.lock_outline,
          color: Theme.of(ctx).colorScheme.primary, size: 36),
      title: Text(tr('tariff.limit_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('tariff.limit_subtitle', args: [
              '${snapshot.activeProductsCount}',
              snapshot.plan.isUnlimited ? 'в€ћ' : '${snapshot.plan.maxActiveProducts}',
            ]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            tr('tariff.upgrade_hint'),
            textAlign: TextAlign.center,
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr('common.close')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TariffScreen()),
            );
          },
          child: Text(tr('tariff.upgrade_cta')),
        ),
      ],
    ),
  );
}

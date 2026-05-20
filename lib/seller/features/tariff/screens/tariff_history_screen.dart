import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/tariff_bloc.dart';

class TariffHistoryScreen extends StatelessWidget {
  const TariffHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TariffBloc(sl<TariffRepository>())
        ..add(const TariffRequested()),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('tariff.history'))),
      body: BlocBuilder<TariffBloc, TariffState>(
        builder: (context, state) {
          return switch (state.status) {
            TariffStatus.initial ||
            TariffStatus.loading =>
              const Center(child: BrandLoadingIndicator()),
            TariffStatus.failure when state.history.isEmpty => ErrorState(
                message: state.error,
                onRetry: () =>
                    context.read<TariffBloc>().add(const TariffRequested()),
              ),
            _ => state.history.isEmpty
                ? EmptyState(
                    icon: Icons.history,
                    title: tr('tariff.history_empty'),
                    message: tr('tariff.history_empty_hint'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _HistoryTile(subscription: state.history[i]),
                  ),
          };
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.subscription});
  final TariffSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final priceFormat = NumberFormat('#,###', lang);
    final dateFmt = DateFormat('dd MMM yyyy', lang);
    final scheme = Theme.of(context).colorScheme;
    final palette = _palette(scheme, subscription.status);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('tariff.plan.${subscription.plan.code}_label'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tr('tariff.upgrade_status.${subscription.status.code}'),
                    style: TextStyle(
                      color: palette.fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('tariff.period_${subscription.period.code}'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${priceFormat.format(subscription.amount)} so\'m',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  dateFmt.format(subscription.submittedAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (subscription.expiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                tr('tariff.expires_at',
                    args: [dateFmt.format(subscription.expiresAt!.toLocal())]),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
              ),
            ],
            if (subscription.rejectionReason != null) ...[
              const SizedBox(height: 6),
              Text(
                subscription.rejectionReason!,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({Color bg, Color fg}) _palette(ColorScheme s, TariffUpgradeStatus status) {
    return switch (status) {
      TariffUpgradeStatus.none => (
          bg: s.surfaceContainerHighest,
          fg: s.onSurface,
        ),
      TariffUpgradeStatus.pending => (
          bg: s.tertiaryContainer,
          fg: s.onTertiaryContainer,
        ),
      TariffUpgradeStatus.approved => (
          bg: const Color(0xFFDCEFDC),
          fg: const Color(0xFF1B5E20),
        ),
      TariffUpgradeStatus.rejected => (
          bg: s.errorContainer,
          fg: s.onErrorContainer,
        ),
      TariffUpgradeStatus.cancelled => (
          bg: s.surfaceContainer,
          fg: s.outline,
        ),
    };
  }
}

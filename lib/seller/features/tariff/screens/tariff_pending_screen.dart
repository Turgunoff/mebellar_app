import 'dart:async';

import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../bloc/tariff_bloc.dart';
import 'tariff_history_screen.dart';

/// "To'lov tasdiqlash kutilmoqda" page. Shows the SLA countdown, the plan
/// being purchased, and routes the user to History or back to the catalog.
/// When the mock admin flips status (12s), TariffBloc'tagi watchPending
/// stream banner'ni yangilaydi va biz approved/rejected dialog ko'rsatamiz.
class TariffPendingScreen extends StatelessWidget {
  const TariffPendingScreen({super.key, required this.subscription});

  final TariffSubscription subscription;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TariffBloc(sl<TariffRepository>())
        ..add(const TariffRequested()),
      child: _PendingView(initial: subscription),
    );
  }
}

class _PendingView extends StatefulWidget {
  const _PendingView({required this.initial});
  final TariffSubscription initial;

  @override
  State<_PendingView> createState() => _PendingViewState();
}

class _PendingViewState extends State<_PendingView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 1-second ticker drives the countdown label so the SLA window feels live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _confirmCancel(TariffSubscription subscription) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('tariff.cancel_title')),
        content: Text(tr('tariff.cancel_subtitle')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('common.back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(tr('orders.cancel')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await sl<TariffRepository>().cancelPending(subscription.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TariffBloc, TariffState>(
      listenWhen: (a, b) {
        // Resolution detection вЂ” same idea as the catalog screen, but here we
        // also need to react to mid-screen approval/rejection by surfacing a
        // dialog the user can dismiss.
        final wasPending = (a.pending?.id == widget.initial.id) &&
            (a.pending?.status.isPending ?? false);
        final nowResolved = wasPending &&
            (b.pending == null ||
                b.pending!.id != widget.initial.id ||
                !b.pending!.status.isPending);
        return nowResolved;
      },
      listener: (context, state) async {
        // Pull the most-recent record for this id from history (admin
        // already finalised it).
        final history = state.history;
        final resolved = history.firstWhere(
          (s) => s.id == widget.initial.id,
          orElse: () => widget.initial,
        );
        final navigator = Navigator.of(context);
        await _showResolutionDialog(context, resolved);
        if (!mounted) return;
        navigator.pop();
      },
      builder: (context, state) {
        // Prefer the live snapshot from the bloc (admin may have flipped it
        // even before this screen opened).
        final live = (state.pending?.id == widget.initial.id)
            ? state.pending!
            : state.history.firstWhere(
                (s) => s.id == widget.initial.id,
                orElse: () => widget.initial,
              );
        return Scaffold(
          appBar: AppBar(title: Text(tr('tariff.pending_title'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_top_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('tariff.pending_headline'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                tr('tariff.pending_subtitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              _SlaCard(subscription: live),
              const SizedBox(height: 16),
              _SubscriptionSummary(subscription: live),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TariffHistoryScreen(),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: Text(tr('tariff.history')),
              ),
              const SizedBox(height: 8),
              if (live.status.isPending)
                TextButton.icon(
                  onPressed: () => _confirmCancel(live),
                  icon: Icon(Icons.cancel_outlined,
                      color: Theme.of(context).colorScheme.error),
                  label: Text(
                    tr('tariff.cancel_request'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showResolutionDialog(
    BuildContext context,
    TariffSubscription resolved,
  ) async {
    if (!context.mounted) return;
    final approved = resolved.status.isApproved;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          approved ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 36,
          color: approved
              ? Colors.green
              : Theme.of(ctx).colorScheme.error,
        ),
        title: Text(approved
            ? tr('tariff.approved_title')
            : tr('tariff.rejected_title')),
        content: Text(approved
            ? tr('tariff.approved_subtitle',
                args: [tr('tariff.plan.${resolved.plan.code}_label')])
            : (resolved.rejectionReason ?? tr('tariff.rejected_subtitle'))),
        actions: [
          if (!approved)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('tariff.try_again')),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common.ok')),
          ),
        ],
      ),
    );
  }
}

class _SlaCard extends StatelessWidget {
  const _SlaCard({required this.subscription});
  final TariffSubscription subscription;

  String _formatRemaining(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              tr('tariff.sla_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _formatRemaining(subscription.slaRemaining),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('tariff.submitted_at', args: [
                DateFormat('dd MMM, HH:mm', lang)
                    .format(subscription.submittedAt.toLocal())
              ]),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionSummary extends StatelessWidget {
  const _SubscriptionSummary({required this.subscription});
  final TariffSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final priceFormat = NumberFormat('#,###', lang);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(tr('tariff.plan.${subscription.plan.code}_label')),
            subtitle: Text(tr('tariff.period_${subscription.period.code}')),
            trailing: Text(
              '${priceFormat.format(subscription.amount)} so\'m',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              tr('tariff.current_remains'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

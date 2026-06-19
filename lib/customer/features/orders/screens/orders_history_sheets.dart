part of 'orders_history_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cancellation reason picker — style + labels for the shared sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Maps the customer [PremiumTokens] bag onto the shared cancel-reason sheet.
/// The cancel context is destructive, so the selection accent is the danger
/// red (matching the old hardcoded sheet), not the brand terracotta.
CancelReasonStyle _customerCancelStyle(BuildContext context, PremiumTokens pt) {
  final danger = Theme.of(context).colorScheme.error;
  return CancelReasonStyle(
    surface: pt.surface,
    ink: pt.dark,
    muted: pt.grey,
    border: pt.divider,
    field: pt.background,
    accent: danger,
    danger: danger,
    fontFamily: AppFonts.body,
  );
}

/// Localised chrome for the cancel-reason sheet. Reason titles themselves come
/// from the backend already localised; these are the surrounding labels.
CancelReasonLabels _cancelReasonLabels() => CancelReasonLabels(
  title: tr('orders.cancel_title'),
  subtitle: tr('orders.cancel_pick_subtitle'),
  otherHint: tr('orders.cancel_other_hint'),
  confirm: tr('orders.cancel'),
  otherRequired: tr('orders.cancel_other_required'),
  loadError: tr('orders.cancel_load_error'),
);

// ─────────────────────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a centred widget in an always-scrollable viewport so pull-to-refresh
/// still works when the list has no rows to show.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.pt});

  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: PremiumTokens.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.receipt,
                size: 42,
                color: PremiumTokens.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Hali buyurtmalar yo\'q',
              textAlign: TextAlign.center,
              style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
            ),
            const SizedBox(height: 10),
            Text(
              'Birinchi buyurtmangizni berganingizdan so\'ng, '
              'u shu yerda ko\'rinadi.',
              textAlign: TextAlign.center,
              style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterEmpty extends StatelessWidget {
  const _FilterEmpty({required this.pt, required this.filter});

  final PremiumTokens pt;
  final _OrderFilter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: pt.imageBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.box_search, size: 28, color: pt.greyLight),
            ),
            const SizedBox(height: 16),
            Text(
              '"${filter.label}" bo\'limida buyurtma yo\'q',
              textAlign: TextAlign.center,
              style: PremiumTokens.body(
                size: 14,
                weight: FontWeight.w600,
                color: pt.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatters
// ─────────────────────────────────────────────────────────────────────────────

const _uzMonths = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avgust',
  'sentabr',
  'oktabr',
  'noyabr',
  'dekabr',
];

/// `2026-05-21T15:32:00Z` → `21-may 2026, 15:32` (local time, Uzbek month).
String _fmtDate(String? raw) {
  if (raw == null) return '—';
  final d = DateTime.tryParse(raw)?.toLocal();
  if (d == null) return '—';
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day}-${_uzMonths[d.month - 1]} ${d.year}, $hh:$mm';
}

/// `7155555` → `7 155 555` (space-grouped, Uzbek convention).
String _fmtPrice(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

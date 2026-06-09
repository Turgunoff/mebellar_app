part of 'orders_history_screen.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Cancellation bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CancellationSheet extends StatefulWidget {
  const _CancellationSheet({required this.pt});

  final PremiumTokens pt;

  @override
  State<_CancellationSheet> createState() => _CancellationSheetState();
}

class _CancellationSheetState extends State<_CancellationSheet> {
  static const _reasons = [
    'Fikrimdan qaytdim',
    'Manzilni xato kiritdim',
    'Boshqa mebel topdim',
    'Kutish vaqti juda uzoq',
    'Boshqa',
  ];

  String? _selected;

  @override
  Widget build(BuildContext context) {
    final pt = widget.pt;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: pt.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.close_circle,
                  size: 20,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Buyurtmani bekor qilish',
                style: PremiumTokens.display(size: 18, letterSpacing: -0.3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Text(
              'Bekor qilish sababini tanlang',
              style: PremiumTokens.body(size: 13, color: pt.grey),
            ),
          ),
          const SizedBox(height: 20),
          ..._reasons.map(
            (reason) => _ReasonRow(
              reason: reason,
              selected: _selected == reason,
              pt: pt,
              onTap: () => setState(() => _selected = reason),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                disabledBackgroundColor: const Color(
                  0xFFDC2626,
                ).withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Bekor qilishni tasdiqlash',
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.pt,
    required this.onTap,
  });

  final String reason;
  final bool selected;
  final PremiumTokens pt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFDC2626).withValues(alpha: 0.06)
              : pt.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                : pt.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason,
                style: PremiumTokens.body(
                  size: 14,
                  weight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? const Color(0xFFDC2626) : pt.dark,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFFDC2626) : pt.greyLight,
                  width: selected ? 5.5 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

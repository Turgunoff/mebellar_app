import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/repositories/payment_cards_repository.dart';
import '../data/ar_token_repository.dart';

/// Opens the AR-token top-up sheet. Returns `true` when a purchase succeeded so
/// the caller can refresh the balance + re-enable the scan CTA.
Future<bool> showArTokenBuySheet(
  BuildContext context, {
  required List<ArTokenPackage> packages,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ArTokenBuySheet(packages: packages),
  );
  return ok ?? false;
}

String _fmtUzs(int value) {
  final digits = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${buf.toString()} so‘m';
}

class _ArTokenBuySheet extends StatefulWidget {
  const _ArTokenBuySheet({required this.packages});

  final List<ArTokenPackage> packages;

  @override
  State<_ArTokenBuySheet> createState() => _ArTokenBuySheetState();
}

class _ArTokenBuySheetState extends State<_ArTokenBuySheet> {
  late Future<List<SavedCard>> _cardsFuture;
  String? _packageCode;
  String? _cardId;
  bool _buying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cardsFuture = sl<PaymentCardsRepository>().list();
    // Default to the middle/most-popular package when present, else the first.
    if (widget.packages.isNotEmpty) {
      final mid = widget.packages.length ~/ 2;
      _packageCode = widget.packages[mid].code;
    }
  }

  Future<void> _buy() async {
    final pkg = _packageCode;
    final card = _cardId;
    if (pkg == null || card == null || _buying) return;
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final result = await sl<ArTokenRepository>().buy(
        packageCode: pkg,
        cardId: card,
      );
      if (mounted) Navigator.of(context).pop(true);
      // Surface the new balance to the caller via a snackbar after the pop.
      _result = result;
    } catch (_) {
      if (mounted) {
        setState(() {
          _buying = false;
          _error = 'To‘lov amalga oshmadi. Boshqa karta bilan urinib ko‘ring.';
        });
      }
    }
  }

  // Carried out so the caller's context can show the confirmation toast.
  static ArTokenPurchaseResult? _result;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.terracotta, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'AR Token sotib olish',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Har bir 3D model yaratish 1 token sarflaydi.',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12.5,
                  color: c.grey,
                ),
              ),
              const SizedBox(height: 16),

              // ── Package picker ──
              for (final pkg in widget.packages)
                _PackageTile(
                  pkg: pkg,
                  selected: pkg.code == _packageCode,
                  onTap: () => setState(() => _packageCode = pkg.code),
                ),
              const SizedBox(height: 16),

              // ── Saved-card picker ──
              Text(
                'To‘lov kartasi',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<SavedCard>>(
                future: _cardsFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    );
                  }
                  final cards = snap.data ?? const <SavedCard>[];
                  if (cards.isEmpty) {
                    return _EmptyCards(color: c);
                  }
                  // Auto-select the first card once loaded.
                  _cardId ??= cards.first.id;
                  return Column(
                    children: [
                      for (final card in cards)
                        _CardTile(
                          card: card,
                          selected: card.id == _cardId,
                          onTap: () => setState(() => _cardId = card.id),
                        ),
                    ],
                  );
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12.5,
                    color: AppColors.sellerNegative,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_packageCode != null && _cardId != null && !_buying)
                      ? _buy
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    disabledBackgroundColor: AppColors.terracotta.withValues(
                      alpha: 0.4,
                    ),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  child: _buying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sotib olish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulls the last purchase result back out (set just before the sheet pops) so
/// the caller can show a "+N token" confirmation. Returns null when none.
ArTokenPurchaseResult? takeLastArTokenPurchase() {
  final r = _ArTokenBuySheetState._result;
  _ArTokenBuySheetState._result = null;
  return r;
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.pkg,
    required this.selected,
    required this.onTap,
  });

  final ArTokenPackage pkg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.terracotta.withValues(alpha: 0.08)
            : c.fillFaint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.terracotta : c.divider,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.terracotta : c.greyFaint,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${pkg.tokens} token',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: c.ink,
                    ),
                  ),
                ),
                Text(
                  _fmtUzs(pkg.priceUzs),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: c.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final SavedCard card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.fillFaint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.terracotta : c.divider,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.credit_card, color: c.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    card.maskedNumber,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: c.ink,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.terracotta,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.color});
  final SellerColors color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.fillFaint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Saqlangan karta yo‘q. Profil → To‘lov kartalari bo‘limidan karta '
        'qo‘shing, so‘ng token sotib oling.',
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 12.5,
          color: color.grey,
          height: 1.35,
        ),
      ),
    );
  }
}

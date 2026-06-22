import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../data/ar_token_repository.dart';

/// Official provider brand colours for the top-up tiles.
const Color _kPaymeTeal = Color(0xFF00A19A);
const Color _kClickBlue = Color(0xFF0073FF);

/// Opens the AR-token top-up sheet. Returns `true` when a checkout deep-link was
/// launched so the caller can refresh + remind the seller to finish paying.
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
  String? _packageCode;
  PaymentProvider _provider = PaymentProvider.payme;
  bool _buying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to the middle/most-popular package when present, else the first.
    if (widget.packages.isNotEmpty) {
      final mid = widget.packages.length ~/ 2;
      _packageCode = widget.packages[mid].code;
    }
  }

  Future<void> _pay() async {
    final pkg = _packageCode;
    if (pkg == null || _buying) return;
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final url = await sl<ArTokenRepository>().buy(
        packageCode: pkg,
        provider: _provider,
      );
      final uri = Uri.tryParse(url);
      if (uri != null && url.isNotEmpty) {
        // externalApplication forces the OS to open the Payme/Click app.
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _buying = false;
          _error = 'To‘lovni boshlab bo‘lmadi. Birozdan so‘ng urinib ko‘ring.';
        });
      }
    }
  }

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
                  Icon(Icons.bolt_rounded, color: c.gold, size: 22),
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

              // ── Payment app picker ──
              Text(
                'To‘lov usuli',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8),
              _ProviderChoice(
                brand: _kPaymeTeal,
                wordmark: 'Payme',
                label: 'Payme ilovasi orqali to‘lash',
                selected: _provider == PaymentProvider.payme,
                onTap: () => setState(() => _provider = PaymentProvider.payme),
              ),
              const SizedBox(height: 8),
              _ProviderChoice(
                brand: _kClickBlue,
                wordmark: 'Click',
                label: 'Click ilovasi orqali to‘lash',
                selected: _provider == PaymentProvider.click,
                onTap: () => setState(() => _provider = PaymentProvider.click),
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
                  onPressed: (_packageCode != null && !_buying) ? _pay : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primary,
                    disabledBackgroundColor: c.primary.withValues(alpha: 0.4),
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
                      : const Text('To‘lash'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        color: selected ? c.primary.withValues(alpha: 0.08) : c.fillFaint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? c.primary : c.divider,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? c.primary : c.greyFaint,
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

/// A branded payment-app choice (logo placeholder wordmark + label + ring).
class _ProviderChoice extends StatelessWidget {
  const _ProviderChoice({
    required this.brand,
    required this.wordmark,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color brand;
  final String wordmark;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? brand.withValues(alpha: 0.08) : c.fillFaint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? brand : c.divider,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                // Logo placeholder — the provider wordmark on its brand colour.
                Container(
                  width: 54,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brand,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    wordmark,
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: c.ink,
                    ),
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: brand, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

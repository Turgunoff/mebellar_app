import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/remote_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/pending_payment_service.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/utils/image_upload.dart';
import '../data/ar_token_repository.dart';

/// Official provider brand colours for the top-up tiles.
const Color _kPaymeTeal = Color(0xFF00A19A);
const Color _kClickBlue = Color(0xFF0073FF);

enum ArTokenBuyResult { onlineLaunched, manualSubmitted }

/// Opens the AR-token top-up sheet. Returns how the seller chose to pay so the
/// caller can refresh + show the right follow-up snackbar.
Future<ArTokenBuyResult?> showArTokenBuySheet(
  BuildContext context, {
  required List<ArTokenPackage> packages,
}) async {
  return showModalBottomSheet<ArTokenBuyResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ArTokenBuySheet(packages: packages),
  );
}

String _fmtUzs(int value) {
  final digits = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return tr('common.uzs_amount', namedArgs: {'amount': buf.toString()});
}

class _ArTokenBuySheet extends StatefulWidget {
  const _ArTokenBuySheet({required this.packages});

  final List<ArTokenPackage> packages;

  @override
  State<_ArTokenBuySheet> createState() => _ArTokenBuySheetState();
}

class _ArTokenBuySheetState extends State<_ArTokenBuySheet> {
  String? _packageCode;
  late PaymentProvider _provider;
  bool _buyingOnline = false;
  bool _submittingManual = false;
  String? _error;
  late Future<TariffPaymentInstructions> _instructions;
  File? _screenshotFile;

  bool get _anyProviderEnabled =>
      RemoteConfig.instance.paymeEnabled || RemoteConfig.instance.clickEnabled;

  ArTokenPackage? get _selectedPackage {
    final code = _packageCode;
    if (code == null) return null;
    for (final pkg in widget.packages) {
      if (pkg.code == code) return pkg;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.packages.isNotEmpty) {
      final mid = widget.packages.length ~/ 2;
      _packageCode = widget.packages[mid].code;
    }
    _provider = RemoteConfig.instance.paymeEnabled
        ? PaymentProvider.payme
        : (RemoteConfig.instance.clickEnabled
              ? PaymentProvider.click
              : PaymentProvider.payme);
    _instructions = sl<ArTokenRepository>().paymentInstructions();
  }

  Future<void> _payOnline() async {
    final pkg = _packageCode;
    if (pkg == null || _buyingOnline || _submittingManual) return;
    setState(() {
      _buyingOnline = true;
      _error = null;
    });
    try {
      final checkout = await sl<ArTokenRepository>().buy(
        packageCode: pkg,
        provider: _provider,
      );
      final reference = checkout.reference;
      if (reference != null &&
          reference.isNotEmpty &&
          sl.isRegistered<PendingPaymentService>()) {
        await sl<PendingPaymentService>().mark(
          kind: PendingPaymentKind.arTokens,
          reference: reference,
        );
      }
      final uri = Uri.tryParse(checkout.url);
      if (uri != null && checkout.url.isNotEmpty) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.of(context).pop(ArTokenBuyResult.onlineLaunched);
    } catch (_) {
      if (mounted) {
        setState(() {
          _buyingOnline = false;
          _error = tr('seller.ar_buy_checkout_failed');
        });
      }
    }
  }

  Future<void> _copyCard(String number) async {
    await Clipboard.setData(ClipboardData(text: number.replaceAll(' ', '')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('tariff.card_copied'))));
  }

  Future<void> _copyNote(String note) async {
    await Clipboard.setData(ClipboardData(text: note));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('tariff.note_copied'))));
  }

  Future<void> _pickScreenshot() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImageUploadHelper().pick(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      setState(() => _screenshotFile = picked.file);
    } on ImagePickError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submitManual() async {
    final pkg = _packageCode;
    final file = _screenshotFile;
    if (pkg == null || file == null || _submittingManual || _buyingOnline) {
      return;
    }
    setState(() {
      _submittingManual = true;
      _error = null;
    });
    try {
      final repo = sl<ArTokenRepository>();
      final ext = file.path.split('.').last;
      final path = await repo.uploadPaymentScreenshot(
        file: file,
        fileExtension: ext.isEmpty ? 'jpg' : ext,
      );
      await repo.submitManualPurchase(
        packageCode: pkg,
        paymentScreenshotPath: path,
      );
      if (mounted) {
        Navigator.of(context).pop(ArTokenBuyResult.manualSubmitted);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submittingManual = false;
          _error = tr('seller.ar_manual_failed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final selected = _selectedPackage;
    final busy = _buyingOnline || _submittingManual;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                    Expanded(
                      child: Text(
                        tr('seller.ar_buy_title'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tr('seller.ar_buy_subtitle'),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12.5,
                    color: c.grey,
                  ),
                ),
                const SizedBox(height: 16),
                for (final pkg in widget.packages)
                  _PackageTile(
                    pkg: pkg,
                    selected: pkg.code == _packageCode,
                    onTap: busy
                        ? null
                        : () => setState(() => _packageCode = pkg.code),
                  ),
                if (_anyProviderEnabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr('seller.payment_method'),
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (RemoteConfig.instance.paymeEnabled)
                    _ProviderChoice(
                      brand: _kPaymeTeal,
                      wordmark: 'Payme',
                      label: tr('seller.pay_via_payme'),
                      selected: _provider == PaymentProvider.payme,
                      onTap: busy
                          ? null
                          : () => setState(
                              () => _provider = PaymentProvider.payme,
                            ),
                    ),
                  if (RemoteConfig.instance.clickEnabled) ...[
                    if (RemoteConfig.instance.paymeEnabled)
                      const SizedBox(height: 8),
                    _ProviderChoice(
                      brand: _kClickBlue,
                      wordmark: 'Click',
                      label: tr('seller.pay_via_click'),
                      selected: _provider == PaymentProvider.click,
                      onTap: busy
                          ? null
                          : () => setState(
                              () => _provider = PaymentProvider.click,
                            ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_packageCode != null && !busy)
                          ? _payOnline
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        disabledBackgroundColor: c.primary.withValues(
                          alpha: 0.4,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: AppFonts.seller,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      child: _buyingOnline
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: Colors.white,
                              ),
                            )
                          : Text(tr('seller.pay_action')),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: c.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          tr('tariff.pay_or_manual'),
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 12,
                            color: c.grey,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: c.divider)),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                FutureBuilder<TariffPaymentInstructions>(
                  future: _instructions,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError || !snap.hasData) {
                      return Text(
                        tr('tariff.instructions_load_failed'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          color: AppColors.sellerNegative,
                        ),
                      );
                    }
                    final ins = snap.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (selected != null) ...[
                          Text(
                            _fmtUzs(selected.priceUzs),
                            style: TextStyle(
                              fontFamily: AppFonts.seller,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _CardBlock(
                          number: ins.cardNumber,
                          holder: ins.cardHolder,
                          bank: ins.bankName,
                          onCopy: () => _copyCard(ins.cardNumber),
                        ),
                        const SizedBox(height: 10),
                        _NoteBlock(
                          note: ins.note,
                          onCopy: () => _copyNote(ins.note),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('tariff.upload_screenshot_title'),
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('tariff.upload_screenshot_hint'),
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 12,
                            color: c.grey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _pickScreenshot,
                          icon: const Icon(Icons.image_outlined, size: 20),
                          label: Text(
                            _screenshotFile == null
                                ? tr('tariff.upload_screenshot')
                                : tr('seller.ar_manual_receipt_selected'),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(color: c.divider),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                (_screenshotFile != null &&
                                    _packageCode != null &&
                                    !busy)
                                ? _submitManual
                                : null,
                            icon: _submittingManual
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(tr('seller.ar_manual_submit')),
                            style: FilledButton.styleFrom(
                              backgroundColor: c.gold,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: c.gold.withValues(
                                alpha: 0.4,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: AppFonts.seller,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBlock extends StatelessWidget {
  const _CardBlock({
    required this.number,
    required this.holder,
    required this.bank,
    required this.onCopy,
  });

  final String number;
  final String holder;
  final String bank;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.fillFaint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  number,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: 0.5,
                    color: c.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('tariff.tap_to_copy'),
                onPressed: onCopy,
                icon: Icon(Icons.copy_outlined, color: c.gold, size: 20),
              ),
            ],
          ),
          if (holder.isNotEmpty)
            Text(
              holder,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.grey,
              ),
            ),
          if (bank.isNotEmpty)
            Text(
              bank,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                color: c.greyMid,
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.note, required this.onCopy});

  final String note;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.tag_outlined, size: 18, color: c.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: c.ink,
                  ),
                ),
                Text(
                  tr('tariff.note_hint'),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 11.5,
                    color: c.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: Icon(Icons.copy_outlined, color: c.gold, size: 18),
          ),
        ],
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
  final VoidCallback? onTap;

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
                    tr(
                      'seller.ar_token_count',
                      namedArgs: {'count': pkg.tokens.toString()},
                    ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
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
    );
  }
}

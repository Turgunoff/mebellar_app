import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/remote_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/pending_payment_service.dart';
import '../../../../shared/payments/manual_payment_pending_screen.dart';
import '../../../../shared/payments/refresh_payment_remote_config.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/utils/image_upload.dart';
import '../../../../shared/widgets/payment_provider_tile.dart';
import '../data/ar_token_repository.dart';

enum _PayMode { online, card }

/// Inline AR-token purchase block — package pick + Payme/Click or P2P card.
/// Lives on [ArTokensScreen]; no minimum amount (package price is fixed).
class ArTokenBuySection extends StatefulWidget {
  const ArTokenBuySection({
    super.key,
    required this.packages,
    required this.onOnlineLaunched,
    this.onFlowCompleted,
  });

  final List<ArTokenPackage> packages;
  final VoidCallback onOnlineLaunched;
  final VoidCallback? onFlowCompleted;

  @override
  State<ArTokenBuySection> createState() => _ArTokenBuySectionState();
}

class _ArTokenBuySectionState extends State<ArTokenBuySection> {
  String? _packageCode;
  PaymentProvider? _provider;
  _PayMode? _payMode;
  bool _buyingOnline = false;
  bool _submittingManual = false;
  String? _error;
  Future<TariffPaymentInstructions>? _instructionsFuture;
  File? _screenshotFile;

  bool get _anyProviderEnabled =>
      RemoteConfig.instance.anyOnlineProviderEnabled;

  bool get _showPayModeSwitcher => _anyProviderEnabled;

  ArTokenPackage? get _selectedPackage {
    final code = _packageCode;
    if (code == null) return null;
    for (final pkg in widget.packages) {
      if (pkg.code == code) return pkg;
    }
    return null;
  }

  bool _providerIsEnabled(PaymentProvider provider) => switch (provider) {
    PaymentProvider.payme => RemoteConfig.instance.paymeEnabled,
    PaymentProvider.click => RemoteConfig.instance.clickEnabled,
  };

  @override
  void initState() {
    super.initState();
    RemoteConfig.instance.addListener(_onPaymentRemoteConfig);
    _syncFromRemoteConfig();
    unawaited(refreshPaymentRemoteConfig());
  }

  @override
  void dispose() {
    RemoteConfig.instance.removeListener(_onPaymentRemoteConfig);
    super.dispose();
  }

  void _onPaymentRemoteConfig() {
    if (!mounted) return;
    setState(_syncFromRemoteConfig);
  }

  void _syncFromRemoteConfig() {
    if (!_anyProviderEnabled) {
      _payMode = _PayMode.card;
      _provider = null;
      _ensureInstructions();
      return;
    }
    if (_provider != null && !_providerIsEnabled(_provider!)) {
      _provider = null;
    }
  }

  void _ensureInstructions() {
    _instructionsFuture ??= sl<ArTokenRepository>().paymentInstructions();
  }

  void _selectPayMode(_PayMode mode) {
    if (_payMode == mode) return;
    setState(() {
      _payMode = mode;
      _provider = null;
      _screenshotFile = null;
      _error = null;
      if (mode == _PayMode.card) _ensureInstructions();
    });
  }

  Future<void> _payOnline() async {
    final pkg = _packageCode;
    final provider = _provider;
    if (pkg == null ||
        provider == null ||
        !_providerIsEnabled(provider) ||
        _buyingOnline ||
        _submittingManual) {
      if (pkg == null) {
        _showSnack(
          tr('seller.ar_select_package_hint'),
          tone: _SnackTone.neutral,
        );
      } else if (provider == null || !_providerIsEnabled(provider)) {
        _showSnack(
          tr('seller.wallet_select_payment_method_hint'),
          tone: _SnackTone.neutral,
        );
      }
      return;
    }
    setState(() {
      _buyingOnline = true;
      _error = null;
    });
    try {
      final checkout = await sl<ArTokenRepository>().buy(
        packageCode: pkg,
        provider: provider,
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
      if (mounted) widget.onOnlineLaunched();
    } catch (e) {
      if (mounted) {
        setState(() {
          _buyingOnline = false;
          _error = apiErrorMessage(e);
        });
      }
    } finally {
      if (mounted && _buyingOnline) {
        setState(() => _buyingOnline = false);
      }
    }
  }

  Future<void> _copyCard(String number) async {
    await Clipboard.setData(ClipboardData(text: number.replaceAll(' ', '')));
    if (!mounted) return;
    _showSnack(tr('tariff.card_copied'), tone: _SnackTone.neutral);
  }

  Future<void> _pickScreenshot() async {
    try {
      final picked = await ImageUploadHelper().pick(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      setState(() {
        _screenshotFile = picked.file;
        _error = null;
      });
    } on ImagePickError catch (e) {
      if (mounted) _showSnack(e.message, tone: _SnackTone.error);
    } catch (e) {
      if (mounted) _showSnack(e.toString(), tone: _SnackTone.error);
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
      final purchase = await repo.submitManualPurchase(
        packageCode: pkg,
        paymentScreenshotPath: path,
      );
      if (!mounted) return;
      setState(() => _screenshotFile = null);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/seller-ar-token-pending'),
          builder: (_) => ManualPaymentPendingScreen(
            args: ArTokenPurchasePendingArgs(purchase: purchase),
          ),
        ),
      );
      if (mounted) widget.onFlowCompleted?.call();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submittingManual = false;
          _error = apiErrorMessage(e);
        });
      }
    } finally {
      if (mounted && _submittingManual) {
        setState(() => _submittingManual = false);
      }
    }
  }

  void _showSnack(String message, {required _SnackTone tone}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: switch (tone) {
          _SnackTone.success => AppColors.sellerPositive,
          _SnackTone.error => AppColors.sellerNegative,
          _SnackTone.neutral => null,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final selected = _selectedPackage;
    final busy = _buyingOnline || _submittingManual;
    final canSubmitOnline =
        _packageCode != null &&
        _provider != null &&
        _providerIsEnabled(_provider!) &&
        !busy;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    fontSize: 16,
                    color: c.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tr('seller.ar_buy_subtitle'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12.5,
              color: c.grey,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          for (final pkg in widget.packages)
            _PackageTile(
              pkg: pkg,
              selected: pkg.code == _packageCode,
              onTap: busy
                  ? null
                  : () => setState(() => _packageCode = pkg.code),
            ),
          if (_packageCode == null) ...[
            const SizedBox(height: 8),
            Text(
              tr('seller.ar_select_package_hint'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.grey,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_showPayModeSwitcher) ...[
            _PayModeBar(mode: _payMode, busy: busy, onSelect: _selectPayMode),
            if (_payMode == null) ...[
              const SizedBox(height: 10),
              Text(
                tr('seller.wallet_select_pay_mode'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12.5,
                  color: c.grey,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
          if (_payMode != _PayMode.card &&
              (_showPayModeSwitcher || _anyProviderEnabled)) ...[
            Text(
              tr('seller.payment_method'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 10),
            if (RemoteConfig.instance.paymeVisible)
              PaymentProviderTile(
                provider: PaymentProvider.payme,
                label: tr('seller.pay_via_payme'),
                selected: _provider == PaymentProvider.payme,
                comingSoon: RemoteConfig.instance.paymeComingSoon,
                style: PaymentProviderTileStyle.seller,
                onTap: busy || !RemoteConfig.instance.paymeEnabled
                    ? null
                    : () => setState(() => _provider = PaymentProvider.payme),
              ),
            if (RemoteConfig.instance.paymeVisible &&
                RemoteConfig.instance.clickVisible)
              const SizedBox(height: 8),
            if (RemoteConfig.instance.clickVisible)
              PaymentProviderTile(
                provider: PaymentProvider.click,
                label: tr('seller.pay_via_click'),
                selected: _provider == PaymentProvider.click,
                comingSoon: RemoteConfig.instance.clickComingSoon,
                style: PaymentProviderTileStyle.seller,
                onTap: busy || !RemoteConfig.instance.clickEnabled
                    ? null
                    : () => setState(() => _provider = PaymentProvider.click),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: canSubmitOnline ? _payOnline : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sellerPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.sellerPrimary.withValues(
                    alpha: 0.35,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _buyingOnline
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Iconsax.wallet_add_1, size: 19),
                label: Text(
                  _buyingOnline
                      ? tr('seller.wallet_opening')
                      : tr('seller.pay_action'),
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ] else if (_payMode == _PayMode.card ||
              (!_showPayModeSwitcher && !_anyProviderEnabled))
            _ManualPaySection(
              instructionsFuture: _instructionsFuture,
              selected: selected,
              screenshotFile: _screenshotFile,
              busy: busy,
              submitting: _submittingManual,
              packageSelected: _packageCode != null,
              onCopyCard: _copyCard,
              onPickScreenshot: _pickScreenshot,
              onSubmit: _submitManual,
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
    );
  }
}

enum _SnackTone { success, error, neutral }

String _fmtUzs(int value) {
  final digits = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return tr('common.uzs_amount', namedArgs: {'amount': buf.toString()});
}

class _PayModeBar extends StatelessWidget {
  const _PayModeBar({
    required this.mode,
    required this.busy,
    required this.onSelect,
  });

  final _PayMode? mode;
  final bool busy;
  final ValueChanged<_PayMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.fillFaint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PayModeChip(
              label: tr('seller.ar_pay_mode_online'),
              icon: Icons.smartphone_rounded,
              selected: mode == _PayMode.online,
              onTap: busy ? null : () => onSelect(_PayMode.online),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _PayModeChip(
              label: tr('seller.ar_pay_mode_card'),
              icon: Icons.credit_card_rounded,
              selected: mode == _PayMode.card,
              onTap: busy ? null : () => onSelect(_PayMode.card),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayModeChip extends StatelessWidget {
  const _PayModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: selected ? c.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: c.primary.withValues(alpha: 0.35))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? c.primary : c.grey),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? c.ink : c.grey,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualPaySection extends StatelessWidget {
  const _ManualPaySection({
    required this.instructionsFuture,
    required this.selected,
    required this.screenshotFile,
    required this.busy,
    required this.submitting,
    required this.packageSelected,
    required this.onCopyCard,
    required this.onPickScreenshot,
    required this.onSubmit,
  });

  final Future<TariffPaymentInstructions>? instructionsFuture;
  final ArTokenPackage? selected;
  final File? screenshotFile;
  final bool busy;
  final bool submitting;
  final bool packageSelected;
  final Future<void> Function(String) onCopyCard;
  final VoidCallback onPickScreenshot;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final future = instructionsFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<TariffPaymentInstructions>(
      future: future,
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
                _fmtUzs(selected!.priceUzs),
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
              onCopy: () => onCopyCard(ins.cardNumber),
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
              onPressed: busy ? null : onPickScreenshot,
              icon: const Icon(Icons.image_outlined, size: 20),
              label: Text(
                screenshotFile == null
                    ? tr('tariff.upload_screenshot')
                    : tr('seller.ar_manual_receipt_selected'),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: c.divider),
              ),
            ),
            if (screenshotFile case final file?) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.positiveBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.positive.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: c.positive,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(
                          'seller.wallet_receipt_attached',
                          namedArgs: {'name': _receiptLabel(file)},
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (screenshotFile != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: (!busy && packageSelected) ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.gold,
                    foregroundColor: AppColors.sellerInk,
                    disabledBackgroundColor: c.gold.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.sellerInk,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    tr('seller.ar_manual_submit'),
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _receiptLabel(File file) {
    final name = file.path.split('/').last;
    if (name.isNotEmpty) return name;
    return tr('seller.ar_manual_receipt_selected');
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

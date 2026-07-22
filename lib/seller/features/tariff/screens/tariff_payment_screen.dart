import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/remote_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/result/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/payments/manual_payment_pending_screen.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/pending_payment_service.dart';
import '../../../../shared/payments/refresh_payment_remote_config.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/utils/image_upload.dart';
import '../../../../shared/widgets/payment_provider_tile.dart';
import '../bloc/tariff_upgrade_bloc.dart';

/// Popped when the seller opened a Payme/Click checkout and left for the
/// payment app. Manual submissions navigate to [ManualPaymentPendingScreen].
enum TariffPaymentResult { onlineLaunched }

enum _PayMode { online, card }

/// Checkout screen after the seller taps **Tanlash** on a plan card.
/// Plan + billing period are locked; the seller picks online or P2P card pay.
class TariffPaymentScreen extends StatelessWidget {
  const TariffPaymentScreen({
    super.key,
    required this.plan,
    required this.period,
  });

  final SubscriptionPlan plan;
  final BillingPeriod period;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TariffUpgradeBloc(sl<TariffRepository>())
            ..add(TariffUpgradeStarted(plan: plan.asEnum, period: period)),
      child: _TariffPaymentView(plan: plan, period: period),
    );
  }
}

class _TariffPaymentView extends StatefulWidget {
  const _TariffPaymentView({required this.plan, required this.period});

  final SubscriptionPlan plan;
  final BillingPeriod period;

  @override
  State<_TariffPaymentView> createState() => _TariffPaymentViewState();
}

class _TariffPaymentViewState extends State<_TariffPaymentView> {
  PaymentProvider? _provider;
  _PayMode? _payMode;
  bool _buyingOnline = false;
  String? _onlineError;
  Future<Result<TariffPaymentInstructions>>? _instructionsFuture;

  bool get _anyProviderEnabled =>
      RemoteConfig.instance.anyOnlineProviderEnabled;

  bool get _showPayModeSwitcher => _anyProviderEnabled;

  int get _amount => widget.plan.priceFor(widget.period).toInt();

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
    _instructionsFuture ??= sl<TariffRepository>().paymentInstructions();
  }

  void _selectPayMode(_PayMode mode) {
    if (_payMode == mode) return;
    setState(() {
      _payMode = mode;
      _provider = null;
      _onlineError = null;
      if (mode == _PayMode.card) _ensureInstructions();
    });
  }

  Future<void> _payOnline() async {
    final provider = _provider;
    if (provider == null || !_providerIsEnabled(provider) || _buyingOnline) {
      if (provider == null || !_providerIsEnabled(provider)) {
        _showSnack(
          tr('seller.wallet_select_payment_method_hint'),
          isError: false,
        );
      }
      return;
    }
    setState(() {
      _buyingOnline = true;
      _onlineError = null;
    });
    try {
      final result = await sl<TariffRepository>().buyPlan(
        plan: widget.plan.asEnum,
        period: widget.period,
        provider: provider,
      );
      if (!mounted) return;
      final checkout = result.valueOrNull;
      if (checkout == null || checkout.url.isEmpty) {
        setState(() {
          _buyingOnline = false;
          _onlineError =
              result.failureOrNull?.message ?? tr('tariff.pay_launch_failed');
        });
        return;
      }
      final reference = checkout.reference;
      if (reference != null &&
          reference.isNotEmpty &&
          sl.isRegistered<PendingPaymentService>()) {
        await sl<PendingPaymentService>().mark(
          kind: PendingPaymentKind.subscription,
          reference: reference,
        );
      }
      final uri = Uri.tryParse(checkout.url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      Navigator.of(context).pop(TariffPaymentResult.onlineLaunched);
    } catch (e) {
      if (mounted) {
        setState(() {
          _buyingOnline = false;
          _onlineError = apiErrorMessage(e);
        });
      }
    }
  }

  Future<void> _copyCard(String number) async {
    await Clipboard.setData(ClipboardData(text: number.replaceAll(' ', '')));
    if (!mounted) return;
    _showSnack(tr('tariff.card_copied'), isError: false);
  }

  Future<void> _pickScreenshot() async {
    final bloc = context.read<TariffUpgradeBloc>();
    try {
      final picked = await ImageUploadHelper().pick(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      bloc.add(
        TariffUpgradeScreenshotPicked(
          file: picked.file,
          fileExtension: picked.extension,
        ),
      );
    } on ImagePickError catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.sellerNegative : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final busy = _buyingOnline;
    final canSubmitOnline =
        _provider != null && _providerIsEnabled(_provider!) && !busy;

    return BlocListener<TariffUpgradeBloc, TariffUpgradeState>(
      listenWhen: (a, b) =>
          a.status != b.status && b.status == TariffUpgradeFlowStatus.submitted,
      listener: (context, state) {
        final subscription = state.subscription;
        if (subscription == null) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/seller-tariff-pending'),
            builder: (_) => ManualPaymentPendingScreen(
              args: TariffSubscriptionPendingArgs(subscription: subscription),
            ),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: c.ink,
          leading: IconButton(
            icon: Icon(Iconsax.arrow_left_2_copy, size: 22, color: c.ink),
            onPressed: busy ? null : () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            tr('tariff.payment_title'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.ink,
              letterSpacing: -0.2,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            _PlanSummaryCard(
              plan: widget.plan,
              period: widget.period,
              amount: _amount,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: c.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showPayModeSwitcher) ...[
                    _PayModeBar(
                      mode: _payMode,
                      busy: busy,
                      onSelect: _selectPayMode,
                    ),
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
                            : () => setState(
                                () => _provider = PaymentProvider.payme,
                              ),
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
                            : () => setState(
                                () => _provider = PaymentProvider.click,
                              ),
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
                          disabledBackgroundColor: AppColors.sellerPrimary
                              .withValues(alpha: 0.35),
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
                    if (_onlineError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _onlineError!,
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12.5,
                          color: AppColors.sellerNegative,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ] else if (_payMode == _PayMode.card ||
                      (!_showPayModeSwitcher && !_anyProviderEnabled))
                    _ManualPaySection(
                      instructionsFuture: _instructionsFuture,
                      amount: _amount,
                      onCopyCard: _copyCard,
                      onPickScreenshot: _pickScreenshot,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.plan,
    required this.period,
    required this.amount,
  });

  final SubscriptionPlan plan;
  final BillingPeriod period;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final periodLabel = tr('tariff.period_${period.code}');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.sellerPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('tariff.plan.${plan.code}_label'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'tariff.payment_subtitle',
              args: [
                tr('tariff.plan.${plan.code}_label'),
                periodLabel,
                _formatPrice(amount),
              ],
            ),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.grey,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
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
    required this.amount,
    required this.onCopyCard,
    required this.onPickScreenshot,
  });

  final Future<Result<TariffPaymentInstructions>>? instructionsFuture;
  final int amount;
  final Future<void> Function(String) onCopyCard;
  final VoidCallback onPickScreenshot;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final future = instructionsFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<Result<TariffPaymentInstructions>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final result = snap.data;
        if (result == null || result.failureOrNull != null) {
          return Text(
            result?.failureOrNull?.message ??
                tr('tariff.instructions_load_failed'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              color: AppColors.sellerNegative,
            ),
          );
        }
        final ins = result.valueOrNull!;
        return BlocBuilder<TariffUpgradeBloc, TariffUpgradeState>(
          builder: (context, state) {
            final uploading = state.status == TariffUpgradeFlowStatus.uploading;
            final submitting =
                state.status == TariffUpgradeFlowStatus.submitting;
            final busy = uploading || submitting;
            final receiptReady =
                state.uploadedScreenshotUrl != null &&
                state.status == TariffUpgradeFlowStatus.ready;
            final localPath = state.localScreenshotPath;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(
                    'common.uzs_amount',
                    namedArgs: {'amount': _formatPrice(amount)},
                  ),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 12),
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
                    localPath == null
                        ? tr('tariff.upload_screenshot')
                        : tr('seller.ar_manual_receipt_selected'),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: c.divider),
                  ),
                ),
                if (localPath != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: c.positiveBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: c.positive.withValues(alpha: 0.25),
                      ),
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
                              namedArgs: {'name': _receiptLabel(localPath)},
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
                if (localPath != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: receiptReady && !busy
                          ? () => context.read<TariffUpgradeBloc>().add(
                              const TariffUpgradeSubmitted(),
                            )
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sellerPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.sellerPrimary
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
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
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.error!,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 12.5,
                      color: AppColors.sellerNegative,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  static String _receiptLabel(String path) {
    final name = path.split('/').last;
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
                icon: Icon(Icons.copy_outlined, color: c.primary, size: 20),
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

String _formatPrice(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  final n = s.length;
  for (var i = 0; i < n; i++) {
    if (i > 0 && (n - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

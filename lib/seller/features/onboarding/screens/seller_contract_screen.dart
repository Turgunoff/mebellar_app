import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/repositories/legal_documents_repository.dart';
import '../bloc/onboarding_bloc.dart';
import '../constants/seller_contract_oferta.dart';
import '../utils/contract_pdf_generator.dart';
import '../widgets/onboarding_kit.dart';

/// Seller public-offer (vositachilik shartnomasi) screen — formal GPD layout.
///
/// A4 paper illusion with three parts: city/date header, markdown body, and a
/// two-column requisites table. Fetches live copy from `GET /legal/oferta`.
class SellerContractScreen extends StatelessWidget {
  const SellerContractScreen({
    super.key,
    this.isReadOnly = false,
    this.sellerName = '',
    this.sellerPhone = '',
    this.sellerAddress = '',
    this.commissionPercent,
    this.acceptedAt,
    this.acceptedVersion,
  });

  final bool isReadOnly;
  final String sellerName;
  final String sellerPhone;
  final String sellerAddress;

  /// Active plan commission (e.g. `"6"`). Defaults to Free (6%) when null.
  final String? commissionPercent;

  /// Persisted acceptance timestamp — shown in read-only mode.
  final DateTime? acceptedAt;

  /// Seller's stamped `contract_version` — used for re-accept detection TODO.
  final String? acceptedVersion;

  @override
  Widget build(BuildContext context) {
    if (isReadOnly) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('seller.profile_contract_title'))),
        body: _SellerContractBody(
          isReadOnly: true,
          sellerName: sellerName,
          sellerPhone: sellerPhone,
          sellerAddress: sellerAddress,
          commissionPercent: commissionPercent,
          acceptedAt: acceptedAt,
          acceptedVersion: acceptedVersion,
        ),
      );
    }

    return StepActivation(
      step: OnboardingStep.contract,
      builder: (context, animation) {
        return FadeTransition(
          opacity: animation,
          child: _SellerContractBody(
            isReadOnly: false,
            sellerName: sellerName,
            sellerPhone: sellerPhone,
            sellerAddress: sellerAddress,
            commissionPercent: commissionPercent,
            acceptedAt: acceptedAt,
            acceptedVersion: acceptedVersion,
          ),
        );
      },
    );
  }
}

class _SellerContractBody extends StatefulWidget {
  const _SellerContractBody({
    required this.isReadOnly,
    this.sellerName = '',
    this.sellerPhone = '',
    this.sellerAddress = '',
    this.commissionPercent,
    this.acceptedAt,
    this.acceptedVersion,
  });

  final bool isReadOnly;
  final String sellerName;
  final String sellerPhone;
  final String sellerAddress;
  final String? commissionPercent;
  final DateTime? acceptedAt;
  final String? acceptedVersion;

  @override
  State<_SellerContractBody> createState() => _SellerContractBodyState();
}

class _SellerContractBodyState extends State<_SellerContractBody> {
  final ScrollController _scrollController = ScrollController();
  bool _hasReachedBottom = false;
  bool _loading = true;
  bool _pdfBusy = false;
  String _content = kSellerOfertaFallbackContent;
  String _version = '1.0';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (!widget.isReadOnly) {
      _scrollController.addListener(_onScroll);
    }
    _loadOferta();
  }

  @override
  void dispose() {
    if (!widget.isReadOnly) {
      _scrollController.removeListener(_onScroll);
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOferta() async {
    try {
      final lang = sl<AppLocaleController>().value.languageCode;
      final doc = await sl<LegalDocumentsRepository>()
          .fetchSellerOferta(lang: lang);
      if (!mounted) return;
      setState(() {
        _content = doc.content.isNotEmpty
            ? doc.content
            : kSellerOfertaFallbackContent;
        _version = doc.version;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _content = kSellerOfertaFallbackContent;
        _loadError = 'fallback';
        _loading = false;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isReadOnly) _checkScrollExtent();
    });
  }

  void _onScroll() {
    if (_hasReachedBottom || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 50) {
      setState(() => _hasReachedBottom = true);
    }
  }

  void _checkScrollExtent() {
    if (!mounted || !_scrollController.hasClients || _hasReachedBottom) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 50) {
      setState(() => _hasReachedBottom = true);
    }
  }

  String get _languageCode =>
      sl<AppLocaleController>().value.languageCode;

  String get _contractNumber =>
      generateOfertaContractNumber(sl<AuthRepository>().currentUserId);

  String _resolveSellerName(BuildContext context) {
    if (widget.sellerName.trim().isNotEmpty) return widget.sellerName.trim();
    if (widget.isReadOnly) return '';
    final draft = context.read<OnboardingBloc>().state.draft;
    if (draft.legalName?.trim().isNotEmpty ?? false) {
      return draft.legalName!.trim();
    }
    if (draft.shopNameUz?.trim().isNotEmpty ?? false) {
      return draft.shopNameUz!.trim();
    }
    return '';
  }

  String _resolvePhone(BuildContext context) {
    if (widget.sellerPhone.trim().isNotEmpty) return widget.sellerPhone.trim();
    if (widget.isReadOnly) return '';
    final draft = context.read<OnboardingBloc>().state.draft;
    return draft.contactPhone?.trim() ?? '';
  }

  String _resolveAddress(BuildContext context) {
    if (widget.sellerAddress.trim().isNotEmpty) {
      return widget.sellerAddress.trim();
    }
    if (widget.isReadOnly) return '';
    final draft = context.read<OnboardingBloc>().state.draft;
    return draft.shopStreetLine?.trim() ?? '';
  }

  String _resolveCommission() {
    if (widget.commissionPercent != null &&
        widget.commissionPercent!.trim().isNotEmpty) {
      return widget.commissionPercent!.trim();
    }
    final rate = TariffPlan.free.commissionRate;
    return rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toString();
  }

  String _resolveDateLabel() {
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat.yMMMMd(locale);
    if (widget.isReadOnly && widget.acceptedAt != null) {
      return fmt.format(widget.acceptedAt!.toLocal());
    }
    return fmt.format(DateTime.now());
  }

  String _injectedText(BuildContext context) {
    return injectOfertaPlaceholders(
      _content,
      sellerName: _resolveSellerName(context),
      commissionPercent: _resolveCommission(),
      dateLabel: _loading ? '…' : _resolveDateLabel(),
      contractNumber: _contractNumber,
    );
  }

  Future<void> _sharePdf() async {
    if (_pdfBusy || _loading) return;
    final name = _resolveSellerName(context);
    final phone = _resolvePhone(context);
    final address = _resolveAddress(context);
    final text = _injectedText(context);
    final dateLabel = _resolveDateLabel();
    setState(() => _pdfBusy = true);
    try {
      await generateAndShareContractPdf(
        sellerName: name,
        sellerPhone: phone,
        sellerAddress: address,
        contractText: text,
        contractNumber: _contractNumber,
        dateLabel: dateLabel,
        languageCode: _languageCode,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('seller.profile_contract_pdf_failed'))),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final isSubmitting = widget.isReadOnly
        ? false
        : context.select(
            (OnboardingBloc b) => b.state.status == OnboardingStatus.submitting,
          );

    final bodyStyle = TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 13.5,
      height: 1.55,
      color: const Color(0xFF1A1A1A),
      fontWeight: FontWeight.w400,
    );
    final boldStyle = bodyStyle.copyWith(fontWeight: FontWeight.w700);
    final headingStyle = bodyStyle.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.35,
    );
    final chromeStyle = bodyStyle.copyWith(fontSize: 12.5);
    final chromeBold = chromeStyle.copyWith(fontWeight: FontWeight.w700);

    final labels = OfertaGpdLabels.forLang(_languageCode);
    final injected = _injectedText(context);
    final dateLabel = _loading ? '…' : _resolveDateLabel();
    final sellerName = _resolveSellerName(context);
    final sellerPhone = _resolvePhone(context);
    final sellerAddress = _resolveAddress(context);

    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: pt.background,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (widget.isReadOnly && widget.acceptedAt != null) ...[
                        _AcceptedBanner(
                          dateLabel: dateLabel,
                          version: widget.acceptedVersion ?? _version,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!widget.isReadOnly) ...[
                        Text(
                          tr('onboarding.step_contract_title'),
                          style: PremiumTokens.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: pt.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('onboarding.step_contract_subtitle'),
                          style: PremiumTokens.body(size: 12, color: pt.grey),
                        ),
                        const SizedBox(height: 16),
                      ],
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                              spreadRadius: -2,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Part 1: Header ────────────────────────
                              _GpdHeader(
                                labels: labels,
                                contractNumber: _contractNumber,
                                dateLabel: dateLabel,
                                cityStyle: chromeBold,
                                titleStyle: chromeBold,
                                dateStyle: chromeStyle,
                              ),
                              const SizedBox(height: 20),
                              // ── Part 2: Markdown body ─────────────────
                              MarkdownBody(
                                data: injected,
                                selectable: false,
                                softLineBreak: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: bodyStyle,
                                  pPadding: EdgeInsets.zero,
                                  strong: boldStyle,
                                  h1: headingStyle,
                                  h2: headingStyle,
                                  h3: headingStyle,
                                  listBullet: bodyStyle,
                                  blockSpacing: 10,
                                ),
                              ),
                              const SizedBox(height: 24),
                              // ── Part 3: Requisites table ──────────────
                              _GpdRequisitesTable(
                                labels: labels,
                                sellerName: sellerName,
                                sellerPhone: sellerPhone,
                                sellerAddress: sellerAddress,
                                headingStyle: chromeBold,
                                cellStyle: chromeStyle.copyWith(fontSize: 11),
                                cellBold: chromeBold.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!widget.isReadOnly && !_hasReachedBottom) ...[
                        const SizedBox(height: 16),
                        Text(
                          tr('onboarding.contract_scroll_hint'),
                          textAlign: TextAlign.center,
                          style: PremiumTokens.body(size: 12, color: pt.grey),
                        ),
                      ],
                      if (_loadError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          tr('onboarding.contract_offline_fallback'),
                          textAlign: TextAlign.center,
                          style: PremiumTokens.body(size: 11, color: pt.grey),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        if (widget.isReadOnly)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: (_loading || _pdfBusy) ? null : () => _sharePdf(),
                  icon: _pdfBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(tr('seller.profile_contract_pdf_download')),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          )
        else
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => context.read<OnboardingBloc>().add(
                                      const OnboardingPreviousStep(),
                                    ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: Text(tr('common.back')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: (_loading ||
                                    !_hasReachedBottom ||
                                    isSubmitting)
                                ? null
                                : () => context.read<OnboardingBloc>().add(
                                      OnboardingSubmitted(
                                        contractVersion: _version,
                                      ),
                                    ),
                            style: FilledButton.styleFrom(
                              backgroundColor: PremiumTokens.accent,
                              disabledBackgroundColor:
                                  pt.grey.withValues(alpha: 0.28),
                              disabledForegroundColor:
                                  Colors.white.withValues(alpha: 0.85),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              tr('onboarding.contract_accept'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: PremiumTokens.body(
                                size: 13,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_hasReachedBottom) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton.icon(
                        onPressed: (_loading || _pdfBusy || isSubmitting)
                            ? null
                            : () => _sharePdf(),
                        icon: _pdfBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 18,
                              ),
                        label: Text(
                          tr('seller.profile_contract_pdf_download'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GpdHeader extends StatelessWidget {
  const _GpdHeader({
    required this.labels,
    required this.contractNumber,
    required this.dateLabel,
    required this.cityStyle,
    required this.titleStyle,
    required this.dateStyle,
  });

  final OfertaGpdLabels labels;
  final String contractNumber;
  final String dateLabel;
  final TextStyle cityStyle;
  final TextStyle titleStyle;
  final TextStyle dateStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(labels.city, style: cityStyle),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${labels.contractTitle} $contractNumber',
                style: titleStyle,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 4),
              Text(
                '${labels.datePrefix} $dateLabel',
                style: dateStyle,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GpdRequisitesTable extends StatelessWidget {
  const _GpdRequisitesTable({
    required this.labels,
    required this.sellerName,
    required this.sellerPhone,
    required this.sellerAddress,
    required this.headingStyle,
    required this.cellStyle,
    required this.cellBold,
  });

  final OfertaGpdLabels labels;
  final String sellerName;
  final String sellerPhone;
  final String sellerAddress;
  final TextStyle headingStyle;
  final TextStyle cellStyle;
  final TextStyle cellBold;

  @override
  Widget build(BuildContext context) {
    final platformBlock = buildPlatformRequisitesBlock(labels);
    final sellerBlock = buildSellerRequisitesBlock(
      labels: labels,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      sellerAddress: sellerAddress,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          labels.requisitesHeading,
          style: headingStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Table(
          border: TableBorder.all(
            color: Colors.black.withValues(alpha: 0.75),
            width: 0.8,
          ),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              children: [
                _Cell(
                  child: Text(labels.platformColumnTitle, style: cellBold),
                ),
                _Cell(
                  child: Text(labels.sellerColumnTitle, style: cellBold),
                ),
              ],
            ),
            TableRow(
              children: [
                _Cell(
                  child: Text(platformBlock, style: cellStyle),
                ),
                _Cell(
                  child: Text(sellerBlock, style: cellStyle),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: child,
    );
  }
}

class _AcceptedBanner extends StatelessWidget {
  const _AcceptedBanner({required this.dateLabel, required this.version});

  final String dateLabel;
  final String version;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PremiumTokens.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PremiumTokens.accent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('seller.profile_contract_accepted_date', args: [dateLabel]),
            style: PremiumTokens.body(
              size: 13,
              weight: FontWeight.w600,
              color: pt.dark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tr('seller.profile_contract_version', args: [version]),
            style: PremiumTokens.body(size: 12, color: pt.grey),
          ),
        ],
      ),
    );
  }
}

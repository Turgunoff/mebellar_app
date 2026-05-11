import 'dart:io';

import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/utils/image_upload.dart';
import '../bloc/tariff_upgrade_bloc.dart';

/// Spec'dan ko'tarilgan to'lov yo'riqnomasi: karta raqami clipboard'ga,
/// SHOP-{id} izoh, skrinshot upload, Telegram fallback. Submit qilingach
/// bottom sheet yopiladi va ekran egasi (`onSubmitted`) PendingStatusScreen
/// ga o'tadi.
Future<TariffSubscription?> showPaymentInstructionsSheet(
  BuildContext context, {
  required TariffPlan plan,
  required BillingPeriod period,
}) {
  return showModalBottomSheet<TariffSubscription>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => BlocProvider(
      create: (_) => TariffUpgradeBloc(sl<TariffRepository>())
        ..add(TariffUpgradeStarted(plan: plan, period: period)),
      child: const _SheetBody(),
    ),
  );
}

class _SheetBody extends StatefulWidget {
  const _SheetBody();

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  late Future<TariffPaymentInstructions> _instructions;

  @override
  void initState() {
    super.initState();
    _instructions = sl<TariffRepository>().paymentInstructions();
  }

  Future<void> _copyCard(String number) async {
    await Clipboard.setData(ClipboardData(text: number.replaceAll(' ', '')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('tariff.card_copied'))),
    );
  }

  Future<void> _copyNote(String note) async {
    await Clipboard.setData(ClipboardData(text: note));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('tariff.note_copied'))),
    );
  }

  Future<void> _openTelegram(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('shop.telegram_failed'))),
      );
    }
  }

  Future<void> _pickScreenshot() async {
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<TariffUpgradeBloc>();
    try {
      final picked = await ImageUploadHelper().pick(source: ImageSource.gallery);
      if (picked == null) return;
      bloc.add(TariffUpgradeScreenshotPicked(
        file: picked.file,
        fileExtension: picked.extension,
      ));
    } on ImagePickError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TariffUpgradeBloc, TariffUpgradeState>(
      listenWhen: (a, b) =>
          a.status != b.status &&
          b.status == TariffUpgradeFlowStatus.submitted,
      listener: (context, state) {
        Navigator.of(context).pop(state.subscription);
      },
      builder: (context, state) {
        final lang = context.locale.languageCode;
        final priceFormat = NumberFormat('#,###', lang);
        final scheme = Theme.of(context).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => SafeArea(
            child: FutureBuilder<TariffPaymentInstructions>(
              future: _instructions,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ins = snap.data!;
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('tariff.payment_title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (state.plan != null)
                      Text(
                        tr('tariff.payment_subtitle', args: [
                          tr('tariff.plan.${state.plan!.code}_label'),
                          tr('tariff.period_${state.period.code}'),
                          priceFormat.format(state.amount),
                        ]),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 20),
                    _CardWidget(
                      number: ins.cardNumber,
                      holder: ins.cardHolder,
                      bank: ins.bankName,
                      onCopy: () => _copyCard(ins.cardNumber),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.tag_outlined),
                        title: Text(ins.note,
                            style: Theme.of(context).textTheme.titleSmall),
                        subtitle: Text(tr('tariff.note_hint'),
                            style: Theme.of(context).textTheme.bodySmall),
                        trailing: IconButton.filledTonal(
                          tooltip: tr('tariff.copy_note'),
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () => _copyNote(ins.note),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('tariff.upload_screenshot_title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('tariff.upload_screenshot_hint'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _ScreenshotPicker(state: state, onPick: _pickScreenshot),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _openTelegram(ins.telegramSupportUrl),
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(tr('tariff.telegram_alternative')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: state.canSubmit &&
                                state.status !=
                                    TariffUpgradeFlowStatus.submitting
                            ? () => context
                                .read<TariffUpgradeBloc>()
                                .add(const TariffUpgradeSubmitted())
                            : null,
                        icon: state.status ==
                                TariffUpgradeFlowStatus.submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(tr('tariff.submit')),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _CardWidget extends StatelessWidget {
  const _CardWidget({
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
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.tertiary,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card, color: Colors.white),
                const SizedBox(width: 8),
                Text(bank,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    )),
                const Spacer(),
                const Icon(Icons.copy_outlined, color: Colors.white, size: 18),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              holder,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              tr('tariff.tap_to_copy'),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotPicker extends StatelessWidget {
  const _ScreenshotPicker({required this.state, required this.onPick});
  final TariffUpgradeState state;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localPath = state.localScreenshotPath;
    final uploaded = state.uploadedScreenshotUrl != null;
    final uploading = state.status == TariffUpgradeFlowStatus.uploading;

    return InkWell(
      onTap: uploading ? null : onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(
            color: uploaded ? scheme.primary : scheme.outlineVariant,
            width: uploaded ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (localPath != null)
              Image.file(
                File(localPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: scheme.surfaceContainerHighest),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 36, color: scheme.outline),
                    const SizedBox(height: 8),
                    Text(tr('tariff.upload_screenshot')),
                  ],
                ),
              ),
            if (uploading)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
            if (uploaded)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: scheme.onPrimary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        tr('tariff.uploaded'),
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

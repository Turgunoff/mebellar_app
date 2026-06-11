import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/seller_wallet.dart';
import '../../../../shared/repositories/seller_wallet_repository.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../bloc/seller_wallet_cubit.dart';
import '../widgets/wallet_info_bottom_sheet.dart';

/// Seller wallet — balance, debt state, top-up by card + screenshot, ledger.
/// The top-up trust model mirrors the tariff flow: pay to the Woody card,
/// upload the receipt, an admin approves and the balance is credited (a
/// clearing balance also lifts the debt freeze automatically).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  /// Persisted flag — the explainer auto-opens only on the seller's first
  /// visit; afterwards it stays reachable via the "Hamyon qanday ishlaydi?"
  /// link under the balance.
  static const _seenInfoKey = 'has_seen_wallet_info';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoShowInfo());
  }

  Future<void> _maybeAutoShowInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seenInfoKey) ?? false) return;
    if (!mounted) return;
    // Persist before awaiting dismissal so killing the app mid-sheet can't
    // make it auto-open a second time.
    await prefs.setBool(_seenInfoKey, true);
    if (!mounted) return;
    await showWalletInfoBottomSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerWalletCubit>(
      create: (_) => SellerWalletCubit(
        sl<SellerWalletRepository>(),
        tariffs: sl<TariffRepository>(),
      )..load(),
      child: const _WalletView(),
    );
  }
}

class _WalletView extends StatelessWidget {
  const _WalletView();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hamyon',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        iconTheme: IconThemeData(color: c.ink),
      ),
      body: BlocConsumer<SellerWalletCubit, SellerWalletState>(
        listenWhen: (prev, next) => prev.topUpStatus != next.topUpStatus,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.topUpStatus == TopUpStatus.success) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  "So'rov yuborildi — admin tasdiqlagach balans yangilanadi.",
                ),
              ),
            );
            context.read<SellerWalletCubit>().acknowledgeTopUpResult();
          } else if (state.topUpStatus == TopUpStatus.failure) {
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: AppColors.danger,
                content: const Text(
                  "To'lov so'rovini yuborib bo'lmadi. Qayta urinib ko'ring.",
                ),
              ),
            );
            context.read<SellerWalletCubit>().acknowledgeTopUpResult();
          }
        },
        builder: (context, state) {
          if (state.status == WalletStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == WalletStatus.failure) {
            return _ErrorView(
              onRetry: () => context.read<SellerWalletCubit>().load(),
            );
          }
          final wallet = state.wallet;
          return BrandRefreshIndicator(
            color: AppColors.sellerPrimary,
            onRefresh: () => context.read<SellerWalletCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                _BalanceCard(wallet: wallet),
                if (!wallet.isHealthy) ...[
                  const SizedBox(height: 12),
                  _DebtNotice(wallet: wallet),
                ],
                if (wallet.pendingTopUp != null) ...[
                  const SizedBox(height: 12),
                  _PendingTopUpCard(topUp: wallet.pendingTopUp!),
                ],
                const SizedBox(height: 20),
                _TopUpSection(state: state, suggestedAmount: wallet.debtAmount),
                if (wallet.transactions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    "So'nggi amallar",
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TransactionsCard(transactions: wallet.transactions),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final SellerWallet wallet;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final negative = wallet.balance < 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: negative ? c.negative : c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Joriy balans',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${formatSom(wallet.balance)} so'm",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: negative ? c.negative : c.ink,
              letterSpacing: -0.5,
            ),
          ),
          if (wallet.creditLimit > 0) ...[
            const SizedBox(height: 8),
            Text(
              "Kredit limiti: ${formatSom(wallet.creditLimit)} so'm "
              "(${formatSom(wallet.debtFloor)} gacha)",
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.greyMid,
              ),
            ),
          ],
          const SizedBox(height: 4),
          // Flush-left, compact link — manual entry point to the same explainer
          // that auto-opens on first visit.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showWalletInfoBottomSheet(context),
              style: TextButton.styleFrom(
                foregroundColor: c.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text(
                'Hamyon qanday ishlaydi?',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grace-period warning or suspension notice, mirroring the dashboard banner.
class _DebtNotice extends StatelessWidget {
  const _DebtNotice({required this.wallet});

  final SellerWallet wallet;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final suspended = wallet.isSuspendedDueToDebt;
    final fg = suspended ? c.negative : c.warning;
    final bg = suspended ? c.negativeBg : c.warningBg;
    final text = suspended
        ? "Do'koningiz vaqtincha muzlatildi! Iltimos, qarzdorlikni uzing — "
              "balans tiklanishi bilan do'kon avtomatik ochiladi."
        : "Balansingiz minusga kirdi. Xizmat ko'rsatish to'xtatilmasligi "
              "uchun ${wallet.graceHoursLeft()} soat ichida hisobni "
              "to'ldiring.";
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            suspended ? Iconsax.lock : Iconsax.warning_2,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingTopUpCard extends StatelessWidget {
  const _PendingTopUpCard({required this.topUp});

  final WalletTopUp topUp;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.progressBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Iconsax.clock, color: c.progress, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${formatSom(topUp.amount)} so'mlik to'lovingiz ko'rib "
              'chiqilmoqda.',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.progress,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUpSection extends StatefulWidget {
  const _TopUpSection({required this.state, required this.suggestedAmount});

  final SellerWalletState state;

  /// Prefill: the exact debt the seller must clear (0 when healthy).
  final int suggestedAmount;

  @override
  State<_TopUpSection> createState() => _TopUpSectionState();
}

class _TopUpSectionState extends State<_TopUpSection> {
  late final TextEditingController _amountCtrl = TextEditingController(
    text: widget.suggestedAmount > 0 ? widget.suggestedAmount.toString() : '',
  );

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndSubmit() async {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(' ', '')) ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<SellerWalletCubit>();
    if (amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text("To'ldirish summasini kiriting.")),
      );
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final ext = picked.path.split('.').last;
    await cubit.submitTopUp(
      amount: amount,
      screenshot: File(picked.path),
      fileExtension: ext.length <= 4 ? ext : 'jpg',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final instructions = widget.state.instructions;
    final submitting = widget.state.topUpStatus == TopUpStatus.submitting;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hisobni to'ldirish",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          if (instructions != null) ...[
            const SizedBox(height: 10),
            Text(
              "${instructions.bankName} kartasiga to'lov qiling va chekni "
              'yuklang:',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12.5,
                color: c.grey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${instructions.cardNumber} · ${instructions.cardHolder}',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
            decoration: InputDecoration(
              labelText: "Summa (so'm)",
              labelStyle: TextStyle(fontFamily: AppFonts.seller, color: c.grey),
              filled: true,
              fillColor: c.fillSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submitting ? null : _pickAndSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sellerPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Iconsax.receipt_2, size: 18),
              label: Text(
                submitting ? 'Yuborilmoqda…' : 'Chek yuklash va yuborish',
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transactions[i].note ?? transactions[i].typeLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmt.format(transactions[i].createdAt.toLocal()),
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 12,
                            color: c.greyMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "${transactions[i].isDebit ? '' : '+'}"
                    "${formatSom(transactions[i].amount)}",
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: transactions[i].isDebit ? c.negative : c.positive,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.wifi_square, color: c.greyMid, size: 36),
          const SizedBox(height: 10),
          Text(
            "Hamyonni yuklab bo'lmadi",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.grey,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
        ],
      ),
    );
  }
}

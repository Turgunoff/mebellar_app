import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/network/payme_client.dart';
import '../../../../shared/repositories/payment_cards_repository.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/add_card_cubit.dart';
import '../widgets/payme_badge.dart';
import '../widgets/payment_pin.dart';

const _paymeOfferUrl = 'https://payme.uz/terms/main';

/// Secure add-card flow. Card number + expiry go straight to Payme
/// ([PaymeClient]); only the resulting token + masked number are sent to the
/// Woody backend. Per Payme requirements, the form shows the Payme mark, the
/// public-offer link, and the "data isn't passed to the merchant" notice.
class AddCardScreen extends StatelessWidget {
  const AddCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddCardCubit(
        payme: sl<PaymeClient>(),
        repo: sl<PaymentCardsRepository>(),
      ),
      child: const _AddCardView(),
    );
  }
}

class _AddCardView extends StatelessWidget {
  const _AddCardView();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return BlocConsumer<AddCardCubit, AddCardState>(
      listenWhen: (a, b) => a.step != b.step,
      listener: (ctx, state) async {
        if (state.step != AddCardStep.done) return;
        // Right after the card is saved, offer to set a 4-digit local PIN
        // (skipped silently if the user already has one) so the first checkout
        // charge isn't interrupted.
        await ensurePaymentPin(ctx);
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(tr('payment.card_added')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: PremiumTokens.successStrong,
          ),
        );
        // Tell the cards list to reload.
        Navigator.of(ctx).pop(true);
      },
      builder: (ctx, state) {
        return Scaffold(
          backgroundColor: pt.background,
          appBar: AppBar(
            backgroundColor: pt.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Iconsax.arrow_left, color: pt.dark),
              onPressed: () {
                if (state.step == AddCardStep.code) {
                  // Back from the SMS step returns to the form, not out.
                  ctx.read<AddCardCubit>().backToForm();
                } else {
                  Navigator.of(ctx).maybePop();
                }
              },
            ),
            title: Text(
              tr('payment.add_title'),
              style: PremiumTokens.display(size: 20, letterSpacing: -0.4),
            ),
            centerTitle: false,
          ),
          body: SafeArea(
            child: switch (state.step) {
              AddCardStep.form => _CardForm(state: state, pt: pt),
              AddCardStep.code => _CodeForm(state: state, pt: pt),
              AddCardStep.done => const SizedBox.shrink(),
            },
          ),
        );
      },
    );
  }
}

// ── Step 1: card entry ───────────────────────────────────────────────────────

class _CardForm extends StatefulWidget {
  const _CardForm({required this.state, required this.pt});
  final AddCardState state;
  final PremiumTokens pt;

  @override
  State<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<_CardForm> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<AddCardCubit>().startCard(
      number: _number.text,
      expire: _expiry.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = widget.pt;
    final busy = widget.state.submitting;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const Center(child: PaymeBadge()),
          const SizedBox(height: 24),
          TextFormField(
            controller: _number,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.creditCardNumber],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              _CardNumberFormatter(),
            ],
            decoration: _dec(
              pt,
              tr('payment.card_number'),
              Iconsax.card,
              '0000 0000 0000 0000',
            ),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return digits.length < 16 ? '' : null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _expiry,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
              _ExpiryFormatter(),
            ],
            decoration: _dec(
              pt,
              tr('payment.expiry'),
              Iconsax.calendar_1,
              'MM/YY',
            ),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return digits.length < 4 ? '' : null;
            },
          ),
          const SizedBox(height: 20),
          _SecureNote(pt: pt),
          if (widget.state.error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: widget.state.error!),
          ],
          const SizedBox(height: 24),
          _PrimaryButton(
            label: tr('payment.continue'),
            busy: busy,
            onPressed: busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ── Step 2: SMS code ─────────────────────────────────────────────────────────

class _CodeForm extends StatefulWidget {
  const _CodeForm({required this.state, required this.pt});
  final AddCardState state;
  final PremiumTokens pt;

  @override
  State<_CodeForm> createState() => _CodeFormState();
}

class _CodeFormState extends State<_CodeForm> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuild so the Verify button enables once 4+ digits are entered.
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pt = widget.pt;
    final busy = widget.state.submitting;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: PremiumTokens.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.sms,
              color: PremiumTokens.accent,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          tr('payment.sms_title'),
          textAlign: TextAlign.center,
          style: PremiumTokens.display(size: 19, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        Text(
          tr('payment.sms_sent', args: [widget.state.maskedPhone ?? '']),
          textAlign: TextAlign.center,
          style: PremiumTokens.body(size: 13, color: pt.grey),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: PremiumTokens.display(size: 24, letterSpacing: 8),
          decoration: _dec(
            pt,
            tr('payment.sms_code'),
            Iconsax.password_check,
            '••••••',
          ),
        ),
        if (widget.state.error != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: widget.state.error!),
        ],
        const SizedBox(height: 24),
        _PrimaryButton(
          label: tr('payment.verify'),
          busy: busy,
          onPressed: busy || _code.text.length < 4
              ? null
              : () => context.read<AddCardCubit>().submitCode(_code.text),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy
              ? null
              : () => context.read<AddCardCubit>().resendCode(),
          child: Text(
            tr('payment.resend'),
            style: PremiumTokens.body(
              size: 13,
              weight: FontWeight.w600,
              color: PremiumTokens.accent,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────────

InputDecoration _dec(
  PremiumTokens pt,
  String label,
  IconData icon,
  String hint,
) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, size: 20, color: pt.greyLight),
    filled: true,
    fillColor: pt.imageBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PremiumTokens.accent, width: 1.5),
    ),
    errorStyle: const TextStyle(height: 0, fontSize: 0),
  );
}

class _SecureNote extends StatelessWidget {
  const _SecureNote({required this.pt});
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pt.imageBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Iconsax.shield_tick, size: 18, color: pt.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('payment.secure_note'),
                  style: PremiumTokens.body(
                    size: 12,
                    color: pt.grey,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => launchUrl(
                Uri.parse(_paymeOfferUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                tr('payment.offer'),
                style: PremiumTokens.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: PremiumTokens.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Iconsax.info_circle, size: 16, color: error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: PremiumTokens.body(size: 13, color: error),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: PremiumTokens.accent,
          disabledBackgroundColor: PremiumTokens.accent.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// Spaces a card number into groups of four as the user types.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Inserts the `/` between month and year (MM/YY).
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

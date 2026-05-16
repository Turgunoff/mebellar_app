import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/profile_cubit.dart';

/// Bottom sheet for editing the user's name and phone. Expects an ancestor
/// `BlocProvider<ProfileCubit>` (the caller wraps it via `BlocProvider.value`).
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.currentName,
    required this.currentPhone,
  });

  final String currentName;
  final String currentPhone;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
    _phoneCtrl = TextEditingController(text: widget.currentPhone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await context.read<ProfileCubit>().updateProfile(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
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
                    color: PremiumTokens.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.edit_2,
                    size: 18,
                    color: PremiumTokens.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Profilni tahrirlash',
                  style: PremiumTokens.display(size: 18, letterSpacing: -0.3),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Ism',
              style: PremiumTokens.body(
                size: 13,
                weight: FontWeight.w600,
                color: pt.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ismni kiriting' : null,
              decoration: _fieldDecoration(pt, hint: 'To\'liq ismingiz'),
            ),
            const SizedBox(height: 16),
            Text(
              'Telefon raqam',
              style: PremiumTokens.body(
                size: 13,
                weight: FontWeight.w600,
                color: pt.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneCtrl,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.phone,
              style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
              onFieldSubmitted: (_) => _submit(),
              decoration: _fieldDecoration(pt, hint: '+998 XX XXX XX XX'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: PremiumTokens.accent,
                  disabledBackgroundColor:
                      PremiumTokens.accent.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Saqlash',
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
      ),
    );
  }

  InputDecoration _fieldDecoration(PremiumTokens pt, {required String hint}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: pt.divider),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: PremiumTokens.body(size: 14, color: pt.greyLight),
      filled: true,
      fillColor: pt.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: PremiumTokens.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}

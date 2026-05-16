import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/logging/talker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_repository.dart';
import '../core/di/service_locator.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!sl.isRegistered<AuthRepository>()) {
      _showError(tr('error.server'));
      return;
    }
    setState(() => _busy = true);
    try {
      await sl<AuthRepository>().resetPassword(_email.text.trim());
    } on AuthException catch (e, st) {
      // OWASP: a reset request must look identical whether or not the
      // address is registered, and whether or not Supabase rate-limited
      // the call. Log the real cause for ourselves; never surface it.
      talker.handle(e, st, 'forgot_password: suppressed AuthException');
    } catch (e, st) {
      talker.handle(e, st, 'forgot_password: suppressed error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    // Always show the same neutral confirmation regardless of the outcome
    // above — per OWASP guidance, never reveal whether the email exists.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('auth.reset_link_sent_generic'))),
    );
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr('auth.reset_password'),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: tr('auth.email')),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return tr('auth.validation_required');
                  if (!value.contains('@')) return tr('auth.validation_email');
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr('auth.send_reset_link')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/logging/talker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_repository.dart';
import '../core/di/service_locator.dart';
import 'auth_error_messages.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Displayed via [showAuthFlow] as a fullscreen modal. Pops with `true` when
/// authentication succeeds; the caller decides what to do next (mode chooser,
/// route consumption, plain UI refresh).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      final repo = sl<AuthRepository>();
      await repo.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!repo.isEmailConfirmed) {
        if (!mounted) return;
        _goToVerifyEmail();
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (e, st) {
      // An unverified-email rejection is not a dead end — route the user
      // straight to the resend screen rather than showing a snackbar.
      if (isEmailNotConfirmed(e)) {
        talker.handle(e, st, 'login: email not confirmed');
        if (mounted) _goToVerifyEmail();
        return;
      }
      talker.handle(e, st, 'login: signIn failed');
      _showError(authErrorMessage(e));
    } catch (e, st) {
      talker.handle(e, st, 'login: signIn failed');
      _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToVerifyEmail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerifyEmailScreen(email: _email.text.trim()),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr('auth.login'),
      actions: [
        IconButton(
          tooltip: tr('common.close'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: tr('auth.email')),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return tr('auth.validation_required');
                  if (!value.contains('@')) return tr('auth.validation_email');
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: tr('auth.password'),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if ((v ?? '').length < 8) {
                    return tr('auth.validation_password');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                  child: Text(tr('auth.forgot_password')),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr('auth.login')),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tr('auth.no_account')),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                    child: Text(tr('auth.register')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

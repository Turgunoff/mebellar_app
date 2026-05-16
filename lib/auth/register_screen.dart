import 'package:flutter/material.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/logging/talker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_repository.dart';
import '../core/di/service_locator.dart';
import '../main.dart' show AppLocaleScope;
import 'auth_error_messages.dart';
import 'verify_email_screen.dart';
import 'widgets/auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _fullName = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _fullName.dispose();
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
      await sl<AuthRepository>().signUp(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        preferredLanguage: context.locale.languageCode,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: _email.text.trim()),
        ),
      );
    } on AuthException catch (e, st) {
      talker.handle(e, st, 'register: signUp failed');
      _showError(authErrorMessage(e));
    } catch (e, st) {
      talker.handle(e, st, 'register: signUp failed');
      _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr('auth.register'),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _fullName,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('auth.full_name')),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? tr('auth.validation_required') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('auth.email')),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return tr('auth.validation_required');
                  if (!value.contains('@')) return tr('auth.validation_email');
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('auth.password')),
                validator: (v) =>
                    (v ?? '').length < 8 ? tr('auth.validation_password') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: tr('auth.confirm_password')),
                validator: (v) =>
                    v != _password.text ? tr('auth.validation_password') : null,
              ),
              const SizedBox(height: 16),
              _LanguagePicker(
                value: context.locale.languageCode,
                onChanged: (code) =>
                    AppLocaleScope.of(context).setLocale(Locale(code)),
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
                    : Text(tr('auth.register')),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tr('auth.have_account')),
                  TextButton(
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(tr('auth.login')),
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

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: tr('auth.language')),
      items: [
        DropdownMenuItem(value: 'uz', child: Text(tr('lang.uz'))),
        DropdownMenuItem(value: 'ru', child: Text(tr('lang.ru'))),
        DropdownMenuItem(value: 'en', child: Text(tr('lang.en'))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

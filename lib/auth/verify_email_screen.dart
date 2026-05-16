import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/logging/talker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_repository.dart';
import '../core/di/service_locator.dart';
import 'auth_error_messages.dart';
import 'widgets/auth_scaffold.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _busy = false;

  Future<void> _resend() async {
    if (!sl.isRegistered<AuthRepository>()) return;
    setState(() => _busy = true);
    try {
      await sl<AuthRepository>().resendVerificationEmail(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('auth.email_resent'))),
      );
    } on AuthException catch (e, st) {
      talker.handle(e, st, 'verify_email: resend failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr('auth.verify_email_title'),
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 96),
        const SizedBox(height: 16),
        Text(
          tr('auth.verify_email_subtitle', namedArgs: {'email': widget.email}),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _resend,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr('auth.resend_email')),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: Text(tr('auth.login')),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../home/widgets/premium/premium_tokens.dart';

const _pinKey = 'woody_payment_pin';

/// Local, app-side payment PIN. Recommended by Payme for token-based charges:
/// a 4-digit code the user enters before a saved card is charged. Stored in
/// `flutter_secure_storage` (Keychain / EncryptedSharedPreferences) — it never
/// goes to any server and is unrelated to the card token.
class PaymentPinService {
  PaymentPinService(this._storage);

  final SecureStorage _storage;

  Future<bool> hasPin() async => (await _storage.read(_pinKey)) != null;

  Future<void> setPin(String pin) => _storage.write(_pinKey, pin);

  Future<bool> verify(String pin) async =>
      (await _storage.read(_pinKey)) == pin;
}

/// Shows the PIN gate. On first use it asks the user to set a PIN (enter +
/// confirm); afterwards it verifies. Returns true when the user is
/// authenticated (or just set a PIN), false if they dismissed it.
Future<bool> showPaymentPinGate(BuildContext context) async {
  final service = PaymentPinService(sl<SecureStorage>());
  final hasPin = await service.hasPin();
  if (!context.mounted) return false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PinSheet(service: service, setup: !hasPin),
  );
  return ok ?? false;
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.service, required this.setup});
  final PaymentPinService service;
  final bool setup;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _controller = TextEditingController();
  String? _firstEntry; // during setup: the first of the two entries
  String? _error;
  bool _confirming = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title {
    if (!widget.setup) return tr('payment.pin_enter_title');
    return _confirming
        ? tr('payment.pin_confirm_title')
        : tr('payment.pin_set_title');
  }

  Future<void> _onComplete(String pin) async {
    if (widget.setup) {
      if (!_confirming) {
        setState(() {
          _firstEntry = pin;
          _confirming = true;
          _error = null;
          _controller.clear();
        });
        return;
      }
      if (pin != _firstEntry) {
        setState(() {
          _error = tr('payment.pin_mismatch');
          _confirming = false;
          _firstEntry = null;
          _controller.clear();
        });
        return;
      }
      await widget.service.setPin(pin);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    // Verify path.
    final ok = await widget.service.verify(pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = tr('payment.pin_wrong');
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: pt.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: PremiumTokens.display(size: 19, letterSpacing: -0.3),
          ),
          if (widget.setup && !_confirming) ...[
            const SizedBox(height: 8),
            Text(
              tr('payment.pin_set_hint'),
              textAlign: TextAlign.center,
              style: PremiumTokens.body(size: 13, color: pt.grey),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 4,
            style: PremiumTokens.display(size: 28, letterSpacing: 16),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              filled: true,
              fillColor: pt.imageBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) {
              if (v.length == 4) _onComplete(v);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: PremiumTokens.body(
                size: 13,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

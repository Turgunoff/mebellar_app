import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_fonts.dart';
import 'auth_sheet_kit.dart';

/// Step 2 — enter the SMS OTP, with a resend countdown.
class OtpStep extends StatelessWidget {
  const OtpStep({
    super.key,
    required this.destination,
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.remainingLabel,
    required this.canResend,
    required this.onResend,
    this.length = 5,
    this.errorMessage,
  });

  /// Where the code was sent — shown in the "code sent to ..." subtitle.
  /// Typically a formatted phone number; could be an email in legacy flows.
  final String destination;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final String remainingLabel;
  final bool canResend;
  final VoidCallback onResend;

  /// Digit count of the OTP. Backend currently issues 5-digit codes
  /// (`OTP_LENGTH=5`, bound to the Eskiz template).
  final int length;

  /// Server-side or validation error (e.g. "wrong code"). Drives the
  /// shake animation + the inline error message under the pin row.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Kodni kiriting', style: authTitleStyle(context)),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: authSubtitleStyle(context),
            children: [
              TextSpan(text: '$length xonali kod '),
              TextSpan(
                text: destination,
                style: authSubtitleStyle(context).copyWith(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' raqamiga yuborildi.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _PinField(
          length: length,
          controller: controller,
          enabled: !busy,
          onCompleted: onSubmit,
          hasError: errorMessage != null,
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          _InlineError(message: errorMessage!),
        ],
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Tasdiqlash',
          busy: busy,
          onTap: busy ? null : onSubmit,
        ),
        const SizedBox(height: 16),
        Center(
          child: canResend
              ? _ResendButton(onTap: onResend)
              : _ResendCountdown(label: remainingLabel),
        ),
      ],
    );
  }
}

// ── Pin field ────────────────────────────────────────────────────────────

class _PinField extends StatefulWidget {
  const _PinField({
    required this.length,
    required this.controller,
    required this.enabled,
    required this.onCompleted,
    required this.hasError,
  });

  final int length;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onCompleted;
  final bool hasError;

  @override
  State<_PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<_PinField>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode();
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    widget.controller.addListener(_handle);
    _focus.addListener(_handleFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant _PinField old) {
    super.didUpdateWidget(old);
    // Trigger the shake whenever the error flag flips ON. Also clears
    // the pin so the user starts fresh — easier than asking them to
    // delete six digits manually after a wrong attempt.
    if (widget.hasError && !old.hasError) {
      _shake.forward(from: 0);
      // Slight delay so the user sees the error state before the field
      // resets — avoids the "did I type that wrong?" moment of doubt.
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          widget.controller.clear();
          _focus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handle);
    _focus.removeListener(_handleFocus);
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _handle() {
    setState(() {});
    if (widget.controller.text.length == widget.length) {
      // Slight delay so the last digit visually lands before submit.
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) widget.onCompleted();
      });
    }
  }

  void _handleFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // Sin-wave shake: 3 oscillations, ~8px amplitude. Decays to 0
        // at the end of the animation so the field settles in place.
        final progress = _shake.value;
        final dx = progress == 0
            ? 0.0
            : 8 *
                (1 - progress) *
                (progress < 0.166
                        ? 1
                        : progress < 0.333
                            ? -1
                            : progress < 0.5
                                ? 1
                                : progress < 0.666
                                    ? -1
                                    : progress < 0.833
                                        ? 1
                                        : -1)
                    .toDouble();
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: SizedBox(
        height: 64,
        child: Stack(
          children: [
            // Source-of-truth input. Visually invisible but receives
            // keystrokes, IME paste, and SMS auto-fill on iOS/Android.
            Positioned.fill(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: widget.length,
                showCursor: false,
                cursorWidth: 0,
                style: const TextStyle(color: Colors.transparent, height: 0.01),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Compute cell width from available space so the row
                  // breathes nicely on every screen — no fixed width.
                  const gap = 10.0;
                  final cellW = (constraints.maxWidth -
                          gap * (widget.length - 1)) /
                      widget.length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(widget.length, (i) {
                      final filled = i < value.length;
                      final isCursor = i == value.length && _focus.hasFocus;
                      final ch = filled ? value[i] : '';
                      return _PinBox(
                        width: cellW,
                        digit: ch,
                        active: isCursor,
                        filled: filled,
                        error: widget.hasError,
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinBox extends StatelessWidget {
  const _PinBox({
    required this.width,
    required this.digit,
    required this.active,
    required this.filled,
    required this.error,
  });

  final double width;
  final String digit;
  final bool active;
  final bool filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color borderColor;
    final Color fillColor;
    final double borderWidth;
    final List<BoxShadow>? shadow;

    if (error) {
      // Soft red tint in light mode; deeper, less-saturated red in dark
      // so the cell doesn't glare against the dark surface.
      borderColor = isDark
          ? const Color(0xFFD06464)
          : const Color(0xFFE36F6F);
      fillColor = isDark
          ? const Color(0xFF3A1E1E)
          : const Color(0xFFFDEFEF);
      borderWidth = 1.6;
      shadow = null;
    } else if (filled) {
      borderColor = kTerracotta;
      // Filled cells use the sheet's surface (not pure white) so they
      // read as "raised" rather than "different colour" in dark mode.
      fillColor = t.surface;
      borderWidth = 1.6;
      shadow = [
        BoxShadow(
          color: kTerracotta.withValues(alpha: 0.10),
          blurRadius: 14,
          offset: const Offset(0, 4),
          spreadRadius: -4,
        ),
      ];
    } else if (active) {
      borderColor = kTerracotta;
      fillColor = t.surface;
      borderWidth = 1.6;
      shadow = [
        BoxShadow(
          color: kTerracotta.withValues(alpha: 0.18),
          blurRadius: 12,
          offset: Offset.zero,
          spreadRadius: 2,
        ),
      ];
    } else {
      borderColor = t.border;
      fillColor = t.fieldFill;
      borderWidth = 1;
      shadow = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: width,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadow,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: digit.isEmpty
            ? active
                ? _BlinkingCaret(key: ValueKey('caret-$active'))
                : const SizedBox.shrink(key: ValueKey('empty'))
            : Text(
                digit,
                key: ValueKey('d-$digit'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: error
                      ? (isDark
                          ? const Color(0xFFEAA0A0)
                          : const Color(0xFF993D3D))
                      : t.textPrimary,
                  height: 1.0,
                ),
              ),
      ),
    );
  }
}

/// Soft pulsing caret bar inside the active empty cell. Visual cue that
/// keyboard input lands there even though our real TextField is the
/// invisible overlay underneath.
class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret({super.key});

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_ctrl),
      child: Container(
        width: 2,
        height: 22,
        decoration: BoxDecoration(
          color: kTerracotta,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ── Inline error chip ────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Pick a red that stays legible against either surface. Dark mode
    // wants a lighter shade because the surface itself is already deep.
    final errorColor =
        isDark ? const Color(0xFFEAA0A0) : const Color(0xFF993D3D);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: errorColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: errorColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Resend area ──────────────────────────────────────────────────────────

class _ResendButton extends StatelessWidget {
  const _ResendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.refresh_rounded, size: 16, color: kTerracotta),
              SizedBox(width: 6),
              Text(
                'Kodni qayta yuborish',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTerracotta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendCountdown extends StatelessWidget {
  const _ResendCountdown({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.timer_outlined, size: 14, color: t.textSecondary),
        const SizedBox(width: 6),
        Text(
          'Kodni qayta yuborish ',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: t.textSecondary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: t.fieldFill,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

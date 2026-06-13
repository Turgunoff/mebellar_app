import 'package:flutter/material.dart';

import '../models/cancel_reason.dart';

/// The user's choice from [showCancelReasonSheet]: the predefined [code] plus
/// the free [text] typed for the `other` code (null otherwise).
class CancelReasonSelection {
  const CancelReasonSelection({required this.code, this.text});

  final String code;
  final String? text;
}

/// Colours + font the sheet renders with. The call site builds this from its
/// own token bag (customer `PremiumTokens`, seller `SellerColors`) so this
/// shared widget never imports a mode-specific theme.
class CancelReasonStyle {
  const CancelReasonStyle({
    required this.surface,
    required this.ink,
    required this.muted,
    required this.border,
    required this.field,
    required this.accent,
    required this.danger,
    this.fontFamily,
  });

  final Color surface;
  final Color ink;
  final Color muted;
  final Color border;
  final Color field;

  /// Selection accent (the filled radio + focused field border).
  final Color accent;

  /// The destructive confirm button colour.
  final Color danger;
  final String? fontFamily;
}

/// Localised chrome strings. Reason titles come from the backend already
/// localised, so they are NOT here.
class CancelReasonLabels {
  const CancelReasonLabels({
    required this.title,
    required this.subtitle,
    required this.otherHint,
    required this.confirm,
    required this.otherRequired,
    required this.loadError,
  });

  final String title;
  final String subtitle;

  /// Hint for the free-text field shown when `other` is selected.
  final String otherHint;
  final String confirm;

  /// Inline validation when `other` is picked but the field is empty.
  final String otherRequired;

  /// Shown when the reasons couldn't be loaded — the user can still type a
  /// free-text reason (treated as `other`).
  final String loadError;
}

/// Bottom sheet: pick a predefined cancel reason (radio list), or `other` to
/// reveal an animated free-text field. Returns the [CancelReasonSelection] on
/// confirm, or null if dismissed. [loadReasons] is awaited with a loading
/// state; on empty/error it degrades to an `other`-only free-text flow so the
/// cancel is never blocked by the network.
Future<CancelReasonSelection?> showCancelReasonSheet({
  required BuildContext context,
  required Future<List<CancelReason>> Function() loadReasons,
  required CancelReasonStyle style,
  required CancelReasonLabels labels,
}) {
  return showModalBottomSheet<CancelReasonSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CancelReasonSheet(
      loadReasons: loadReasons,
      style: style,
      labels: labels,
    ),
  );
}

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet({
    required this.loadReasons,
    required this.style,
    required this.labels,
  });

  final Future<List<CancelReason>> Function() loadReasons;
  final CancelReasonStyle style;
  final CancelReasonLabels labels;

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  final _textController = TextEditingController();
  List<CancelReason>? _reasons;
  bool _loading = true;
  bool _loadFailed = false;
  String? _selectedCode;
  bool _showOtherError = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final fetched = await widget.loadReasons();
      if (!mounted) return;
      setState(() {
        _reasons = _withOther(fetched);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Degrade: an `other`-only list so the user can still type a reason.
      setState(() {
        _reasons = const [];
        _loadFailed = true;
        _loading = false;
        _selectedCode = CancelReason.otherCode;
      });
    }
  }

  /// Guarantees an `other` entry exists and is last, so the free-text path is
  /// always available even if the backend list omits it.
  List<CancelReason> _withOther(List<CancelReason> reasons) {
    if (reasons.any((r) => r.isOther)) return reasons;
    return [
      ...reasons,
      CancelReason(
        code: CancelReason.otherCode,
        title: widget.labels.otherHint,
      ),
    ];
  }

  bool get _isOtherSelected => _selectedCode == CancelReason.otherCode;

  void _submit() {
    final code = _selectedCode;
    if (code == null) return;
    final text = _textController.text.trim();
    if (code == CancelReason.otherCode && text.isEmpty) {
      setState(() => _showOtherError = true);
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      CancelReasonSelection(
        code: code,
        text: code == CancelReason.otherCode ? text : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: s.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.labels.title,
            style: TextStyle(
              fontFamily: s.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: s.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _loadFailed ? widget.labels.loadError : widget.labels.subtitle,
            style: TextStyle(
              fontFamily: s.fontFamily,
              fontSize: 13,
              color: s.muted,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: s.accent,
                  ),
                ),
              ),
            )
          else ...[
            // The reason list + "other" field scroll inside the space left
            // above the keyboard; the header and confirm button stay pinned so
            // the CTA is always reachable. Without this the Column overflows
            // once the soft keyboard claims half the sheet (autofocus on the
            // free-text field).
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final reason in _reasons ?? const <CancelReason>[])
                      _ReasonRow(
                        reason: reason,
                        selected: _selectedCode == reason.code,
                        style: s,
                        onTap: () => setState(() {
                          _selectedCode = reason.code;
                          _showOtherError = false;
                        }),
                      ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _isOtherSelected
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _OtherField(
                                controller: _textController,
                                style: s,
                                hint: widget.labels.otherHint,
                                errorText: _showOtherError
                                    ? widget.labels.otherRequired
                                    : null,
                                onChanged: (_) {
                                  if (_showOtherError) {
                                    setState(() => _showOtherError = false);
                                  }
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: (_selectedCode == null || _submitting)
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: s.danger,
                  disabledBackgroundColor: s.danger.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  widget.labels.confirm,
                  style: TextStyle(
                    fontFamily: s.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final CancelReason reason;
  final bool selected;
  final CancelReasonStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = style;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? s.accent.withValues(alpha: 0.08) : s.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? s.accent : s.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            _RadioDot(selected: selected, accent: s.accent, border: s.border),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason.title,
                style: TextStyle(
                  fontFamily: s.fontFamily,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: s.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({
    required this.selected,
    required this.accent,
    required this.border,
  });

  final bool selected;
  final Color accent;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : border,
          width: selected ? 6.5 : 1.6,
        ),
        color: Colors.transparent,
      ),
    );
  }
}

class _OtherField extends StatelessWidget {
  const _OtherField({
    required this.controller,
    required this.style,
    required this.hint,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final CancelReasonStyle style;
  final String hint;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = style;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      minLines: 2,
      maxLines: 4,
      maxLength: 1000,
      style: TextStyle(fontFamily: s.fontFamily, fontSize: 15, color: s.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: s.fontFamily, color: s.muted),
        errorText: errorText,
        filled: true,
        fillColor: s.field,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: s.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: s.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: s.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: s.danger, width: 1.6),
        ),
      ),
    );
  }
}

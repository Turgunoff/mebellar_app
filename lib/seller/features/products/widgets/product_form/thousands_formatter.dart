import 'package:flutter/services.dart';

/// Formats a numeric field with thin-space thousands grouping as the user
/// types (`1234567` -> `1 234 567`).
class ThousandsSpaceFormatter extends TextInputFormatter {
  const ThousandsSpaceFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = formatThousands(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Renders [value] with space-separated thousands groups.
String formatThousands(int value) {
  if (value == 0) return '0';
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return value.isNegative ? '-${buf.toString()}' : buf.toString();
}

import 'package:flutter/services.dart';

/// Prevents leading spaces/tabs in text fields across the application.
class NoLeadingSpaceFormatter extends TextInputFormatter {
  const NoLeadingSpaceFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith(' ') || newValue.text.startsWith('\t')) {
      final trimmed = newValue.text.trimLeft();
      final diff = newValue.text.length - trimmed.length;
      final newOffset = (newValue.selection.baseOffset - diff).clamp(
        0,
        trimmed.length,
      );
      return TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }
    return newValue;
  }
}

/// Formatter for mobile/phone number fields:
/// 1. Allows ONLY digits (0-9).
/// 2. Restricts maximum length to exactly 10 digits.
/// 3. Rejects invalid 10-digit numbers where all digits are identical (e.g., 0000000000, 9999999999).
class PhoneNumberFormatter extends TextInputFormatter {
  const PhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Keep digits only
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Limit to max 10 digits
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    // Reject 10 identical repeated digits (e.g. 0000000000, 1111111111, 9999999999)
    if (digits.length == 10 && RegExp(r'^(\d)\1{9}$').hasMatch(digits)) {
      return oldValue;
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class AppInputFormatters {
  static const NoLeadingSpaceFormatter noLeadingSpace =
      NoLeadingSpaceFormatter();
  static const PhoneNumberFormatter phoneNumber = PhoneNumberFormatter();
}

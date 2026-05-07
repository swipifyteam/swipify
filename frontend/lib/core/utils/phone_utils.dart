import 'package:flutter/services.dart';

/// Centralized PH phone number normalization and formatting.
class PhoneUtils {
  /// Normalizes a Philippine phone number to the E.164 format (+639XXXXXXXXX).
  static String normalizePH(String input) {
    // Remove ALL non-digit characters except +
    String phone = input.replaceAll(RegExp(r'[^0-9+]'), '');
    
    if (phone.isEmpty) return "";

    String normalized;
    // Already correct
    if (phone.startsWith('+63')) {
      normalized = phone;
    }
    // 09123456789 -> +639123456789
    else if (phone.startsWith('09')) {
      normalized = '+63${phone.substring(1)}';
    }
    // 9123456789 -> +639123456789
    else if (phone.startsWith('9') && phone.length == 10) {
      normalized = '+63$phone';
    }
    else {
      normalized = phone;
    }

    print("[PHONE NORMALIZED] $normalized");
    return normalized;
  }

  /// Returns true if the phone number looks like a valid PH mobile number.
  static bool isValidPH(String input) {
    final normalized = normalizePH(input);
    return normalized.startsWith('+639') && normalized.length == 13;
  }
}

/// A formatter that turns 09123456789 into 0912 345 6789
class PHPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.length > 11) return oldValue;

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 3 || i == 6) {
        if (i != text.length - 1) {
          formatted += ' ';
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

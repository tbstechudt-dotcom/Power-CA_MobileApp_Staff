import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

/// Service to validate phone numbers using device's Phone Number Hint API
/// Shows phone numbers linked to the user's Google account for selection
/// User must select their registered phone number to receive OTP
class PhoneValidationService {
  final SmsAutoFill _smsAutoFill = SmsAutoFill();

  /// Get phone number from device using Phone Number Hint API
  /// Shows a dialog with phone numbers linked to user's Google account
  /// Returns the selected phone number, or null if user cancels
  Future<String?> getPhoneNumberHint() async {
    try {
      final hint = await _smsAutoFill.hint;
      return hint;
    } on PlatformException catch (e) {
      debugPrint('Phone Number Hint error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Phone Number Hint error: $e');
      return null;
    }
  }

  /// Get app signature for SMS Retriever API
  /// This is needed for auto-reading OTP from SMS
  Future<String?> getAppSignature() async {
    try {
      final signature = await _smsAutoFill.getAppSignature;
      return signature;
    } catch (e) {
      debugPrint('Get app signature error: $e');
      return null;
    }
  }

  /// Start listening for OTP SMS
  /// Call this after sending OTP to auto-fill the OTP code
  Future<void> listenForCode() async {
    try {
      await _smsAutoFill.listenForCode();
    } catch (e) {
      debugPrint('Listen for code error: $e');
    }
  }

  /// Stop listening for SMS
  void unregisterListener() {
    try {
      _smsAutoFill.unregisterListener();
    } catch (e) {
      debugPrint('Unregister listener error: $e');
    }
  }

  /// Normalize phone number by removing country code prefix and spaces
  /// Example: "+91 98765 43210" -> "9876543210"
  String normalizePhoneNumber(String phone) {
    // Remove all spaces, dashes, and parentheses
    String normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Remove country code prefix if present
    if (normalized.startsWith('+91')) {
      normalized = normalized.substring(3);
    } else if (normalized.startsWith('91') && normalized.length > 10) {
      normalized = normalized.substring(2);
    } else if (normalized.startsWith('0') && normalized.length == 11) {
      normalized = normalized.substring(1);
    }

    return normalized;
  }

  /// Validate if entered phone matches device's phone
  /// Returns true if the phones match (after normalization)
  bool validatePhoneMatch(String enteredPhone, String devicePhone) {
    final normalizedEntered = normalizePhoneNumber(enteredPhone);
    final normalizedDevice = normalizePhoneNumber(devicePhone);

    return normalizedEntered == normalizedDevice;
  }

  /// Check if phone number is valid (10 digits for India)
  bool isValidPhoneNumber(String phone) {
    final normalized = normalizePhoneNumber(phone);
    // Indian phone numbers are 10 digits
    return normalized.length == 10 && RegExp(r'^\d{10}$').hasMatch(normalized);
  }
}

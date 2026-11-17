import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last company (concern) name seen on this device so the
/// sign-in screens can show it before anyone is logged in.
///
/// Saved whenever the app header loads the company for a signed-in staff
/// member; read by the auth screens (phone verification, OTP, sign-in ...).
/// Nothing is stored until someone has signed in once on the device.
class CompanyNameCache {
  static const _key = 'last_company_name';

  static Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key)?.trim();
      return (name == null || name.isEmpty) ? null : name;
    } catch (e) {
      debugPrint('CompanyNameCache.read failed: $e');
      return null;
    }
  }

  static Future<void> save(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, trimmed);
    } catch (e) {
      debugPrint('CompanyNameCache.save failed: $e');
    }
  }
}

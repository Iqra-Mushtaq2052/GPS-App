import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _keyAppLockEnabled = 'security_app_lock_enabled';
  static const String _keyPinCode = 'security_pin_code';

  /// Check if PIN app lock is enabled
  static Future<bool> isAppLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAppLockEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Enable or disable app PIN lock
  static Future<void> setAppLock(bool enabled, {String? pin}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAppLockEnabled, enabled);
      if (pin != null && pin.isNotEmpty) {
        await prefs.setString(_keyPinCode, pin);
      }
    } catch (_) {}
  }

  /// Verify user entered PIN code against saved PIN
  static Future<bool> verifyPin(String enteredPin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPin = prefs.getString(_keyPinCode) ?? '1234';
      return enteredPin == savedPin;
    } catch (_) {
      return false;
    }
  }

  /// Validates and sanitizes Imam Share Code (Must be 6 uppercase alphanumeric characters)
  static bool isValidShareCode(String code) {
    final clean = code.trim().toUpperCase();
    final regex = RegExp(r'^[A-Z0-9]{6}$');
    return regex.hasMatch(clean);
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const String keyToken = 'na7la_auth_token';
  static const String keyUserRole = 'na7la_user_role';
  static const String keyUserEmail = 'na7la_user_email';
  static const String keySelectedMac = 'na7la_selected_mac';
  static const String keyPinCode = 'na7la_pin_code';
  static const String keyBiometricEnabled = 'na7la_biometric_enabled';
  static const String keyAppLockEnabled = 'na7la_app_lock_enabled';
  static const String keyDarkMode = 'na7la_dark_mode';
  static const String keyLanguage = 'na7la_language';
  static const String keyTariffPrice = 'na7la_tariff_price';

  static Future<void> saveTariffPrice(double price) async {
    await _storage.write(key: keyTariffPrice, value: price.toString());
  }

  static Future<double> getTariffPrice() async {
    final val = await _storage.read(key: keyTariffPrice);
    if (val != null) {
      return double.tryParse(val) ?? 1.45;
    }
    return 1.45;
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: keyToken);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: keyToken);
  }

  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: keyUserRole, value: role);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: keyUserRole);
  }

  static Future<void> saveUserEmail(String email) async {
    await _storage.write(key: keyUserEmail, value: email);
  }

  static Future<String?> getUserEmail() async {
    return await _storage.read(key: keyUserEmail);
  }

  static Future<void> saveSelectedMac(String mac) async {
    await _storage.write(key: keySelectedMac, value: mac);
  }

  static Future<String?> getSelectedMac() async {
    return await _storage.read(key: keySelectedMac);
  }

  static Future<void> savePin(String pin) async {
    await _storage.write(key: keyPinCode, value: pin);
  }

  static Future<String?> getPin() async {
    return await _storage.read(key: keyPinCode);
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: keyBiometricEnabled, value: enabled.toString());
  }

  static Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: keyBiometricEnabled);
    return val == 'true';
  }

  static Future<void> setAppLockEnabled(bool enabled) async {
    await _storage.write(key: keyAppLockEnabled, value: enabled.toString());
  }

  static Future<bool> isAppLockEnabled() async {
    final val = await _storage.read(key: keyAppLockEnabled);
    return val == 'true';
  }

  static Future<void> setDarkMode(bool dark) async {
    await _storage.write(key: keyDarkMode, value: dark.toString());
  }

  static Future<bool> isDarkMode() async {
    final val = await _storage.read(key: keyDarkMode);
    return val != 'false'; // Defaults to TRUE (Dark Titanium)
  }

  static Future<void> setLanguage(String lang) async {
    await _storage.write(key: keyLanguage, value: lang);
  }

  static Future<String?> getLanguage() async {
    return await _storage.read(key: keyLanguage);
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: keyToken);
    await _storage.delete(key: keyUserRole);
    await _storage.delete(key: keyUserEmail);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../storage/secure_storage.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if hardware supports biometrics
  static Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  /// List enrolled biometrics
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Trigger fingerprint / face / device security prompt
  static Future<bool> authenticateBiometric({
    String reason = 'أكّد هويتك بالبصمة أو رمز الجهاز للمتابعة',
    bool biometricOnly = false,
  }) async {
    if (kIsWeb) return false;
    try {
      final isSupported = await canCheckBiometrics();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Check if master PIN is set
  static Future<bool> hasPin() async {
    final savedPin = await SecureStorageService.getPin();
    return savedPin != null && savedPin.trim().isNotEmpty;
  }

  /// Retrieve the saved Master PIN
  static Future<String?> getMasterPin() async {
    return await SecureStorageService.getPin();
  }

  /// Check master PIN
  static Future<bool> verifyPin(String enteredPin) async {
    final savedPin = await SecureStorageService.getPin();
    if (savedPin == null || savedPin.isEmpty) {
      return false;
    }
    return enteredPin == savedPin;
  }

  /// Save new Master PIN locally
  static Future<void> saveMasterPin(String newPin) async {
    await SecureStorageService.savePin(newPin);
  }
}

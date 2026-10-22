import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../storage/secure_storage.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if hardware supports biometrics
  static Future<bool> canCheckBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  /// Trigger fingerprint / face unlock prompt
  static Future<bool> authenticateBiometric({String reason = 'المس مستشعر البصمة لفتح المخرج المحمي'}) async {
    try {
      final isSupported = await canCheckBiometrics();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Check if master PIN is set
  static Future<bool> hasPin() async {
    final savedPin = await SecureStorageService.getPin();
    return savedPin != null && savedPin.trim().isNotEmpty;
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

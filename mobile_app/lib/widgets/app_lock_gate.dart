import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/localization/app_locale.dart';
import '../core/security/biometric_service.dart';
import '../core/storage/secure_storage.dart';
import 'pin_biometric_dialog.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({
    super.key,
    required this.child,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAppLockEnabled = false;
  bool _isDark = true;
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialLock() async {
    final token = await SecureStorageService.getToken();
    final enabled = await SecureStorageService.isAppLockEnabled();
    final isDark = await SecureStorageService.isDarkMode();

    if (!mounted) return;
    setState(() {
      _isAppLockEnabled = enabled;
      _isDark = isDark;
    });

    if (token != null && token.isNotEmpty && enabled) {
      setState(() => _isLocked = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateAndUnlock();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAppLockEnabled) return;

    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null && DateTime.now().difference(_pausedTime!).inSeconds >= 3) {
        if (!_isLocked) {
          setState(() => _isLocked = true);
          _authenticateAndUnlock();
        }
      }
    }
  }

  Future<void> _authenticateAndUnlock() async {
    final success = await BiometricService.authenticateBiometric(
      reason: trBi(
        'أكّد هويتك بالبصمة أو رمز الجهاز للدخول إلى تطبيق نحلة',
        'Verify your identity with biometrics or device passcode to unlock Na7la IoT',
      ),
    );
    if (success && mounted) {
      setState(() => _isLocked = false);
    }
  }

  void _openPinUnlockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PinBiometricDialog(
        title: trBi('فتح قفل التطبيق', 'Unlock Application'),
        isDark: _isDark,
        onSuccess: () {
          setState(() => _isLocked = false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) {
      return widget.child;
    }

    final bg = _isDark ? AppColors.darkOuter : AppColors.lightBg;
    final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = _isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final borderColor = _isDark ? AppColors.borderDark : AppColors.borderLight;

    return Directionality(
      textDirection: AppLocaleController.instance.textDirection,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldActive.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.emeraldActive.withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldActive.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 42,
                      color: AppColors.emeraldActive,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    trBi('التطبيق مقفل 🔐', 'App Locked 🔐'),
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    trBi(
                      'يرجى تأكيد الهوية بالبصمة أو رمز PIN للمتابعة',
                      'Please verify your identity with biometrics or Master PIN to continue',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),

                  ElevatedButton.icon(
                    onPressed: _authenticateAndUnlock,
                    icon: const Icon(Icons.fingerprint_rounded, size: 26),
                    label: Text(
                      trBi('فتح بالبصمة', 'Unlock with Biometrics'),
                      style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldActive,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: _openPinUnlockDialog,
                    icon: const Icon(Icons.dialpad_rounded, size: 20),
                    label: Text(
                      trBi('استخدام رمز PIN الماستر', 'Use Master PIN Code'),
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: borderColor, width: 1.2),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: cardBg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

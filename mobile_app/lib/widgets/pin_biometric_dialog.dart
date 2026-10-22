import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/security/biometric_service.dart';
import '../data/repositories/strip_repository.dart';

class PinBiometricDialog extends StatefulWidget {
  final String title;
  final bool isDark;
  final Function() onSuccess;

  const PinBiometricDialog({
    super.key,
    required this.title,
    required this.isDark,
    required this.onSuccess,
  });

  @override
  State<PinBiometricDialog> createState() => _PinBiometricDialogState();
}

class _PinBiometricDialogState extends State<PinBiometricDialog> {
  final StripRepository _repo = StripRepository();
  String _pin = '';
  String _firstEnteredPin = '';
  String? _errorMessage;
  bool _isFirstTimeSetup = false;
  bool _isConfirming = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSetupState();
  }

  Future<void> _checkSetupState() async {
    final hasPin = await BiometricService.hasPin();
    if (!mounted) return;

    if (!hasPin) {
      setState(() {
        _isFirstTimeSetup = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isFirstTimeSetup = false;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometric();
      });
    }
  }

  Future<void> _triggerBiometric() async {
    if (_isFirstTimeSetup) return;
    final success = await BiometricService.authenticateBiometric(
      reason: 'المس مستشعر البصمة لفتح: ${widget.title}',
    );
    if (success && mounted) {
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  }

  Future<void> _handlePinComplete() async {
    if (_isFirstTimeSetup) {
      if (!_isConfirming) {
        // Step 1 done -> Go to step 2 (Confirm)
        setState(() {
          _firstEnteredPin = _pin;
          _pin = '';
          _isConfirming = true;
          _errorMessage = null;
        });
      } else {
        // Step 2 done -> Check if matches
        if (_pin == _firstEnteredPin) {
          // Save locally & on server
          await BiometricService.saveMasterPin(_pin);
          try {
            await _repo.setPin(_pin);
          } catch (_) {}
          if (mounted) {
            Navigator.of(context).pop();
            widget.onSuccess();
          }
        } else {
          setState(() {
            _errorMessage = 'الرمز غير متطابق! أعد المحاولة';
            _pin = '';
            _firstEnteredPin = '';
            _isConfirming = false;
          });
        }
      }
    } else {
      // Normal verification mode
      final valid = await BiometricService.verifyPin(_pin);
      if (valid) {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
        }
      } else {
        setState(() {
          _errorMessage = 'رمز PIN غير صحيح!';
          _pin = '';
        });
      }
    }
  }

  void _onKeyPress(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _errorMessage = null;
        _pin += digit;
      });
      if (_pin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Widget _buildKey(String digit) {
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;
    final keyBg = widget.isDark ? AppColors.cardMutedDark : AppColors.cardSurfaceLight;
    final textColor = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return GestureDetector(
      onTap: () => _onKeyPress(digit),
      child: Container(
        width: 60,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: keyBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Text(
          digit,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Dialog(
        backgroundColor: Colors.transparent,
        child: Center(child: CircularProgressIndicator(color: AppColors.honeyYellow)),
      );
    }

    final cardBg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final titleColor = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subtitleColor = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    String subtitleText;
    if (_isFirstTimeSetup) {
      subtitleText = _isConfirming
          ? 'أعد إدخال نفس الرمز للتأكيد'
          : 'عيّن رمز PIN الماستر الخاص بك (4 أرقام)';
    } else {
      subtitleText = 'المس مستشعر البصمة أو أدخل رمز PIN';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: widget.isDark ? const Color(0x60000000) : const Color(0x15000000),
              offset: const Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isFirstTimeSetup ? AppColors.honeyAmber.withOpacity(0.2) : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isFirstTimeSetup ? AppColors.honeyAmber : Colors.redAccent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFirstTimeSetup ? Icons.shield_rounded : Icons.lock_rounded,
                        size: 13,
                        color: _isFirstTimeSetup ? AppColors.honeyAmber : Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isFirstTimeSetup ? 'إعداد الحماية لأول مرة' : 'قفل المخرج',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _isFirstTimeSetup ? AppColors.honeyAmber : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: subtitleColor),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _isFirstTimeSetup ? 'حماية المشترك برمز PIN' : widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitleText,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 18),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.honeyYellow : Colors.transparent,
                    border: Border.all(
                      color: filled ? AppColors.honeyYellow : borderColor,
                      width: 1.8,
                    ),
                  ),
                );
              }),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Keypad (3x4)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildKey('1'), _buildKey('2'), _buildKey('3')],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildKey('4'), _buildKey('5'), _buildKey('6')],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildKey('7'), _buildKey('8'), _buildKey('9')],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Biometric Trigger Key
                    GestureDetector(
                      onTap: _isFirstTimeSetup ? null : _triggerBiometric,
                      child: Container(
                        width: 60,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _isFirstTimeSetup
                              ? Colors.transparent
                              : AppColors.honeyYellow.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isFirstTimeSetup ? Colors.transparent : AppColors.honeyYellow,
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          size: 26,
                          color: _isFirstTimeSetup ? Colors.transparent : AppColors.honeyYellow,
                        ),
                      ),
                    ),
                    _buildKey('0'),
                    // Backspace Key
                    GestureDetector(
                      onTap: _onBackspace,
                      child: Container(
                        width: 60,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor, width: 1.2),
                        ),
                        child: Icon(
                          Icons.backspace_outlined,
                          size: 20,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

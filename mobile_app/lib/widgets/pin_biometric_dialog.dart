import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/security/biometric_service.dart';

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
  String _pin = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Automatically trigger biometric check on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometric();
    });
  }

  Future<void> _triggerBiometric() async {
    final success = await BiometricService.authenticateBiometric(
      reason: 'المس مستشعر البصمة لفتح: ${widget.title}',
    );
    if (success && mounted) {
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  }

  Future<void> _checkPin() async {
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

  void _onKeyPress(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _errorMessage = null;
        _pin += digit;
      });
      if (_pin.length == 4) {
        _checkPin();
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
    return GestureDetector(
      onTap: () => _onKeyPress(digit),
      child: Container(
        width: 58,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.cardSurfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack,
            width: 2,
          ),
        ),
        child: Text(
          digit,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: widget.isDark ? Colors.white : AppColors.inkBlack,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.inkCardDecoration(
          isDark: widget.isDark,
          radius: 28,
          shadowOffset: 5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'قفل أمان',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'استخدم البصمة أو أدخل رمز الـ PIN',
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.honeyAmber : Colors.transparent,
                    border: Border.all(
                      color: widget.isDark ? AppColors.honeyYellow : AppColors.inkBlack,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Keypad (3x4)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildKey('1'), _buildKey('2'), _buildKey('3')],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildKey('4'), _buildKey('5'), _buildKey('6')],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildKey('7'), _buildKey('8'), _buildKey('9')],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Biometric Trigger Key
                    GestureDetector(
                      onTap: _triggerBiometric,
                      child: Container(
                        width: 58,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.honeyYellow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.inkBlack, width: 2),
                        ),
                        child: const Icon(Icons.fingerprint_rounded, size: 26, color: AppColors.inkBlack),
                      ),
                    ),
                    _buildKey('0'),
                    // Backspace Key
                    GestureDetector(
                      onTap: _onBackspace,
                      child: Container(
                        width: 58,
                        height: 52,
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.backspace_outlined,
                          size: 20,
                          color: widget.isDark ? Colors.white70 : AppColors.inkBlack,
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_locale.dart';
import '../../data/repositories/strip_repository.dart';
import '../home/home_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _repo = StripRepository();

  int _authMode = 0; // 0: Login, 1: Register, 2: Family Invite
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _confirmPasswordController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  String _tr(String key) => AppLocaleController.instance.tr(key);

  Future<void> _submitAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_authMode == 0) {
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        if (email.isEmpty || password.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = trBi(
              'يرجى إدخال البريد الإلكتروني وكلمة المرور',
              'Please enter both email and password',
            );
          });
          return;
        }

        final res = await _repo.login(email, password);
        setState(() => _isLoading = false);

        if (res['success'] == true && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
          );
        } else {
          setState(() => _errorMessage = res['message']);
        }
      } else if (_authMode == 1) {
        final fullName = _fullNameController.text.trim();
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        final confirmPassword = _confirmPasswordController.text;

        if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = trBi(
              'يرجى ملء جميع الحقول المطلوبة',
              'Please fill in all required fields',
            );
          });
          return;
        }

        if (password.length < 8 || !RegExp(r'[a-zA-Z]').hasMatch(password) || !RegExp(r'[0-9]').hasMatch(password)) {
          setState(() {
            _isLoading = false;
            _errorMessage = trBi(
              'كلمة المرور يجب ألا تقل عن 8 خانات وتحتوي على حروف وأرقام معاً',
              'Password must be at least 8 characters and contain letters & numbers',
            );
          });
          return;
        }

        if (password != confirmPassword) {
          setState(() {
            _isLoading = false;
            _errorMessage = trBi(
              'كلمة المرور وتأكيدها غير متطابقين',
              'Password confirmation does not match',
            );
          });
          return;
        }

        final res = await _repo.register(email, password, fullName);
        setState(() => _isLoading = false);

        if (res['success'] == true && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
          );
        } else {
          setState(() => _errorMessage = res['message']);
        }
      } else {
        final invite = _inviteController.text.trim();
        if (invite.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = trBi(
              'يرجى إدخال كود الدعوة المكون من 6 أرقام',
              'Please enter the 6-digit invite code',
            );
          });
          return;
        }

        final res = await _repo.loginInvite(invite);
        setState(() => _isLoading = false);

        if (res['success'] == true && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
          );
        } else {
          setState(() => _errorMessage = res['message']);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = trBi('حدث خطأ: $e', 'Error: $e');
      });
    }
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPasswordSheet(
        initialEmail: _emailController.text.trim(),
        onSuccess: (newEmail) {
          setState(() {
            _emailController.text = newEmail;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                trBi(
                  '✅ تم تحديث كلمة المرور بنجاح! يمكنك الآن تسجيل الدخول',
                  '✅ Password reset successfully! Please sign in',
                ),
              ),
              backgroundColor: AppColors.emeraldActive,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppLocaleController.instance,
        AppThemeController.instance,
      ]),
      builder: (context, _) {
        final isDark = AppThemeController.instance.isDark;
        final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
        final cardBg = isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
        final inputFill = isDark ? const Color(0xFF0F172A) : AppColors.cardMutedLight;
        final borderCol = isDark ? AppColors.darkBorder : AppColors.borderLight;
        final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

        return Directionality(
          textDirection: AppLocaleController.instance.textDirection,
          child: Scaffold(
            backgroundColor: bg,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- Top Header with Language & Theme Switcher Pills ---
                      Container(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Na7la Smart Power Strip ⚡',
                              style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: textSecondary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => AppThemeController.instance.toggleTheme(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.amber.withOpacity(0.12)
                                          : AppColors.emeraldActive.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.amber.withOpacity(0.5)
                                            : AppColors.emeraldActive.withOpacity(0.45),
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                          size: 14,
                                          color: isDark ? Colors.amber : AppColors.emeraldActive,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isDark
                                              ? trBi('نهاري', 'Light')
                                              : trBi('ليلي', 'Dark'),
                                          style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.amber : AppColors.emeraldActive,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => AppLocaleController.instance.toggleLanguage(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.emeraldActive.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.emeraldActive.withOpacity(0.5),
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.language_rounded, size: 14, color: AppColors.emeraldActive),
                                        const SizedBox(width: 5),
                                        Text(
                                          _tr('quick_switch_target'),
                                          style: GoogleFonts.cairo(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.emeraldActive,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Brand Header
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.emeraldActive, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emeraldActive.withOpacity(0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width: 62,
                          height: 62,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tr('app_title'),
                        style: GoogleFonts.cairo(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        _tr('brand_sub'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Main Auth Card Container
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderCol, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Mode Selector (3 Tabs: Login | Sign Up | Invite)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  _buildModeTab(_tr('tab_login'), 0, isDark),
                                  _buildModeTab(_tr('tab_register'), 1, isDark),
                                  _buildModeTab(_tr('tab_invite'), 2, isDark),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Error Banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900.withOpacity(isDark ? 0.3 : 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.redAccent.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : Colors.red.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Form Fields Based on Mode
                            if (_authMode == 0) ...[
                              _buildInputField(
                                label: _tr('lbl_email'),
                                hint: _tr('hint_email'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _tr('lbl_password'),
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _showForgotPasswordSheet,
                                    child: Text(
                                      _tr('forgot_pass_link'),
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.emeraldActive,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              _buildPasswordField(
                                hint: _tr('hint_password'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                                isDark: isDark,
                              ),
                            ] else if (_authMode == 1) ...[
                              _buildInputField(
                                label: _tr('lbl_name'),
                                hint: _tr('placeholder_name'),
                                controller: _fullNameController,
                                prefixIcon: Icons.person_outline_rounded,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                label: _tr('lbl_email'),
                                hint: _tr('hint_email'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                label: _tr('lbl_password'),
                                hint: _tr('hint_password'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                prefixIcon: Icons.lock_outline_rounded,
                                isDark: isDark,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20,
                                    color: AppColors.emeraldActive,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                label: _tr('lbl_confirm_pass'),
                                hint: _tr('hint_password'),
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                prefixIcon: Icons.lock_reset_rounded,
                                isDark: isDark,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20,
                                    color: AppColors.emeraldActive,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: inputFill,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderCol),
                                ),
                                child: Text(
                                  _tr('pass_guidelines'),
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                _tr('invite_hint'),
                                style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _inviteController,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                  color: textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: '849-201',
                                  hintStyle: GoogleFonts.jetBrainsMono(
                                    color: isDark ? Colors.white30 : Colors.black26,
                                  ),
                                  filled: true,
                                  fillColor: inputFill,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: borderCol, width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppColors.emeraldActive, width: 2),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Submit CTA Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _submitAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emeraldActive,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : Text(
                                      _authMode == 0
                                          ? _tr('btn_login')
                                          : (_authMode == 1 ? _tr('btn_register') : _tr('btn_invite_login')),
                                      style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w900),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeTab(String title, int mode, bool isDark) {
    final isSel = _authMode == mode;
    final unselectedColor = isDark ? Colors.white60 : AppColors.textSecondaryLight;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _authMode = mode;
            _errorMessage = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSel ? AppColors.emeraldActive : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
              color: isSel ? Colors.white : unselectedColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final fillCol = isDark ? const Color(0xFF0F172A) : AppColors.cardMutedLight;
    final borderCol = isDark ? const Color(0xFF334155) : AppColors.borderLight;
    final hintCol = isDark ? Colors.white30 : AppColors.textSecondaryLight.withOpacity(0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: textPrimary),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(fontSize: 11, color: hintCol),
            filled: true,
            fillColor: fillCol,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.emeraldActive) : null,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.emeraldActive, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String hint,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
    required bool isDark,
  }) {
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final fillCol = isDark ? const Color(0xFF0F172A) : AppColors.cardMutedLight;
    final borderCol = isDark ? const Color(0xFF334155) : AppColors.borderLight;
    final hintCol = isDark ? Colors.white30 : AppColors.textSecondaryLight.withOpacity(0.65);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(fontSize: 11, color: hintCol),
        filled: true,
        fillColor: fillCol,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.emeraldActive),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: AppColors.emeraldActive,
          ),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderCol, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emeraldActive, width: 1.8),
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  final ValueChanged<String> onSuccess;

  const _ForgotPasswordSheet({
    required this.initialEmail,
    required this.onSuccess,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _repo = StripRepository();

  int _step = 1; // 1: Email, 2: OTP, 3: New Password
  bool _isLoading = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNewPass = true;

  Timer? _countdownTimer;
  int _secondsLeft = 600;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 600);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String _formatTimer() {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _tr(String key) => AppLocaleController.instance.tr(key);

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = trBi('يرجى إدخال بريد إلكتروني صالح', 'Please enter a valid email'));
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await _repo.requestForgotPassword(email);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (res['otp_preview'] != null && res['otp_preview'].toString().isNotEmpty) {
        _otpCtrl.text = res['otp_preview'].toString();
      }
      setState(() => _step = 2);
      _startTimer();
    } else {
      setState(() => _error = res['message']);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = trBi('يرجى إدخال كود التحقق المكون من 6 أرقام', 'Please enter the 6-digit code'));
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await _repo.verifyOtp(_emailCtrl.text.trim(), otp);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _countdownTimer?.cancel();
      setState(() => _step = 3);
    } else {
      setState(() => _error = res['message']);
    }
  }

  Future<void> _submitReset() async {
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (newPass.length < 8 || !RegExp(r'[a-zA-Z]').hasMatch(newPass) || !RegExp(r'[0-9]').hasMatch(newPass)) {
      setState(() => _error = trBi(
          'كلمة المرور يجب ألا تقل عن 8 خانات وتحتوي على حروف وأرقام معاً',
          'Password must be 8+ chars and contain letters & numbers'));
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _error = trBi('كلمتا المرور غير متطابقتين', 'Passwords do not match'));
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await _repo.resetPassword(
      email: _emailCtrl.text.trim(),
      otp: _otpCtrl.text.trim(),
      newPassword: newPass,
      confirmPassword: confirmPass,
    );

    setState(() => _isLoading = false);

    if (res['success'] == true) {
      Navigator.of(context).pop();
      widget.onSuccess(_emailCtrl.text.trim());
    } else {
      setState(() => _error = res['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = AppThemeController.instance.isDark;
    final cardBg = isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.borderLight;
    final inputFill = isDark ? const Color(0xFF0F172A) : AppColors.cardMutedLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final hintCol = isDark ? Colors.white30 : AppColors.textSecondaryLight.withOpacity(0.65);

    return Directionality(
      textDirection: AppLocaleController.instance.textDirection,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + bottomInset,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderCol, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.6 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_reset_rounded, color: AppColors.emeraldActive, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _tr('forgot_modal_title'),
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(isDark ? 0.3 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.red.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_step == 1) ...[
                Text(
                  _tr('forgot_step1_desc'),
                  style: GoogleFonts.cairo(fontSize: 12, color: textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.cairo(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: _tr('lbl_email'),
                    labelStyle: GoogleFonts.cairo(color: textSecondary),
                    hintText: 'name@example.com',
                    hintStyle: GoogleFonts.cairo(color: hintCol),
                    filled: true,
                    fillColor: inputFill,
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.emeraldActive, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendOtp,
                  icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  label: Text(_tr('btn_send_otp'), style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldActive,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else if (_step == 2) ...[
                Text(
                  '${_tr('forgot_step2_desc')} ${_emailCtrl.text.trim()}',
                  style: GoogleFonts.cairo(fontSize: 12, color: textSecondary, height: 1.5),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _otpCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: AppColors.emeraldActive,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '123456',
                    hintStyle: GoogleFonts.jetBrainsMono(color: hintCol, letterSpacing: 8),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_tr('resend_after')} ${_formatTimer()}',
                      style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
                    ),
                    TextButton(
                      onPressed: _secondsLeft == 0 ? _sendOtp : null,
                      child: Text(
                        _tr('resend_code_link'),
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _secondsLeft == 0 ? AppColors.emeraldActive : hintCol,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldActive,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _tr('btn_verify_otp'),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ] else if (_step == 3) ...[
                Text(
                  _tr('forgot_step3_desc'),
                  style: GoogleFonts.cairo(fontSize: 12, color: textSecondary, height: 1.5),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNewPass,
                  style: GoogleFonts.cairo(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: _tr('lbl_new_pass'),
                    labelStyle: GoogleFonts.cairo(color: textSecondary),
                    filled: true,
                    fillColor: inputFill,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.emeraldActive, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPass ? Icons.visibility_off : Icons.visibility, color: textSecondary, size: 18),
                      onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureNewPass,
                  style: GoogleFonts.cairo(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: _tr('lbl_confirm_new_pass'),
                    labelStyle: GoogleFonts.cairo(color: textSecondary),
                    filled: true,
                    fillColor: inputFill,
                    prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.emeraldActive, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _tr('otp_hint_sec'),
                  style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldActive,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _tr('btn_save_pass_login'),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

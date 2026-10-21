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
        // --- Sign In ---
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        if (email.isEmpty || password.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = AppLocaleController.instance.isArabic
                ? 'يرجى إدخال البريد الإلكتروني وكلمة المرور'
                : 'Please enter both email and password';
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
        // --- Create Account (Sign Up) ---
        final fullName = _fullNameController.text.trim();
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        final confirmPassword = _confirmPasswordController.text;

        if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = AppLocaleController.instance.isArabic
                ? 'يرجى ملء جميع الحقول المطلوبة'
                : 'Please fill in all required fields';
          });
          return;
        }

        if (password.length < 8 || !RegExp(r'[a-zA-Z]').hasMatch(password) || !RegExp(r'[0-9]').hasMatch(password)) {
          setState(() {
            _isLoading = false;
            _errorMessage = AppLocaleController.instance.isArabic
                ? 'كلمة المرور يجب ألا تقل عن 8 خانات وتحتوي على حروف وأرقام معاً'
                : 'Password must be at least 8 characters and contain letters & numbers';
          });
          return;
        }

        if (password != confirmPassword) {
          setState(() {
            _isLoading = false;
            _errorMessage = AppLocaleController.instance.isArabic
                ? 'كلمة المرور وتأكيدها غير متطابقين'
                : 'Password confirmation does not match';
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
        // --- Family Invite Code ---
        final invite = _inviteController.text.trim();
        if (invite.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = AppLocaleController.instance.isArabic
                ? 'يرجى إدخال كود الدعوة المكون من 6 أرقام'
                : 'Please enter the 6-digit invite code';
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
        _errorMessage = 'حدث خطأ: $e';
      });
    }
  }

  // --- 3-Step Forgot Password Bottom Sheet ---
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
                AppLocaleController.instance.isArabic
                    ? '✅ تم تحديث كلمة المرور بنجاح! يمكنك الآن تسجيل الدخول'
                    : '✅ Password reset successfully! Please sign in',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocaleController.instance,
      builder: (context, _) {
        final isArabic = AppLocaleController.instance.isArabic;
        return Directionality(
          textDirection: AppLocaleController.instance.textDirection,
          child: Scaffold(
            backgroundColor: AppColors.darkBg,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- Sticky Top Header with Language Switcher Pill ---
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
                                color: Colors.white54,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => AppLocaleController.instance.toggleLanguage(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B1A16),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.honeyYellow.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.language_rounded, size: 14, color: AppColors.honeyYellow),
                                    const SizedBox(width: 5),
                                    Text(
                                      _tr('quick_switch_target'),
                                      style: GoogleFonts.cairo(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.honeyYellow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bee Mascot & Clean Brand Header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurfaceDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.honeyAmber, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.honeyAmber.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _tr('app_title'),
                        style: GoogleFonts.cairo(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _tr('brand_sub'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Main Auth Card Container
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurfaceDark,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.darkBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
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
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  _buildModeTab(_tr('tab_login'), 0),
                                  _buildModeTab(_tr('tab_register'), 1),
                                  _buildModeTab(_tr('tab_invite'), 2),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Error Banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900.withOpacity(0.3),
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
                                          color: Colors.white,
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
                              // --- Sign In Fields ---
                              _buildInputField(
                                label: _tr('lbl_email'),
                                hint: _tr('hint_email'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                              ),
                              const SizedBox(height: 12),
                              
                              // Password Label with "Forgot Password?" Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _tr('lbl_password'),
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _showForgotPasswordSheet,
                                    child: Text(
                                      _tr('forgot_pass_link'),
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.honeyAmber,
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
                              ),
                            ] else if (_authMode == 1) ...[
                              // --- Sign Up Fields ---
                              _buildInputField(
                                label: _tr('lbl_name'),
                                hint: _tr('placeholder_name'),
                                controller: _fullNameController,
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                label: _tr('lbl_email'),
                                hint: _tr('hint_email'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                label: _tr('lbl_password'),
                                hint: _tr('hint_password'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                prefixIcon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20,
                                    color: AppColors.honeyAmber,
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
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20,
                                    color: AppColors.honeyAmber,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Security Guidelines Box
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  _tr('pass_guidelines'),
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ] else ...[
                              // --- Invite Code Mode ---
                              Text(
                                _tr('invite_hint'),
                                style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _inviteController,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: '849-201',
                                  hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white30),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppColors.honeyAmber, width: 2),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Submit CTA Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _submitAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.honeyYellow,
                                foregroundColor: AppColors.inkBlack,
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
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
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

  Widget _buildModeTab(String title, int mode) {
    final isSel = _authMode == mode;
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
            color: isSel ? AppColors.honeyYellow : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
              color: isSel ? AppColors.inkBlack : Colors.white60,
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
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(fontSize: 11, color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.honeyAmber) : null,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.honeyAmber, width: 1.8),
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
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(fontSize: 11, color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.honeyAmber),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: AppColors.honeyAmber,
          ),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.honeyAmber, width: 1.8),
        ),
      ),
    );
  }
}

// ============================================================================
// 3-STEP FORGOT PASSWORD MODAL SHEET
// ============================================================================
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
  int _secondsLeft = 600; // 10 minutes

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

  // Step 1: Send OTP
  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = AppLocaleController.instance.isArabic ? 'يرجى إدخال بريد إلكتروني صالح' : 'Please enter a valid email');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await _repo.requestForgotPassword(email);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() => _step = 2);
      _startTimer();
    } else {
      setState(() => _error = res['message']);
    }
  }

  // Step 2: Verify OTP
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = AppLocaleController.instance.isArabic ? 'يرجى إدخال كود التحقق المكون من 6 أرقام' : 'Please enter the 6-digit code');
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

  // Step 3: Reset Password
  Future<void> _submitReset() async {
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (newPass.length < 8 || !RegExp(r'[a-zA-Z]').hasMatch(newPass) || !RegExp(r'[0-9]').hasMatch(newPass)) {
      setState(() => _error = AppLocaleController.instance.isArabic
          ? 'كلمة المرور يجب ألا تقل عن 8 خانات وتحتوي على حروف وأرقام معاً'
          : 'Password must be 8+ chars and contain letters & numbers');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _error = AppLocaleController.instance.isArabic ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match');
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
          color: AppColors.cardSurfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.darkBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_reset_rounded, color: AppColors.honeyAmber, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _tr('forgot_modal_title'),
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // STEP 1: Email Input
              if (_step == 1) ...[
                Text(
                  _tr('forgot_step1_desc'),
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.cairo(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: _tr('lbl_email'),
                    labelStyle: GoogleFonts.cairo(color: Colors.white70),
                    hintText: 'name@example.com',
                    hintStyle: GoogleFonts.cairo(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.honeyAmber, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendOtp,
                  icon: const Icon(Icons.send_rounded, size: 16, color: Colors.black),
                  label: Text(_tr('btn_send_otp'), style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.honeyYellow,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ]

              // STEP 2: OTP Verification
              else if (_step == 2) ...[
                Text(
                  '${_tr('forgot_step2_desc')} ${_emailCtrl.text.trim()}',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70, height: 1.5),
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
                    color: AppColors.honeyYellow,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '123456',
                    hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white24, letterSpacing: 8),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_tr('resend_after')} ${_formatTimer()}',
                      style: GoogleFonts.cairo(fontSize: 11, color: Colors.white60),
                    ),
                    TextButton(
                      onPressed: _secondsLeft == 0 ? _sendOtp : null,
                      child: Text(
                        _tr('resend_code_link'),
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _secondsLeft == 0 ? AppColors.honeyAmber : Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.honeyYellow,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _tr('btn_verify_otp'),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ),
              ]

              // STEP 3: Reset Password
              else if (_step == 3) ...[
                Text(
                  _tr('forgot_step3_desc'),
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNewPass,
                  style: GoogleFonts.cairo(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: _tr('lbl_new_pass'),
                    labelStyle: GoogleFonts.cairo(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.honeyAmber, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPass ? Icons.visibility_off : Icons.visibility, color: Colors.white60, size: 18),
                      onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureNewPass,
                  style: GoogleFonts.cairo(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: _tr('lbl_confirm_new_pass'),
                    labelStyle: GoogleFonts.cairo(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.honeyAmber, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _tr('otp_hint_sec'),
                  style: GoogleFonts.cairo(fontSize: 10, color: Colors.white54),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.honeyYellow,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _tr('btn_save_pass_login'),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.black),
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

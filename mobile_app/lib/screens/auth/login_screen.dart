import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/strip_repository.dart';
import '../home/home_dashboard_screen.dart';
import '../admin/admin_console_screen.dart';

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
            _errorMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور';
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
            _errorMessage = 'يرجى ملء جميع الحقول المطلوبة';
          });
          return;
        }

        if (password.length < 6) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'كلمة المرور يجب ألا تقل عن 6 خانات';
          });
          return;
        }

        if (password != confirmPassword) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'كلمة المرور وتأكيدها غير متطابقين';
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
            _errorMessage = 'يرجى إدخال كود الدعوة المكون من 6 أرقام';
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
        _errorMessage = 'حدث خطأ غير متوقع: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                    width: 70,
                    height: 70,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'نحلة IoT',
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'منظومة التحكم الذكي بالطاقة وحماية الأجهزة',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 22),

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
                            _buildModeTab('دخول', 0),
                            _buildModeTab('حساب جديد', 1),
                            _buildModeTab('كود عائلي 🔑', 2),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
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
                                    color: Colors.red.shade900,
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
                          label: 'البريد الإلكتروني',
                          hint: 'user@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          label: 'كلمة المرور',
                          hint: '••••••••',
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
                      ] else if (_authMode == 1) ...[
                        // --- Sign Up Fields ---
                        _buildInputField(
                          label: 'الاسم بالكامل',
                          hint: 'مثال: أحمد عصام',
                          controller: _fullNameController,
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          label: 'البريد الإلكتروني',
                          hint: 'user@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          label: 'كلمة المرور (6 خانات على الأقل)',
                          hint: '••••••••',
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
                          label: 'تأكيد كلمة المرور',
                          hint: '••••••••',
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
                      ] else ...[
                        // --- Invite Code Mode ---
                        Text(
                          'أدخل كود الدعوة العائلي المكون من 6 أرقام:',
                          style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _inviteController,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                          decoration: InputDecoration(
                            hintText: '849-201',
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.honeyAmber, width: 2),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

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
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(
                                _authMode == 0
                                    ? 'تسجيل الدخول'
                                    : (_authMode == 1 ? 'إنشاء الحساب وبدء الاستخدام 🚀' : 'دخول فوري للمشترك 🚀'),
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
}

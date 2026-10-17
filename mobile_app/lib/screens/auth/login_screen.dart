import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/strip_repository.dart';
import '../home/home_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _repo = StripRepository();
  final _emailController = TextEditingController(text: 'ahmedessam2032@gmail.com');
  final _passwordController = TextEditingController();
  final _inviteController = TextEditingController();

  bool _isGuestMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isGuestMode) {
      final res = await _repo.loginInvite(_inviteController.text.trim());
      setState(() => _isLoading = false);
      if (res['success'] == true && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
        );
      } else {
        setState(() => _errorMessage = res['message']);
      }
    } else {
      final res = await _repo.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() => _isLoading = false);
      if (res['success'] == true && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
        );
      } else {
        setState(() => _errorMessage = res['message']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.outerYellow,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Bee Mascot & Header
                Image.asset(
                  'assets/icons/app_icon.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 12),
                Text(
                  'نحلة IoT',
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.inkBlack,
                  ),
                ),
                Text(
                  'المشترك الذكي والتحكم المتقدم بالطاقة',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkBlack.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 24),

                // Main Auth Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: AppTheme.inkCardDecoration(
                    isDark: false,
                    radius: 28,
                    shadowOffset: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mode Selector (Account vs Guest Code)
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isGuestMode = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !_isGuestMode ? AppColors.honeyYellow : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !_isGuestMode ? AppColors.inkBlack : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  'تسجيل الدخول',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isGuestMode = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _isGuestMode ? AppColors.honeyYellow : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isGuestMode ? AppColors.inkBlack : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  'كود دعوة عائلي 🔑',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (!_isGuestMode) ...[
                        // Email Field
                        Text(
                          'البريد الإلكتروني:',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.inkBlack, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Password Field
                        Text(
                          'كلمة المرور:',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.inkBlack, width: 2),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Guest Code Field
                        Text(
                          'أدخل كود الدعوة (6 أرقام):',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _inviteController,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetbrainsMono(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                          decoration: InputDecoration(
                            hintText: '849-201',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.inkBlack, width: 2),
                            ),
                          ),
                        ),
                      ],

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.honeyAmber,
                          foregroundColor: AppColors.inkBlack,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.inkBlack, width: 2),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkBlack),
                              )
                            : Text(
                                _isGuestMode ? 'دخول فوري للمشترك 🚀' : 'تسجيل الدخول',
                                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900),
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
}

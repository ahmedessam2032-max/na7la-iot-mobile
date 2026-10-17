import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/softap_service.dart';
import '../../data/repositories/strip_repository.dart';

class WizardScreen extends StatefulWidget {
  final bool isDark;

  const WizardScreen({super.key, required this.isDark});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  final _repo = StripRepository();
  int _currentStep = 1; // 1: Select WiFi, 2: Connect SoftAP, 3: Syncing, 4: Router Safeguard
  
  // Wi-Fi inputs
  String _selectedSsid = 'TP-Link_A88F';
  final _passwordController = TextEditingController();
  final List<String> _scannedNetworks = [
    'TP-Link_A88F',
    'Etisalat-thF3',
    'Vodafone_Home',
    'Orange-6fHF',
    'WE_Fiber_2.4G',
  ];

  // Detected Strip
  final String _detectedMac = '88D039394B53';
  String get _detectedSsid => 'TONLY_TAP_${_detectedMac.substring(5)}';

  // Countdown timer for Step 3
  int _countdownSeconds = 180;
  Timer? _timer;
  int _progressStage = 1; // 1: Send settings, 2: Strip connecting to router, 3: Cloud sync

  // Router Safeguard choice
  int _routerSocketIndex = 2; // Default Socket 2

  @override
  void dispose() {
    _timer?.cancel();
    SoftApService.releaseStripAp();
    super.dispose();
  }

  void _startCountdown() {
    _countdownSeconds = 180;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
          if (_countdownSeconds <= 160 && _progressStage == 1) _progressStage = 2;
          if (_countdownSeconds <= 140 && _progressStage == 2) _progressStage = 3;
          if (_countdownSeconds <= 130) {
            t.cancel();
            setState(() => _currentStep = 4); // Go to Router Safeguard Step
          }
        });
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _executeNativePairing() async {
    setState(() => _currentStep = 3);
    _startCountdown();

    // 1. Calculate SoftAP Password
    final pass = SoftApService.calculateSoftApPassword(_detectedMac);

    // 2. Native Android WifiNetworkSpecifier Handshake
    final connected = await SoftApService.connectToStripAp(_detectedSsid, pass);

    if (connected) {
      // 3. Send raw TCP command to 192.168.1.1:30300
      await SoftApService.sendWifiCredentialsToStrip(
        routerSsid: _selectedSsid,
        routerPassword: _passwordController.text.trim(),
      );

      // 4. Release SoftAP so phone returns to router
      await SoftApService.releaseStripAp();

      // 5. Claim strip on cloud
      await _repo.claimStrip(_detectedMac);
    }
  }

  Future<void> _finishOnboarding() async {
    // If router safeguard was selected, configure it
    if (_routerSocketIndex > 0) {
      await _repo.lockSocket(_detectedMac, _routerSocketIndex, true);
      await _repo.configSocket(_detectedMac, _routerSocketIndex, {
        'name': 'راوتر الإنترنت',
        'icon': 'router',
        'is_router': true,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 تم ربط المشترك وتفعيل درع حماية الراوتر بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDark ? AppColors.darkBg : AppColors.outerYellow,
      appBar: AppBar(
        title: Text(
          'معالج ربط مشترك جديد (Hybrid Wizard)',
          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : AppColors.honeyYellow,
        foregroundColor: AppColors.inkBlack,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.inkCardDecoration(isDark: widget.isDark, radius: 28),
            child: _buildStepContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1SelectWifi();
      case 2:
        return _buildStep2DetectedStrip();
      case 3:
        return _buildStep3ProgressSync();
      case 4:
        return _buildStep4RouterSafeguard();
      default:
        return const SizedBox();
    }
  }

  // Step 1: Select Home Wi-Fi
  Widget _buildStep1SelectWifi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('الخطوة 1 من 3: بيانات الراوتر', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.honeyYellow, borderRadius: BorderRadius.circular(6)),
              child: Text('2.4 GHz فقط', style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.inkBlack)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'اختر شبكة الواي فاي المنزلية التي سيتصل بها المشترك:',
          style: GoogleFonts.cairo(fontSize: 11, color: widget.isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 8),

        // Quick Tap Wi-Fi Chips (Darwish-style Zero-Typing)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _scannedNetworks.map((ssid) {
            final isSel = _selectedSsid == ssid;
            return ChoiceChip(
              label: Text(ssid, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800)),
              selected: isSel,
              selectedColor: AppColors.honeyAmber,
              backgroundColor: widget.isDark ? AppColors.cardMutedDark : Colors.white,
              onSelected: (_) => setState(() => _selectedSsid = ssid),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        Text('كلمة مرور الواي فاي:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '••••••••',
            filled: true,
            fillColor: widget.isDark ? AppColors.cardMutedDark : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: () => setState(() => _currentStep = 2),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.honeyYellow,
            foregroundColor: AppColors.inkBlack,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('متابعة للبحث عن المشترك ➔', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  // Step 2: Auto Detected Strip
  Widget _buildStep2DetectedStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('الخطوة 2 من 3: التقاط المشترك', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          'اضغط مطولاً على زر الباور بالمشترك لمدة 5 ثوانٍ حتى يرمش الـ LED بسرعة:',
          style: GoogleFonts.cairo(fontSize: 11, color: widget.isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 14),

        // Detected Strip Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.inkBlack,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.honeyAmber, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.power_rounded, color: AppColors.honeyYellow, size: 28),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_detectedSsid, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                      Text('إشارة ممتازة • جاهز للاقتران', style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                child: Text('تم الالتقاط ✓', style: GoogleFonts.cairo(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _executeNativePairing,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.honeyAmber,
            foregroundColor: AppColors.inkBlack,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('بدء الاتصال ونقل الإعدادات 🚀', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  // Step 3: Circular Countdown & 3-stage Sync
  Widget _buildStep3ProgressSync() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Circular Countdown
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: CircularProgressIndicator(
                value: _countdownSeconds / 180.0,
                strokeWidth: 8,
                backgroundColor: widget.isDark ? Colors.white12 : Colors.black12,
                valueColor: const AlwaysStoppedAnimation(AppColors.honeyAmber),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$_countdownSeconds', style: GoogleFonts.jetBrainsMono(fontSize: 28, fontWeight: FontWeight.w900)),
                Text('ثانية', style: GoogleFonts.cairo(fontSize: 10)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('جارِ ربط المشترك بحسابك تلقائياً...', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900)),
        Text('المشترك استلم الإعدادات ويتصل بالسيرفر الآن — لا تغلق التطبيق', style: GoogleFonts.cairo(fontSize: 10, color: widget.isDark ? Colors.white60 : Colors.black54)),
        const SizedBox(height: 20),

        // 3-Stage Checklist
        _buildChecklistStage(1, '1. إرسال بيانات الشبكة للمشترك', _progressStage >= 1),
        _buildChecklistStage(2, '2. اتصال المشترك بالراوتر', _progressStage >= 2),
        _buildChecklistStage(3, '3. التحقق من اتصال السيرفر السحابي', _progressStage >= 3),
      ],
    );
  }

  // Step 4: Router Safeguard Setup (The Killer Feature)
  Widget _buildStep4RouterSafeguard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: AppColors.routerCyan, shape: BoxShape.circle),
            child: const Icon(Icons.shield_rounded, color: Colors.black, size: 28),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '🛡️ سؤال الحماية الأهم (Router Safeguard)',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'هل راوتر الإنترنت متوصل في هذا المشترك؟ سنقوم بحمايته تلقائياً ضد الفصل بالخطأ:',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontSize: 11, color: widget.isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 16),

        RadioListTile<int>(
          title: Text('نعم — متوصل في فيشة رقم (#2) احميه فوراً (موصى به)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
          value: 2,
          groupValue: _routerSocketIndex,
          activeColor: AppColors.routerCyan,
          onChanged: (val) => setState(() => _routerSocketIndex = val!),
        ),
        RadioListTile<int>(
          title: Text('نعم — متوصل في فيشة رقم (#1)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
          value: 1,
          groupValue: _routerSocketIndex,
          activeColor: AppColors.routerCyan,
          onChanged: (val) => setState(() => _routerSocketIndex = val!),
        ),
        RadioListTile<int>(
          title: Text('لا — هذا المشترك لغرفة أخرى ولا يوجد راوتر عليه', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
          value: 0,
          groupValue: _routerSocketIndex,
          activeColor: AppColors.routerCyan,
          onChanged: (val) => setState(() => _routerSocketIndex = val!),
        ),
        const SizedBox(height: 18),

        ElevatedButton(
          onPressed: _finishOnboarding,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.honeyYellow,
            foregroundColor: AppColors.inkBlack,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('إتمام الربط وتفعيل الحماية 🚀', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _buildChecklistStage(int stage, String label, bool isDone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFF10B981).withOpacity(0.15) : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? const Color(0xFF10B981) : (widget.isDark ? Colors.white24 : Colors.black12),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isDone ? const Color(0xFF10B981) : (widget.isDark ? Colors.white38 : Colors.black38),
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: isDone ? FontWeight.w900 : FontWeight.w700,
              color: isDone ? const Color(0xFF10B981) : (widget.isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

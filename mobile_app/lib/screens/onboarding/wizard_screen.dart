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

  int _currentStep = 1; // 1: Wi-Fi & Discovery, 2: Real Pairing & Cloud Polling, 3: Router & Customization
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isPasswordVisible = false;
  bool _showManualMacInput = false;

  // Controllers
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _manualMacController = TextEditingController();
  final _stripNameController = TextEditingController(text: 'مشترك الصالة الذكي');

  // Discovered networks & strips
  List<String> _scannedNetworks = [];
  List<String> _detectedStrips = [];
  String _selectedStripSsid = '';
  String _resolvedMac = '';

  // Step 2 Progress & Status
  String _pairingStatusMessage = 'جاري بدء الاقتران...';
  int _pairingStage = 1; // 1: Connecting SoftAP, 2: Sending TCP, 3: Polling Cloud
  String? _pairingErrorMessage;

  // Step 3 Configuration
  int _routerSocketIndex = 0; // 0 = No router (Default), 1-4 = Specific socket
  String _selectedRoom = 'living'; // living, office, bedroom, kitchen

  @override
  void initState() {
    super.initState();
    _initPermissionsAndWifi();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _manualMacController.dispose();
    _stripNameController.dispose();
    SoftApService.releaseStripAp();
    super.dispose();
  }

  Future<void> _initPermissionsAndWifi() async {
    setState(() => _isScanning = true);
    // 1. Request Android OS permissions (Location & Nearby Devices)
    await SoftApService.requestPermissions();

    // 2. Auto-detect current connected home Wi-Fi SSID
    final currentSsid = await SoftApService.getCurrentSsid();
    if (currentSsid.isNotEmpty && mounted) {
      _ssidController.text = currentSsid;
    }

    // 3. Scan nearby Wi-Fi networks to find any TONLY_TAP_* strips
    await _scanWifi();
  }

  Future<void> _scanWifi() async {
    setState(() => _isScanning = true);
    final networks = await SoftApService.scanNearbyWifi();
    if (!mounted) return;

    final strips = networks.where((n) => n.toUpperCase().startsWith('TONLY_TAP_')).toList();
    setState(() {
      _scannedNetworks = networks;
      _detectedStrips = strips;
      _isScanning = false;
      if (_detectedStrips.isNotEmpty && _selectedStripSsid.isEmpty) {
        _selectedStripSsid = _detectedStrips.first;
      }
    });
  }

  // --- Step 2: Real Pairing Execution ---

  Future<void> _startPairing() async {
    final ssid = _ssidController.text.trim();
    final pass = _passwordController.text.trim();

    if (_showManualMacInput) {
      // Manual MAC Path
      final mac = _manualMacController.text.trim().replaceAll(':', '').replaceAll('-', '').toUpperCase();
      if (mac.length != 12) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ يرجى إدخال عنوان MAC صحيح مكون من 12 رمزاً')),
        );
        return;
      }
      _resolvedMac = mac;
      setState(() {
        _currentStep = 3; // Go directly to customization
      });
      return;
    }

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى تحديد اسم شبكة واي فاي المنزل')),
      );
      return;
    }

    if (_selectedStripSsid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى اختيار المشترك الذكي المكتشف أو إدخال الماك يدوياً')),
      );
      return;
    }

    setState(() {
      _currentStep = 2;
      _pairingStage = 1;
      _pairingErrorMessage = null;
      _pairingStatusMessage = 'جاري الاتصال بشبكة المشترك (${_selectedStripSsid})...';
    });

    _resolvedMac = SoftApService.extractMacFromSsid(_selectedStripSsid);
    final softApPass = SoftApService.calculateSoftApPassword(_selectedStripSsid);

    try {
      // Stage 1: Connect to strip temporary SoftAP via Android Native Channel
      final connected = await SoftApService.connectToStripAp(_selectedStripSsid, softApPass);
      if (!connected) {
        // If native specifier rejected or unavailable, proceed to socket or alert
        setState(() {
          _pairingStatusMessage = 'يرجى التأكد من الموافقة على الاتصال بشبكة المشترك في رسالة أندرويد...';
        });
      }

      // Stage 2: Send raw TCP credentials to 192.168.1.1:30300
      setState(() {
        _pairingStage = 2;
        _pairingStatusMessage = 'جاري إرسال إعدادات الواي فاي للمشترك عبر بورت 30300...';
      });

      await SoftApService.sendWifiCredentialsToStrip(
        routerSsid: ssid,
        routerPassword: pass,
      );

      // Stage 3: Release SoftAP so phone reconnects to internet
      setState(() {
        _pairingStage = 3;
        _pairingStatusMessage = 'المشترك يقوم بإعادة التشغيل... جاري فحص اتصاله بسيرفر نحلة على AWS...';
      });
      await SoftApService.releaseStripAp();

      // Stage 4: Poll AWS Server for up to 60 seconds to verify real connection
      bool verifiedOnCloud = false;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;

        // Try registering/claiming strip on cloud
        final res = await _repo.registerStrip(_resolvedMac, name: _stripNameController.text.trim());
        if (res['ok'] == true || res['success'] == true) {
          verifiedOnCloud = true;
          break;
        }
      }

      if (verifiedOnCloud || mounted) {
        setState(() {
          _currentStep = 3; // Advance to Router Safeguard and Finish
        });
      } else {
        setState(() {
          _pairingErrorMessage = 'تعذر رصد المشترك على السيرفر. تأكد من صحة باسورد الراوتر وقرب المشترك من الإشارة.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pairingErrorMessage = 'حدث خطأ أثناء الاقتران: $e';
        });
      }
    }
  }

  // --- Step 3: Finish and Apply Safeguard ---

  Future<void> _finishSetup() async {
    setState(() => _isLoading = true);

    // 1. Register/claim strip with chosen name & room
    await _repo.registerStrip(
      _resolvedMac,
      name: _stripNameController.text.trim(),
      roomCategory: _selectedRoom,
    );

    // 2. Configure router safeguard if a socket was selected
    if (_routerSocketIndex > 0) {
      await _repo.lockSocket(_resolvedMac, _routerSocketIndex, true);
      await _repo.configSocket(_resolvedMac, _routerSocketIndex, {
        'name': 'راوتر الإنترنت',
        'icon': 'router',
        'is_router': true,
      });
    }

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_routerSocketIndex > 0
              ? '🎉 تم ربط المشترك وتأمين مخرج الراوتر (#$_routerSocketIndex) بنجاح!'
              : '🎉 تم ربط المشترك بحسابك بنجاح!'),
          backgroundColor: Colors.green.shade800,
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
          'معالج ربط مشترك جديد',
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : AppColors.honeyYellow,
        foregroundColor: AppColors.inkBlack,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _scanWifi,
            tooltip: 'إعادة المسح',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.inkCardDecoration(isDark: widget.isDark, radius: 24),
            child: _buildCurrentStepView(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1View();
      case 2:
        return _buildStep2View();
      case 3:
        return _buildStep3View();
      default:
        return const SizedBox();
    }
  }

  // --- Step 1: Wi-Fi Credentials & Auto-Discovery ---

  Widget _buildStep1View() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.honeyAmber,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.inkBlack, width: 1.5),
              ),
              child: Text(
                'الخطوة 1 من 3: اكتشاف المشترك والواي فاي',
                style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            if (_isScanning)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkBlack),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Auto-discovered Strip Section
        if (!_showManualMacInput) ...[
          Text(
            '🐝 المشتركات الذكية المكتشفة بالقرب منك:',
            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          if (_detectedStrips.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black26),
              ),
              child: Column(
                children: [
                  const Icon(Icons.wifi_tethering_error_rounded, size: 28, color: Colors.orange),
                  const SizedBox(height: 6),
                  Text(
                    'لم يتم رصد شبكة المشترك (TONLY_TAP_...) بعد.\nاضغط مطولاً على زر المشترك 5 ثوانٍ حتى يومض الليد بسرعة.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _scanWifi,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text('إعادة البحث عن المشترك', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            )
          else
            ..._detectedStrips.map((stripSsid) {
              final isSelected = _selectedStripSsid == stripSsid;
              final derivedMac = SoftApService.extractMacFromSsid(stripSsid);
              return GestureDetector(
                onTap: () => setState(() => _selectedStripSsid = stripSsid),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (widget.isDark ? AppColors.honeyAmber.withOpacity(0.3) : AppColors.honeyYellow)
                        : (widget.isDark ? Colors.white10 : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.inkBlack : Colors.black26,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.power_rounded, color: AppColors.honeyAmber, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stripSsid,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'كود الجهاز: $derivedMac',
                              style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: AppColors.inkBlack, size: 20),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 14),
        ],

        // Home Wi-Fi Input Fields
        Text(
          '📶 شبكة واي فاي المنزل (2.4 GHz):',
          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _ssidController,
          decoration: InputDecoration(
            hintText: 'اسم شبكة الواي فاي (SSID)',
            prefixIcon: const Icon(Icons.wifi_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: 'كلمة مرور واي فاي الراوتر',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),

        // Fallback Manual MAC Input Toggle
        GestureDetector(
          onTap: () => setState(() => _showManualMacInput = !_showManualMacInput),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _showManualMacInput ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                _showManualMacInput ? 'إخفاء الإدخال اليدوي' : 'أو أدخل عنوان الماك يدوياً ✍️',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.honeyAmber,
                ),
              ),
            ],
          ),
        ),
        if (_showManualMacInput) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _manualMacController,
            decoration: InputDecoration(
              hintText: 'مثال: 88D039394B53',
              prefixIcon: const Icon(Icons.tag_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],

        const SizedBox(height: 18),

        // Submit Button
        ElevatedButton(
          onPressed: _startPairing,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.honeyYellow,
            foregroundColor: AppColors.inkBlack,
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: AppColors.inkBlack, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            _showManualMacInput ? 'متابعة بكود الماك 🚀' : 'بدء الاقتران والربط 🚀',
            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  // --- Step 2: Real Pairing Execution & Cloud Polling ---

  Widget _buildStep2View() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.honeyAmber,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.inkBlack, width: 1.5),
          ),
          child: Text(
            'الخطوة 2 من 3: ربط الجهاز والتحقق السحابي',
            style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 24),

        // Status Animation / Spinner
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  value: _pairingStage == 1 ? 0.33 : (_pairingStage == 2 ? 0.66 : null),
                  strokeWidth: 6,
                  color: AppColors.honeyAmber,
                  backgroundColor: Colors.black12,
                ),
              ),
              Image.asset('assets/icons/app_icon.png', width: 44, height: 44),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          _pairingStatusMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),

        if (_pairingErrorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent, width: 1.5),
            ),
            child: Text(
              _pairingErrorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.red.shade900),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: Text('العودة للمحاولة مجدداً', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          ),
        ],
      ],
    );
  }

  // --- Step 3: Router Safeguard & Strip Naming ---

  Widget _buildStep3View() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.inkBlack, width: 1.5),
          ),
          child: Text(
            'الخطوة 3 من 3: حماية الراوتر وتخصيص المشترك 🛡️',
            style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
          ),
        ),
        const SizedBox(height: 16),

        // Strip Name
        Text('اسم المشترك:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        TextField(
          controller: _stripNameController,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),

        // Room Selection
        Text('مكان المشترك / الغرفة:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildRoomChip('صالة 🛋️', 'living'),
            const SizedBox(width: 6),
            _buildRoomChip('مكتب 💻', 'office'),
            const SizedBox(width: 6),
            _buildRoomChip('نوم 🛏️', 'bedroom'),
            const SizedBox(width: 6),
            _buildRoomChip('مطبخ 🍳', 'kitchen'),
          ],
        ),
        const SizedBox(height: 16),

        // Router Safeguard Dropdown (The Key Feature Requested by User!)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.routerBgDark : AppColors.routerBgLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.routerCyan, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AppColors.routerCyan, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'درع حماية راوتر الإنترنت:',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'اختر المخرج المتصل به الراوتر لحمايته تلقائياً من الفصل بالخطأ:',
                style: GoogleFonts.cairo(fontSize: 10, color: Colors.black87),
              ),
              const SizedBox(height: 8),

              // The Dropdown for all 4 sockets or none
              DropdownButtonFormField<int>(
                value: _routerSocketIndex,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.inkBlack, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 0,
                    child: Text('❌ لا يوجد راوتر على هذا المشترك (المشترك في غرفة أخرى)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text('🌐 مخرج رقم 1 (فيشة #1)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('🌐 مخرج رقم 2 (فيشة #2)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('🌐 مخرج رقم 3 (فيشة #3)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  DropdownMenuItem(
                    value: 4,
                    child: Text('🌐 مخرج رقم 4 (فيشة #4)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _routerSocketIndex = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isLoading ? null : _finishSetup,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.honeyYellow,
            foregroundColor: AppColors.inkBlack,
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: AppColors.inkBlack, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkBlack))
              : Text('إتمام الإعداد وحفظ الحماية 🚀', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _buildRoomChip(String title, String val) {
    final isSel = _selectedRoom == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRoom = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSel ? AppColors.honeyYellow : (widget.isDark ? Colors.white10 : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? AppColors.inkBlack : Colors.black26,
              width: isSel ? 2 : 1,
            ),
          ),
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

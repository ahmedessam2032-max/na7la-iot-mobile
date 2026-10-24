import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_locale.dart';
import '../../data/services/softap_service.dart';
import '../../data/repositories/strip_repository.dart';

class WizardScreen extends StatefulWidget {
  final bool isDark;

  const WizardScreen({super.key, required this.isDark});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> with WidgetsBindingObserver {
  final _repo = StripRepository();

  int _currentStep = 1; // 1: Wi-Fi & Discovery, 2: Auto Pairing & Cloud Verification, 3: Customization & Router Guard
  bool _isLoading = false;
  bool _isScanning = false;
  bool _hasPermissions = true;
  bool _isLocationDisabled = false;
  bool _isPasswordVisible = false;
  bool _showManualMacInput = false;
  bool _phoneMissingInternetInStep2 = false;
  Timer? _autoScanTimer;

  // Controllers
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _manualMacController = TextEditingController();
  final _stripNameController = TextEditingController(
    text: AppLocaleController.instance.isArabic ? 'مشترك الصالة الذكي' : 'Smart Living Strip',
  );

  // Discovered networks & strips
  List<WifiNetworkInfo> _scannedDetailedNetworks = [];
  List<String> _detectedStrips = [];
  String _selectedStripSsid = '';
  String _resolvedMac = '';

  // Step 2 Progress & Status
  String _pairingStatusMessage = '';
  int _pairingStage = 1; // 1: Connecting SoftAP, 2: Sending TCP, 3: Waiting Internet & Polling Cloud
  String? _pairingErrorMessage;

  // Step 3 Configuration
  int _routerSocketIndex = 0; // 0 = No router, 1-4 = Specific socket
  String _selectedRoom = 'living'; // living, office, bedroom, kitchen

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPermissionsAndWifi();
    _startPeriodicDiscovery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoScanTimer?.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    _manualMacController.dispose();
    _stripNameController.dispose();
    SoftApService.releaseStripAp();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      if (_currentStep == 1) {
        _scanWifi();
      }
    }
  }

  void _startPeriodicDiscovery() {
    _autoScanTimer?.cancel();
    _autoScanTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _currentStep == 1 && !_isScanning && _detectedStrips.isEmpty && !_showManualMacInput) {
        _scanWifi(silent: true);
      }
    });
  }

  Future<void> _initPermissionsAndWifi() async {
    setState(() => _isScanning = true);

    // 1. Request Android OS permissions ONLY when entering WizardScreen
    final granted = await SoftApService.requestPermissions();
    if (mounted) {
      setState(() => _hasPermissions = granted);
    }

    // 2. Check if Location (GPS) is enabled in Android system settings
    final isLocOn = await SoftApService.isLocationEnabled();
    if (mounted) {
      setState(() => _isLocationDisabled = !isLocOn);
    }

    // 3. Auto-detect current connected home Wi-Fi SSID
    final currentSsid = await SoftApService.getCurrentSsid();
    if (currentSsid.isNotEmpty &&
        !currentSsid.toUpperCase().startsWith('TONLY_TAP_') &&
        !currentSsid.toUpperCase().startsWith('ONLY_TAP_') &&
        mounted) {
      _ssidController.text = currentSsid;
    }

    // 4. Scan nearby Wi-Fi networks for both TONLY_TAP_* strips and 2.4GHz routers
    await _scanWifi();
  }

  Future<void> _scanWifi({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isScanning = true);
    }

    final isLocOn = await SoftApService.isLocationEnabled();
    final hasPerm = await SoftApService.hasPermissions();
    if (mounted) {
      setState(() {
        _isLocationDisabled = !isLocOn;
        _hasPermissions = hasPerm;
      });
    }

    // Also refresh current SSID if field is still empty
    if (_ssidController.text.trim().isEmpty) {
      final currentSsid = await SoftApService.getCurrentSsid();
      if (currentSsid.isNotEmpty &&
          !currentSsid.toUpperCase().startsWith('TONLY_TAP_') &&
          !currentSsid.toUpperCase().startsWith('ONLY_TAP_') &&
          mounted) {
        _ssidController.text = currentSsid;
      }
    }

    final networks = await SoftApService.scanNearbyWifiDetailed();
    if (!mounted) return;

    final strips = networks
        .map((n) => n.ssid)
        .where((s) => s.toUpperCase().startsWith('TONLY_TAP_') || s.toUpperCase().startsWith('ONLY_TAP_'))
        .toList();

    setState(() {
      _scannedDetailedNetworks = networks;
      _detectedStrips = strips;
      _isScanning = false;
      if (_detectedStrips.isNotEmpty &&
          (_selectedStripSsid.isEmpty || !_detectedStrips.contains(_selectedStripSsid))) {
        _selectedStripSsid = _detectedStrips.first;
      }
    });
  }

  List<WifiNetworkInfo> get _routerNetworks {
    return _scannedDetailedNetworks
        .where((n) =>
            !n.ssid.toUpperCase().startsWith('TONLY_TAP_') &&
            !n.ssid.toUpperCase().startsWith('ONLY_TAP_'))
        .toList();
  }

  void _showRouterNetworkPicker() async {
    if (_routerNetworks.isEmpty && !_isScanning) {
      await _scanWifi();
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final routers = _routerNetworks;
            final cardBg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
            final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
            final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

            return Directionality(
              textDirection: AppLocaleController.instance.textDirection,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: textSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldActive.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.router_rounded, color: AppColors.emeraldActive, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trBi('اختر شبكة واي فاي المنزل', 'Select Home Wi-Fi Network'),
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                trBi(
                                  'يرجى اختيار شبكة تعمل بتردد 2.4 GHz',
                                  'Please choose a 2.4 GHz network',
                                ),
                                style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            setModalState(() => _isScanning = true);
                            await _scanWifi();
                            if (ctx.mounted) setModalState(() {});
                          },
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.emeraldActive,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, color: AppColors.emeraldActive),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (routers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Column(
                          children: [
                            Icon(Icons.wifi_find_rounded, size: 40, color: textSecondary),
                            const SizedBox(height: 10),
                            Text(
                              trBi(
                                'لم يتم العثور على شبكات قريبة. تأكد من تفعيل الموقع والواي فاي ثم اضغط تحديث.',
                                'No nearby networks found. Ensure Location & Wi-Fi are enabled and tap refresh.',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: routers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final net = routers[idx];
                            final isSelected = _ssidController.text.trim() == net.ssid;
                            final is24 = net.is24GHz;

                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() {
                                  _ssidController.text = net.ssid;
                                });
                                Navigator.of(ctx).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.emeraldActive.withOpacity(0.12)
                                      : (widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.emeraldActive
                                        : (widget.isDark ? AppColors.borderDark : AppColors.borderLight),
                                    width: isSelected ? 1.6 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.wifi_rounded,
                                      color: is24 ? AppColors.emeraldActive : AppColors.warningAmber,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        net.ssid,
                                        textDirection: TextDirection.ltr,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: is24
                                            ? AppColors.emeraldActive.withOpacity(0.15)
                                            : AppColors.warningAmber.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        is24 ? '2.4 GHz ✓' : '5 GHz ⚠️',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: is24 ? AppColors.emeraldActive : AppColors.warningAmber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Step 2: Real Pairing Execution ---

  Future<void> _startPairing() async {
    final ssid = _ssidController.text.trim();
    final pass = _passwordController.text.trim();

    if (_showManualMacInput) {
      final mac = _manualMacController.text.trim().replaceAll(':', '').replaceAll('-', '').toUpperCase();
      if (mac.length != 12) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trBi(
                '⚠️ يرجى إدخال عنوان MAC صحيح مكون من 12 رمزاً',
                '⚠️ Please enter a valid 12-character MAC address',
              ),
            ),
          ),
        );
        return;
      }
      _resolvedMac = mac;
      setState(() {
        _currentStep = 3;
      });
      return;
    }

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trBi(
              '⚠️ يرجى اختيار أو كتابة اسم شبكة الواي فاي المنزلية (SSID)',
              '⚠️ Please select or enter your home Wi-Fi network (SSID)',
            ),
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    if (ssid.contains(':') || pass.contains(':')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trBi(
              '⚠️ اسم الشبكة أو كلمة المرور لا يمكن أن يحتوي على الرمز (:)',
              '⚠️ Wi-Fi SSID or password cannot contain a colon (:)',
            ),
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    final selectedNetInfo = _scannedDetailedNetworks.firstWhere(
      (n) => n.ssid == ssid,
      orElse: () => WifiNetworkInfo(ssid: ssid, frequency: 2412, is24GHz: true, level: -50),
    );
    if (!selectedNetInfo.is24GHz && selectedNetInfo.frequency > 4900) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trBi(
              '⚠️ تنبيه: الشبكة المختارة تعمل بتردد 5 GHz فقط! المشترك الذكي يتطلب شبكة 2.4 GHz.',
              '⚠️ Warning: Selected network is 5 GHz only! The smart strip requires 2.4 GHz.',
            ),
          ),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (_selectedStripSsid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trBi(
              '⚠️ يرجى اختيار المشترك الذكي المكتشف (TONLY_TAP_...) أولاً',
              '⚠️ Please select the discovered smart strip (TONLY_TAP_...) first',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _currentStep = 2;
      _pairingStage = 1;
      _pairingErrorMessage = null;
      _phoneMissingInternetInStep2 = false;
      _pairingStatusMessage = trBi(
        'جاري الاتصال بشبكة المشترك ($_selectedStripSsid)...\nيرجى الضغط على "اتصال / Connect" في نافذة النظام.',
        'Connecting to strip ($_selectedStripSsid)...\nPlease tap "Connect" on the system prompt.',
      );
    });

    _resolvedMac = SoftApService.extractMacFromSsid(_selectedStripSsid);
    final softApPass = SoftApService.calculateSoftApPassword(_selectedStripSsid);

    try {
      // Stage 1: Connect to strip temporary SoftAP via Android Native Channel
      final connected = await SoftApService.connectToStripAp(_selectedStripSsid, softApPass);
      if (!connected && mounted) {
        setState(() {
          _pairingErrorMessage = trBi(
            'لم يتم الاتصال بشبكة المشترك ($_selectedStripSsid). تأكد من وميض لمبة المشترك والموافقة على نافذة الاتصال.',
            'Could not connect to strip ($_selectedStripSsid). Ensure the strip LED is blinking and approve the connection prompt.',
          );
        });
        return;
      }

      // Stage 2: Send 3-command protocol (up:ip: -> up:connect: -> up:reboot:0)
      if (mounted) {
        setState(() {
          _pairingStage = 2;
          _pairingStatusMessage = trBi(
            'تم الاتصال بالمشترك بنجاح! جاري إرسال بيانات الواي فاي ($ssid) وإعادة تشغيل المشترك...',
            'Connected to strip! Sending Wi-Fi credentials ($ssid) and rebooting strip...',
          );
        });
      }

      await SoftApService.sendWifiCredentialsToStrip(
        routerSsid: ssid,
        routerPassword: pass,
      );

      // Stage 3: Release SoftAP so phone reconnects to internet
      if (mounted) {
        setState(() {
          _pairingStage = 3;
          _pairingStatusMessage = trBi(
            'المشترك يعيد التشغيل الآن ويتصل بالراوتر...\nجاري استعادة إنترنت الهاتف والتحقق من السيرفر السحابي...',
            'Strip is rebooting and joining your router...\nRestoring phone internet & verifying cloud connection...',
          );
        });
      }
      await SoftApService.releaseStripAp();

      // Wait briefly for phone Wi-Fi / internet to come back, then poll cloud
      bool verifiedOnCloud = false;
      bool registeredOnce = false;

      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;

        final hasNet = await SoftApService.hasInternetConnection();
        if (!hasNet && i >= 1) {
          setState(() {
            _phoneMissingInternetInStep2 = true;
            _pairingStatusMessage = trBi(
              'تم إرسال الإعدادات للمشترك بنجاح ✅\nيرجى التأكد من إعادة اتصال هاتفك بشبكة الواي فاي المنزلية لاستكمال التفعيل السحابي.',
              'Settings sent to strip successfully ✅\nPlease ensure your phone is reconnected to your home Wi-Fi to complete cloud activation.',
            );
          });
        } else if (hasNet) {
          if (_phoneMissingInternetInStep2) {
            setState(() {
              _phoneMissingInternetInStep2 = false;
              _pairingStatusMessage = trBi(
                'تم استعادة اتصال الإنترنت! جاري تأكيد ظهور المشترك أونلاين على السيرفر...',
                'Internet restored! Confirming strip online status on cloud server...',
              );
            });
          }
          if (!registeredOnce) {
            try {
              await _repo.registerStrip(_resolvedMac, name: _stripNameController.text.trim());
              registeredOnce = true;
            } catch (_) {}
          }
        }

        try {
          final status = await _repo.getStripStatus(_resolvedMac);
          if (status['online'] == true || status['is_online'] == true) {
            verifiedOnCloud = true;
            break;
          }
        } catch (_) {}
      }

      if (verifiedOnCloud) {
        if (mounted) {
          setState(() {
            _currentStep = 3;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _pairingErrorMessage = trBi(
              'تعذر رصد المشترك أونلاين بعد 60 ثانية.\n• تأكد من صحة كلمة مرور الواي فاي ($ssid)\n• تأكد أن الشبكة تعمل بتردد 2.4 GHz\n• تأكد من اتصال هاتفك بالإنترنت حالياً.',
              'Could not detect the strip online after 60 seconds.\n• Verify Wi-Fi password for ($ssid)\n• Ensure network is 2.4 GHz\n• Ensure your phone is connected to the internet.',
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pairingErrorMessage = trBi(
            'حدث خطأ أثناء الاقتران: $e',
            'An error occurred during pairing: $e',
          );
        });
      }
    }
  }

  // --- Step 3: Finish and Apply Safeguard ---

  Future<void> _finishSetup() async {
    setState(() => _isLoading = true);

    await _repo.registerStrip(
      _resolvedMac,
      name: _stripNameController.text.trim(),
      roomCategory: _selectedRoom,
    );

    if (_routerSocketIndex > 0) {
      await _repo.lockSocket(_resolvedMac, _routerSocketIndex, true);
      await _repo.configSocket(_resolvedMac, _routerSocketIndex, {
        'name': AppLocaleController.instance.isArabic ? 'راوتر الإنترنت' : 'Internet Router',
        'icon': 'router',
        'is_router': true,
      });
    }

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _routerSocketIndex > 0
                ? trBi(
                    '🎉 تم ربط المشترك وتأمين مخرج الراوتر (#$_routerSocketIndex) بنجاح!',
                    '🎉 Strip paired & Router Outlet (#$_routerSocketIndex) safeguarded!',
                  )
                : trBi(
                    '🎉 تم ربط المشترك بحسابك بنجاح!',
                    '🎉 Smart strip paired to your account successfully!',
                  ),
          ),
          backgroundColor: AppColors.emeraldDeep,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.darkBg : AppColors.lightBg;
    final appBarBg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Directionality(
      textDirection: AppLocaleController.instance.textDirection,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(
            trBi('إضافة وربط مشترك ذكي', 'Add & Pair Smart Strip'),
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
          ),
          backgroundColor: appBarBg,
          foregroundColor: textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          actions: [
            if (_currentStep == 1)
              IconButton(
                icon: _isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.emeraldActive,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.emeraldActive),
                onPressed: _isScanning ? null : () => _scanWifi(),
                tooltip: trBi('إعادة البحث', 'Rescan'),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildStepperHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AppTheme.cleanCardDecoration(isDark: widget.isDark, radius: 24),
                    child: _buildCurrentStepView(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    final steps = [
      trBi('1. الاكتشاف والواي فاي', '1. Discover & Wi-Fi'),
      trBi('2. الربط التلقائي', '2. Auto Pairing'),
      trBi('3. التخصيص والحماية', '3. Customize'),
    ];
    final cardBg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final borderCol = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderCol, width: 1)),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final stepNum = index + 1;
          final isActive = _currentStep == stepNum;
          final isDone = _currentStep > stepNum;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDone || isActive
                          ? AppColors.emeraldActive
                          : (widget.isDark ? AppColors.borderDark : AppColors.borderLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isDone)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(end: 4),
                          child: Icon(Icons.check_circle_rounded, size: 14, color: AppColors.emeraldActive),
                        ),
                      Flexible(
                        child: Text(
                          steps[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            fontWeight: isActive || isDone ? FontWeight.w900 : FontWeight.w600,
                            color: isActive || isDone
                                ? AppColors.emeraldActive
                                : (widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
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
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final mutedBg = widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight;
    final borderCol = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Missing Permissions Banner
        if (!_hasPermissions)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warningAmber, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.perm_scan_wifi_rounded, color: AppColors.warningAmber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trBi(
                          'مطلوب إذن البحث عن شبكات الواي فاي القريبة',
                          'Wi-Fi Discovery Permission Required',
                        ),
                        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  trBi(
                    'يحتاج التطبيق إلى هذا الإذن فقط أثناء عملية الربط للعثور على شبكة المشترك وراوتر المنزل تلقائياً.',
                    'The app only needs this permission during pairing to automatically find your smart strip and home router.',
                  ),
                  style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _initPermissionsAndWifi,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: Text(
                      trBi('منح الإذن والبحث الآن', 'Grant Permission & Scan Now'),
                      style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldActive,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Location Services (GPS) Disabled Banner
        if (_isLocationDisabled)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.dangerRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.dangerRed, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_off_rounded, color: AppColors.dangerRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trBi(
                          'خدمات الموقع (GPS) غير مفعلة على الهاتف',
                          'Location Services (GPS) are turned off',
                        ),
                        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.dangerRed),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  trBi(
                    'يشترط نظام أندرويد تفعيل الموقع (GPS) ليتمكن الهاتف من قراءة شبكات الواي فاي القريبة واكتشاف المشترك.',
                    'Android requires Location (GPS) to be turned on in order to scan nearby Wi-Fi networks and detect the strip.',
                  ),
                  style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await SoftApService.openLocationSettings();
                    },
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: Text(
                      trBi('تفعيل الموقع (GPS) من الإعدادات', 'Turn On Location (GPS)'),
                      style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Clear Step-by-Step Guide Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.emeraldActive.withOpacity(0.08) : AppColors.emeraldLightBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.emeraldActive.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded, color: AppColors.emeraldActive, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trBi(
                        'خطوات تجهيز المشترك للربط السريع:',
                        'Quick Strip Preparation Steps:',
                      ),
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: widget.isDark ? AppColors.emeraldActive : AppColors.emeraldDeep,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildGuideStep(
                '1',
                trBi(
                  'وصّل المشترك بالكهرباء واضغط مطولاً على زر الباور لمدة 5–10 ثوانٍ حتى تومض لمبة الواي فاي بسرعة.',
                  'Plug in the strip and press & hold the power button for 5–10 seconds until the Wi-Fi LED blinks rapidly.',
                ),
              ),
              _buildGuideStep(
                '2',
                trBi(
                  'أوقف بيانات الهاتف (Mobile Data) مؤقتاً أثناء الربط لضمان توجيه الاتصال للمشترك.',
                  'Temporarily turn off Mobile Data during pairing so your phone routes traffic directly to the strip.',
                ),
              ),
              _buildGuideStep(
                '3',
                trBi(
                  'اختر شبكة المشترك المكتشفة بالأسفل، ثم اختر شبكة راوتر المنزل (بتردد 2.4 GHz) وأدخل كلمة المرور.',
                  'Select the discovered strip below, then pick your 2.4 GHz home router network and enter its password.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section 1: Auto-discovered Strip Section
        if (!_showManualMacInput) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trBi('1. المشترك الذكي المكتشف:', '1. Discovered Smart Strip:'),
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: textPrimary),
              ),
              TextButton.icon(
                onPressed: _isScanning ? null : () => _scanWifi(),
                icon: _isScanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emeraldActive),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16, color: AppColors.emeraldActive),
                label: Text(
                  trBi('بحث الآن', 'Scan Now'),
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldActive,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_detectedStrips.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mutedBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                children: [
                  Icon(
                    _isScanning ? Icons.wifi_find_rounded : Icons.wifi_tethering_rounded,
                    size: 32,
                    color: _isScanning ? AppColors.emeraldActive : textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isScanning
                        ? trBi(
                            'جاري البحث عن شبكة المشترك (TONLY_TAP_...)...',
                            'Scanning for smart strip network (TONLY_TAP_...)...',
                          )
                        : trBi(
                            'لم يتم رصد شبكة المشترك (TONLY_TAP_...) حتى الآن.\nتأكد من وميض لمبة المشترك ثم اضغط إعادة البحث.',
                            'Smart strip network (TONLY_TAP_...) not detected yet.\nEnsure the strip LED is blinking, then tap Rescan.',
                          ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : () => _scanWifi(),
                        icon: const Icon(Icons.wifi_find_rounded, size: 16),
                        label: Text(
                          trBi('إعادة البحث عن المشترك', 'Rescan for Strip'),
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldActive,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await SoftApService.openWifiSettings();
                          await Future.delayed(const Duration(seconds: 1));
                          if (mounted) _scanWifi();
                        },
                        icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                        label: Text(
                          trBi('فتح قائمة الواي فاي للنظام', 'System Wi-Fi Panel'),
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderCol),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.emeraldActive.withOpacity(0.12)
                        : mutedBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.emeraldActive : borderCol,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldActive.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.power_rounded, color: AppColors.emeraldActive, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stripSsid,
                              textDirection: TextDirection.ltr,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'MAC: $derivedMac',
                              textDirection: TextDirection.ltr,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? AppColors.emeraldActive : textSecondary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
        ],

        // Section 2: Home Wi-Fi Router Credentials (with 2.4GHz Network Picker)
        if (!_showManualMacInput) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trBi('2. شبكة راوتر المنزل (2.4 GHz):', '2. Home Router Wi-Fi (2.4 GHz):'),
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: textPrimary),
                ),
              ),
              TextButton.icon(
                onPressed: _showRouterNetworkPicker,
                icon: const Icon(Icons.list_alt_rounded, size: 16, color: AppColors.emeraldActive),
                label: Text(
                  trBi('اختر من الشبكات المتاحة', 'Choose Network'),
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldActive,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            trBi('اسم شبكة الواي فاي (SSID)', 'Wi-Fi Network Name (SSID)'),
            style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w700, color: textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ssidController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText: trBi('اضغط لاختيار الشبكة أو اكتب اسمها', 'Tap to pick or type router SSID'),
              prefixIcon: const Icon(Icons.wifi_rounded, color: AppColors.emeraldActive),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: AppColors.emeraldActive),
                tooltip: trBi('اختر من الشبكات المتاحة', 'Pick from nearby networks'),
                onPressed: _showRouterNetworkPicker,
              ),
              filled: true,
              fillColor: mutedBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderCol),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderCol),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.emeraldActive, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            trBi('كلمة مرور الواي فاي (Password)', 'Wi-Fi Password'),
            style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w700, color: textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText: trBi('أدخل كلمة مرور راوتر المنزل', 'Enter home router password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.emeraldActive),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: textSecondary,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              filled: true,
              fillColor: mutedBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderCol),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderCol),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.emeraldActive, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 16),
        ],

        // Optional Manual MAC Registration (for strips already connected to Wi-Fi)
        GestureDetector(
          onTap: () => setState(() => _showManualMacInput = !_showManualMacInput),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showManualMacInput ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.emeraldActive,
                ),
                const SizedBox(width: 4),
                Text(
                  _showManualMacInput
                      ? trBi('العودة للربط التلقائي عبر الواي فاي', 'Back to Automatic Wi-Fi Pairing')
                      : trBi('المشترك متصل بالإنترنت مسبقاً؟ سجّله بالماك يدوياً', 'Strip already online? Register via MAC'),
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldActive,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showManualMacInput) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _manualMacController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText: '88D039XXXXXX',
              prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.emeraldActive),
              filled: true,
              fillColor: mutedBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderCol),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary),
          ),
        ],

        const SizedBox(height: 20),

        // Primary CTA Button
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _startPairing,
            icon: const Icon(Icons.rocket_launch_rounded, size: 18),
            label: Text(
              _showManualMacInput
                  ? trBi('متابعة برقم الماك', 'Continue with MAC')
                  : trBi('بدء الربط التلقائي للمشترك', 'Start Automatic Strip Pairing'),
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldActive,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideStep(String number, String text) {
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.emeraldActive,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              number,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 2: Real Pairing Execution & Cloud Polling ---

  Widget _buildStep2View() {
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: _pairingStage == 1 ? 0.35 : (_pairingStage == 2 ? 0.70 : null),
                  strokeWidth: 6,
                  color: AppColors.emeraldActive,
                  backgroundColor: AppColors.emeraldActive.withOpacity(0.15),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.emeraldActive.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_protected_setup_rounded, color: AppColors.emeraldActive, size: 34),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Text(
          _pairingStatusMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary, height: 1.5),
        ),
        const SizedBox(height: 16),

        if (_phoneMissingInternetInStep2 && _pairingErrorMessage == null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warningAmber),
            ),
            child: Column(
              children: [
                Text(
                  trBi(
                    'الهاتف غير متصل بالإنترنت حالياً. إذا لم يعد الاتصال تلقائياً لشبكة المنزل، اضغط الزر أدناه لاختيار شبكة الراوتر:',
                    'Your phone is not connected to the internet yet. If it did not auto-reconnect to your home Wi-Fi, tap below:',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w700, color: textPrimary),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => SoftApService.openWifiSettings(),
                  icon: const Icon(Icons.wifi_rounded, size: 16),
                  label: Text(
                    trBi('فتح الواي فاي والاتصال بالراوتر', 'Open Wi-Fi & Connect to Router'),
                    style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldActive,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (_pairingErrorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.dangerRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.dangerRed, width: 1.2),
            ),
            child: Text(
              _pairingErrorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.dangerRed, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() => _currentStep = 1),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(
              trBi('العودة للخطوة السابقة وإعادة المحاولة', 'Back to Previous Step & Retry'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldActive,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ] else ...[
          Text(
            trBi(
              'قد تستغرق عملية اتصال المشترك بالراوتر والسحابة من 15 إلى 40 ثانية...',
              'Connecting the strip to your router and cloud may take 15 to 40 seconds...',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
          ),
        ],
      ],
    );
  }

  // --- Step 3: Safeguard & Customization ---

  Widget _buildStep3View() {
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final mutedBg = widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight;
    final borderCol = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.emeraldActive.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.emeraldActive.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.emeraldActive, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trBi('تم اتصال المشترك بالسيرفر بنجاح! 🎉', 'Smart Strip Connected to Cloud! 🎉'),
                      style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppColors.emeraldActive),
                    ),
                    Text(
                      trBi('خصّص اسم المشترك ومكانه وحدد مخرج الراوتر لحمايته.', 'Customize your strip name, room, and router safeguard.'),
                      style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Text(
          trBi('اسم المشترك الذكي:', 'Smart Strip Name:'),
          style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _stripNameController,
          decoration: InputDecoration(
            filled: true,
            fillColor: mutedBg,
            prefixIcon: const Icon(Icons.edit_rounded, color: AppColors.emeraldActive),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderCol),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderCol),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary),
        ),
        const SizedBox(height: 16),

        Text(
          trBi('الغرفة / المكان في المنزل:', 'Room / Location:'),
          style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedRoom,
          items: [
            DropdownMenuItem(value: 'living', child: Text(trBi('صالة المعيشة 🛋️', 'Living Room 🛋️'))),
            DropdownMenuItem(value: 'office', child: Text(trBi('غرفة المكتب 💻', 'Office Room 💻'))),
            DropdownMenuItem(value: 'bedroom', child: Text(trBi('غرفة النوم 🛏️', 'Bedroom 🛏️'))),
            DropdownMenuItem(value: 'kitchen', child: Text(trBi('المطبخ 🍳', 'Kitchen 🍳'))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedRoom = val);
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: mutedBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderCol),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderCol),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),

        // Router Safeguard Selector
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.routerBgDark : AppColors.routerBgLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.routerCyan.withOpacity(0.5), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AppColors.routerCyan, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trBi('🛡️ درع حماية راوتر الإنترنت:', '🛡️ Internet Router Safeguard:'),
                      style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.routerCyan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                trBi(
                  'حدد المقبس الموصول به راوتر الإنترنت لحمايته برمز PIN أو البصمة ومنع فصله بالخطأ عند إيقاف الكل:',
                  'Select which outlet powers your internet router to protect it with PIN/Biometrics and exclude it from Smart All-OFF:',
                ),
                style: GoogleFonts.cairo(fontSize: 11, color: textPrimary, height: 1.4),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: _routerSocketIndex,
                items: [
                  DropdownMenuItem(
                    value: 0,
                    child: Text(trBi('لا يوجد راوتر متصل بهذا المشترك', 'No router connected to this strip')),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text(trBi('🔒 المقبس رقم 1 (راوتر الإنترنت)', '🔒 Outlet #1 (Internet Router)')),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text(trBi('🔒 المقبس رقم 2 (راوتر الإنترنت)', '🔒 Outlet #2 (Internet Router)')),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text(trBi('🔒 المقبس رقم 3 (راوتر الإنترنت)', '🔒 Outlet #3 (Internet Router)')),
                  ),
                  DropdownMenuItem(
                    value: 4,
                    child: Text(trBi('🔒 المقبس رقم 4 (راوتر الإنترنت)', '🔒 Outlet #4 (Internet Router)')),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _routerSocketIndex = val);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: widget.isDark ? AppColors.cardSurfaceDark : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _finishSetup,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              trBi('حفظ الإعدادات وبدء الاستخدام 🎉', 'Save & Start Using Strip 🎉'),
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldActive,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/security/biometric_service.dart';
import '../../core/localization/app_locale.dart';
import '../../core/services/home_widget_service.dart';
import '../../data/services/softap_service.dart';
import '../../data/models/strip_model.dart';
import '../../data/models/socket_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/strip_repository.dart';
import '../../data/websockets/ws_manager.dart';
import '../../widgets/socket_card.dart';
import '../../widgets/pin_biometric_dialog.dart';
import '../analytics/energy_analytics_screen.dart';
import '../protection/protection_screen.dart';
import '../family/family_sharing_screen.dart';
import '../admin/admin_console_screen.dart';
import '../onboarding/wizard_screen.dart';
import '../auth/login_screen.dart';
import '../schedules/schedules_tab.dart';
import '../favorites/favorites_tab.dart';
import '../settings/settings_tab.dart';
import '../settings/widgets/controller_mode_dialog.dart';
import '../account/account_tab.dart';
import 'widgets/socket_deep_dive_sheet.dart';
import 'widgets/digital_twin_card.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repo = StripRepository();
  final _wsManager = WebSocketManager();

  int _selectedTabIndex = 0;
  bool _isDark = false;
  double _tariffPrice = 1.45;
  bool _isLoading = true;
  UserModel? _currentUser;
  List<StripModel> _strips = [];
  StripModel? _selectedStrip;
  List<Map<String, dynamic>> _scenes = [];
  StreamSubscription? _wsSubscription;
  Timer? _autoPollTimer;
  final Set<int> _pendingSockets = {};
  bool _isSerialVisible = false;
  bool _showDigitalTwin = true;

  String _tr(String key) => AppLocaleController.instance.tr(key);

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _initApp();
    _startPeriodicPoll();
  }

  void _startPeriodicPoll() {
    _autoPollTimer?.cancel();
    _autoPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_isLoading && _strips.isNotEmpty) {
        _repo.getStrips().then((strips) {
          if (mounted && strips.isNotEmpty) {
            setState(() {
              _strips = strips;
              final currentMac = _selectedStrip?.macAddress;
              _selectedStrip = strips.firstWhere(
                (s) => s.macAddress == currentMac,
                orElse: () => strips.first,
              );
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _autoPollTimer?.cancel();
    _wsSubscription?.cancel();
    _wsManager.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    SoftApService.requestPermissions();
    _isDark = await SecureStorageService.isDarkMode();
    _tariffPrice = await SecureStorageService.getTariffPrice();
    _currentUser = await _repo.getAuthStatus();
    await _loadStrips();
    await _loadScenes();
  }

  Future<void> _loadScenes() async {
    final list = await _repo.getScenes();
    if (mounted) {
      setState(() => _scenes = list);
    }
  }

  Future<void> _loadStrips() async {
    setState(() => _isLoading = true);
    final strips = await _repo.getStrips();
    if (!mounted) return;
    setState(() {
      _strips = strips;
      if (_strips.isNotEmpty) {
        final prevMac = _selectedStrip?.macAddress;
        _selectedStrip = _strips.firstWhere(
          (s) => s.macAddress == prevMac,
          orElse: () => _strips.first,
        );
        _connectWebSocket();
        HomeWidgetService.updateFromStrip(_selectedStrip!);
      }
      _isLoading = false;
    });
  }

  void _connectWebSocket() {
    if (_selectedStrip == null) return;
    _wsSubscription?.cancel();
    _wsSubscription = _wsManager.connect(_selectedStrip!.macAddress).listen((data) {
      if (!mounted) return;
      setState(() {
        if (data.containsKey('online')) {
          _selectedStrip!.isOnline = data['online'] == true;
        } else if (data['event'] == 'status_change') {
          _selectedStrip!.isOnline = data['online'] == true;
        } else if (data.containsKey('voltage') || data['event'] == 'telemetry_update') {
          _selectedStrip!.isOnline = true;
        }

        if (data.containsKey('voltage')) {
          _selectedStrip!.currentVoltage = (data['voltage'] as num?)?.toDouble();
        }
        if (data.containsKey('sockets') && data['sockets'] is List) {
          final sList = data['sockets'] as List;
          for (var sJson in sList) {
            final idx = sJson['socket_index'];
            final socket = _selectedStrip!.sockets.firstWhere(
              (s) => s.socketIndex == idx,
              orElse: () => _selectedStrip!.sockets[0],
            );
            if (sJson.containsKey('state')) socket.state = sJson['state'];
            if (sJson.containsKey('current_watt')) socket.currentWatt = (sJson['current_watt'] as num).toDouble();
            if (sJson.containsKey('current_amp')) socket.currentAmp = (sJson['current_amp'] as num).toDouble();
            if (sJson.containsKey('raw_energy_kwh')) socket.rawEnergyKwh = (sJson['raw_energy_kwh'] as num).toDouble();
          }
        }
        if (_selectedStrip != null) {
          HomeWidgetService.updateFromStrip(_selectedStrip!);
        }
      });
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
    });
    SecureStorageService.setDarkMode(_isDark);
  }

  // ===================== SOCKET SWITCHING & HARDWARE GUARDS =====================

  void _onToggleSocket(SocketModel socket) {
    if (_selectedStrip == null) return;

    // 1. Check if Pinned State is active
    if (socket.isPinnedState) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.push_pin_rounded, color: AppColors.emeraldPrimary),
              const SizedBox(width: 8),
              Text('المخرج مثبّت الحالة 📌', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(
            'تم تفعيل ميزة تثبيت الحالة الحالية على "${socket.name}". هل تريد إلغاء تثبيت الحالة وتبديل المخرج؟',
            style: GoogleFonts.cairo(fontSize: 12, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _repo.configSocket(_selectedStrip!.macAddress, socket.socketIndex, {
                  'is_pinned_state': false,
                });
                setState(() => socket.isPinnedState = false);
                _proceedSocketAuthAndFlip(socket);
              },
              child: Text('إلغاء التثبيت والتبديل', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Check if Router is about to be turned OFF -> Safety confirmation
    if (socket.isRouter && socket.state) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.router_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text('تحذير فصل الراوتر 🌐', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.redAccent)),
            ],
          ),
          content: Text(
            'أنت على وشك إيقاف مخرج الراوتر (${socket.name}). قد يؤدي ذلك إلى انقطاع اتصال الإنترنت عن المشترك.\n\nهل تريد استخدام "إعادة تشغيل الراوتر (5 ثوانٍ)" بدلاً من الإيقاف الدائم؟',
            style: GoogleFonts.cairo(fontSize: 12, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('تراجع', style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.w800)),
            ),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _repo.restartSocket(_selectedStrip!.macAddress, socket.socketIndex);
                final ok = res['ok'] == true;
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? '🔄 جاري إعادة تشغيل الراوتر (فصل 5 ثوانٍ ثم تشغيل تلقائي)...' : '❌ تعذر إرسال أمر إعادة التشغيل'),
                      backgroundColor: AppColors.emeraldPrimary,
                    ),
                  );
                }
              },
              child: Text('إعادة تشغيل 5ث 🔄', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _proceedSocketAuthAndFlip(socket);
              },
              child: Text('إيقاف رغم ذلك', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    _proceedSocketAuthAndFlip(socket);
  }

  void _proceedSocketAuthAndFlip(SocketModel socket) {
    if (socket.isLocked || (_selectedStrip?.biometricControl ?? false)) {
      showDialog(
        context: context,
        builder: (_) => PinBiometricDialog(
          title: 'تأكيد تبديل: ${socket.name}',
          isDark: _isDark,
          onSuccessWithPin: (pin) => _flipSocketState(socket),
          onSuccess: () => _flipSocketState(socket),
        ),
      );
    } else {
      _flipSocketState(socket);
    }
  }

  Future<void> _flipSocketState(SocketModel socket) async {
    if (_selectedStrip == null || _pendingSockets.contains(socket.socketIndex)) return;

    final previousState = socket.state;
    final newState = !previousState;

    setState(() {
      _pendingSockets.add(socket.socketIndex);
      socket.state = newState;
      // Propagate link group locally for instant UI feedback (backend also executes it on hardware)
      if (socket.linkGroup > 0) {
        for (final other in _selectedStrip!.sockets) {
          if (other.socketIndex != socket.socketIndex &&
              other.linkGroup == socket.linkGroup &&
              !other.isLocked &&
              !other.isPinnedState) {
            other.state = newState;
          }
        }
      }
    });

    try {
      final success = await _repo.switchSocket(
        _selectedStrip!.macAddress,
        socket.socketIndex,
        newState,
      );

      if (!mounted) return;

      if (!success) {
        setState(() {
          socket.state = previousState;
          _pendingSockets.remove(socket.socketIndex);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ تعذر إرسال الأمر للمشترك، تحقق من الاتصال أو قفل الأطفال'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _pendingSockets.remove(socket.socketIndex);
        });
        // If Doorbell Mode is active and we turned it ON, refresh strip after pulse
        if (newState && socket.doorbellMode) {
          Future.delayed(Duration(seconds: socket.doorbellPulseSec + 1), () {
            if (mounted) _loadStrips();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        socket.state = previousState;
        _pendingSockets.remove(socket.socketIndex);
      });
    }
  }

  void _smartAllOff() {
    if (_selectedStrip == null) return;
    for (var s in _selectedStrip!.sockets) {
      if (!s.isRouter && !s.isLocked && !s.isPinnedState) {
        s.state = false;
        _repo.switchSocket(_selectedStrip!.macAddress, s.socketIndex, false);
      }
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🛡️ تم إيقاف الكل مع استثناء الراوتر والمخارج المقفولة/المثبتة!'),
        backgroundColor: AppColors.emeraldPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _turnAllOn() {
    if (_selectedStrip == null) return;
    for (var s in _selectedStrip!.sockets) {
      if (!s.isLocked && !s.isPinnedState) {
        s.state = true;
        _repo.switchSocket(_selectedStrip!.macAddress, s.socketIndex, true);
      }
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ تم تشغيل جميع المخارج غير المقفولة'),
        backgroundColor: AppColors.emeraldPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openDeepDive(SocketModel socket) {
    if (_selectedStrip == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SocketDeepDiveSheet(
        stripMac: _selectedStrip!.macAddress,
        socket: socket,
        allSockets: _selectedStrip!.sockets,
        onSaved: () {
          if (mounted) {
            setState(() {});
            _loadStrips();
          }
        },
      ),
    );
  }

  // ===================== BUILD SCAFFOLD =====================

  @override
  Widget build(BuildContext context) {
    final bg = _isDark ? AppColors.darkBg : AppColors.lightBg;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.emeraldPrimary)),
      );
    }

    return AnimatedBuilder(
      animation: AppLocaleController.instance,
      builder: (context, _) {
        return Directionality(
          textDirection: AppLocaleController.instance.textDirection,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: bg,
            drawer: _buildSideDrawer(),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _selectedStrip == null
                        ? _buildEmptyState()
                        : _buildActiveTabContent(),
                  ),
                  _buildBottomNav(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===================== TOP APP BAR (WattQ 1.0.27 + Na7la) =====================

  Widget _buildHeader() {
    final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = _isDark ? AppColors.cardSurfaceDark : Colors.white;
    final borderColor = _isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Identity
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset('assets/icons/app_icon.png', width: 28, height: 28),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Na7la IoT',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'تحكم ذكي في طاقتك ⚡',
                    style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emeraldPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Actions: Admin + Theme + Side Drawer (☰)
          Row(
            children: [
              if (_currentUser?.isAdmin ?? false)
                GestureDetector(
                  onTap: _openAdminConsole,
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warningAmber, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.admin_panel_settings_rounded, size: 15, color: AppColors.warningAmber),
                        const SizedBox(width: 4),
                        Text(
                          'الأدمن 👑',
                          style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                onPressed: _toggleTheme,
                icon: Icon(
                  _isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_outlined,
                  size: 20,
                  color: _isDark ? AppColors.warningAmber : textPrimary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: Icon(Icons.menu_rounded, size: 22, color: textPrimary),
                tooltip: 'القائمة الجانبية',
                style: IconButton.styleFrom(
                  backgroundColor: _isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== SIDE DRAWER (☰) — WattQ 1.0.27 + Eng. Ahmed Essam =====================

  Widget _buildSideDrawer() {
    final bg = _isDark ? AppColors.cardSurfaceDark : Colors.white;
    final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = _isDark ? AppColors.borderDark : AppColors.borderLight;

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.emeraldPrimary.withOpacity(0.15),
                    AppColors.emeraldDark.withOpacity(0.05),
                  ],
                ),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.emeraldPrimary,
                    child: Text(
                      (_currentUser?.fullName?.isNotEmpty == true
                              ? _currentUser!.fullName![0]
                              : (_currentUser?.email.isNotEmpty == true ? _currentUser!.email[0] : 'N'))
                          .toUpperCase(),
                      style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.fullName ?? 'مستخدم Na7la IoT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: textPrimary),
                        ),
                        Text(
                          _currentUser?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Drawer Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                children: [
                  _buildDrawerItem(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'إضافة مشترك جديد (الواي فاي)',
                    onTap: () async {
                      Navigator.pop(context);
                      final added = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => WizardScreen(isDark: _isDark)),
                      );
                      if (added == true) _loadStrips();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'ربط مشترك بالسيريال (MAC)',
                    onTap: () {
                      Navigator.pop(context);
                      _openClaimBySerialDialog();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.auto_awesome_mosaic_rounded,
                    title: 'المشاهد الذكية (Smart Scenes)',
                    onTap: () {
                      Navigator.pop(context);
                      _openCreateSceneDialog();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.analytics_outlined,
                    title: 'مراقب الاستهلاك لجميع المشتركات',
                    onTap: () {
                      Navigator.pop(context);
                      _openAllStripsEnergyMonitorSheet();
                    },
                  ),
                  Divider(height: 16, color: borderColor),
                  _buildDrawerItem(
                    icon: Icons.workspace_premium_outlined,
                    title: 'الأسعار والاشتراك',
                    onTap: () {
                      Navigator.pop(context);
                      _showPricingDialog();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.rate_review_outlined,
                    title: 'إرسال مقترح / الدعم الفني',
                    onTap: () {
                      Navigator.pop(context);
                      _openFeedbackAndSupportDialog();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'الإعدادات والتنبيهات',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedTabIndex = 3);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info_outline_rounded,
                    title: 'حول التطبيق',
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog();
                    },
                  ),
                  Divider(height: 16, color: borderColor),
                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'تسجيل الخروج',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmLogout();
                    },
                  ),
                ],
              ),
            ),

            // Quranic Verse & Eng. Ahmed Essam Footer
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.emeraldPrimary.withOpacity(0.35)),
              ),
              child: Column(
                children: [
                  Text(
                    '﴿ إِنَّ اللَّهَ وَمَلَائِكَتَهُ يُصَلُّونَ عَلَى النَّبِيِّ ۚ يَا أَيُّهَا الَّذِينَ آمَنُوا صَلُّوا عَلَيْهِ وَسَلِّمُوا تَسْلِيمًا ﴾',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emeraldPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Made with ❤️ by Eng. Ahmed Essam',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, size: 20, color: color ?? AppColors.emeraldPrimary),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: color ?? textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  // ===================== MAIN HOME TAB (WattQ 1.0.27 + Na7la) =====================

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return SchedulesTab(
          strip: _selectedStrip!,
          isDark: _isDark,
          onOpenScheduleSheet: _openDeepDive,
        );
      case 2:
        return FavoritesTab(
          strip: _selectedStrip!,
          isDark: _isDark,
          onToggleSocket: _onToggleSocket,
          onOpenDeepDive: _openDeepDive,
          onGoToDashboard: () => setState(() => _selectedTabIndex = 0),
        );
      case 3:
        return SettingsTab(
          strip: _selectedStrip!,
          isDark: _isDark,
          isAdmin: _currentUser?.isAdmin ?? false,
          onToggleTheme: _toggleTheme,
          onOpenProtection: _openProtectionScreen,
          onOpenFamily: _openFamilyScreen,
          onOpenAdminConsole: _openAdminConsole,
        );
      case 4:
        return AccountTab(
          user: _currentUser,
          isDark: _isDark,
          stripsCount: _strips.length,
          onUpgradeQuota: () => _showQuotaUpgradeDialog(_currentUser?.stripQuota ?? 1),
          onLogout: _confirmLogout,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildHomeTab() {
    final strip = _selectedStrip!;
    final double totalWatts = strip.totalWatt;
    final double totalAmps = strip.totalAmp;
    final double voltage = strip.voltage;
    final int maxSocketTemp = strip.sockets.isNotEmpty
        ? strip.sockets.map((s) => s.currentTempC).reduce((a, b) => a > b ? a : b)
        : 28;
    final int displayTemp = maxSocketTemp > 0 ? maxSocketTemp : 28;
    final bool isOnline = strip.isOnline;

    final int stripsCount = _strips.length;
    final int onlineCount = _strips.where((s) => s.isOnline).length;
    final double fleetTotalWatts = _strips.fold(0.0, (sum, s) => sum + s.totalWatt);

    final cardBg = _isDark ? AppColors.cardSurfaceDark : Colors.white;
    final borderColor = _isDark ? AppColors.borderDark : AppColors.borderLight;
    final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final mac = strip.macAddress;
    final maskedMac = _isSerialVisible
        ? mac
        : (mac.length > 5 ? '${mac.substring(0, 5)}••••••' : mac);

    return RefreshIndicator(
      onRefresh: () async {
        await _loadStrips();
        await _loadScenes();
      },
      color: AppColors.emeraldPrimary,
      backgroundColor: cardBg,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top 3-Column Summary Card (Exact WattQ 1.0.27 Style)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: AppTheme.cleanCardDecoration(isDark: _isDark, radius: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$stripsCount',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'المشتركات',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 34, color: borderColor),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$onlineCount',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'متصل',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 34, color: borderColor),
                  Expanded(
                    child: Column(
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '${fleetTotalWatts.toStringAsFixed(0)} W',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'إجمالي السحب',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 2. Smart Scenes Pill Bar (+ مشهد جديد & Saved Scenes)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.emeraldPrimary),
                    label: Text(
                      'مشهد جديد',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldPrimary,
                      ),
                    ),
                    backgroundColor: AppColors.emeraldPrimary.withOpacity(0.1),
                    side: BorderSide(color: AppColors.emeraldPrimary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onPressed: _openCreateSceneDialog,
                  ),
                  const SizedBox(width: 8),
                  ..._scenes.map((scene) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onLongPress: () => _confirmDeleteScene(scene),
                        child: ActionChip(
                          avatar: const Icon(Icons.play_circle_fill_rounded, size: 16, color: AppColors.emeraldPrimary),
                          label: Text(
                            scene['name']?.toString() ?? 'مشهد',
                            style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                          ),
                          backgroundColor: cardBg,
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onPressed: () async {
                            final ok = await _repo.executeScene(scene['id'] as int);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? '🎬 تم تنفيذ المشهد "${scene['name']}" بنجاح' : '❌ تعذر تنفيذ المشهد'),
                                  backgroundColor: AppColors.emeraldPrimary,
                                ),
                              );
                              _loadStrips();
                            }
                          },
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Multi-Strip Selector if user has > 1 strip
            if (_strips.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _strips.map((s) {
                    final isSel = s.macAddress == strip.macAddress;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: ChoiceChip(
                        selected: isSel,
                        selectedColor: AppColors.emeraldPrimary,
                        backgroundColor: cardBg,
                        label: Text(
                          s.stripName,
                          style: GoogleFonts.cairo(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isSel ? Colors.white : textPrimary,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedStrip = s);
                          _connectWebSocket();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // 3. Main Strip Container Card (Exact WattQ 1.0.27 Layout + Na7la Features)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cleanCardDecoration(isDark: _isDark, radius: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 3.A Strip Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Strip Info (Icon + Name + Status + Masked MAC)
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.emeraldPrimary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.power_rounded, color: AppColors.emeraldPrimary, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          strip.stripName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.cairo(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w900,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isOnline
                                              ? AppColors.emeraldPrimary.withOpacity(0.15)
                                              : Colors.redAccent.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isOnline ? AppColors.emeraldPrimary : Colors.redAccent,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isOnline ? 'متصل' : 'غير متصل',
                                              style: GoogleFonts.cairo(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: isOnline ? AppColors.emeraldPrimary : Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (strip.childLock) ...[
                                        const SizedBox(width: 4),
                                        const Text('👶', style: TextStyle(fontSize: 12)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  GestureDetector(
                                    onTap: () => setState(() => _isSerialVisible = !_isSerialVisible),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(
                                            maskedMac,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Icon(
                                          _isSerialVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          size: 13,
                                          color: textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Strip 3-Dots Menu Button (⋮)
                      IconButton(
                        onPressed: _openDotsMenu,
                        icon: Icon(Icons.more_vert_rounded, color: textPrimary),
                        tooltip: 'إعدادات المشترك',
                        style: IconButton.styleFrom(
                          backgroundColor: _isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3.B Warm Cream / Dark Telemetry Bar (⚡ A | 🛡️ V | 🌡️ °C | ⚡ W)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isDark ? AppColors.telemetryBarDark : AppColors.telemetryBarLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isDark
                            ? AppColors.warningAmber.withOpacity(0.25)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTelemetryPill('⚡ ${totalAmps.toStringAsFixed(2)}A', textPrimary),
                        Container(width: 1, height: 16, color: borderColor),
                        _buildTelemetryPill('🛡️ ${voltage.toStringAsFixed(0)}V', AppColors.emeraldPrimary),
                        Container(width: 1, height: 16, color: borderColor),
                        _buildTelemetryPill('🌡️ $displayTemp°C', displayTemp > 45 ? Colors.redAccent : textPrimary),
                        Container(width: 1, height: 16, color: borderColor),
                        _buildTelemetryPill('⚡ ${totalWatts.toStringAsFixed(1)} W', AppColors.warningAmber),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3.C Collapsible Real Power Strip Image (Hardware Digital Twin)
                  InkWell(
                    onTap: () => setState(() => _showDigitalTwin = !_showDigitalTwin),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hub_outlined, size: 15, color: AppColors.emeraldPrimary),
                              const SizedBox(width: 6),
                              Text(
                                'المجسم الحقيقي التفاعلي للمشترك',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _showDigitalTwin ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showDigitalTwin) ...[
                    const SizedBox(height: 4),
                    DigitalTwinCard(
                      strip: strip,
                      isDark: _isDark,
                      onToggleSocket: _onToggleSocket,
                      onToggleAll: _smartAllOff,
                    ),
                  ],
                  const SizedBox(height: 6),

                  // 3.D Symmetrical 2x2 Outlet Grid (Exact WattQ 1.0.27 Cards)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: strip.sockets.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.18,
                    ),
                    itemBuilder: (context, index) {
                      final socket = strip.sockets[index];
                      return SocketCard(
                        socket: socket,
                        isDark: _isDark,
                        voltage: voltage,
                        onToggle: () => _onToggleSocket(socket),
                        onOpenDeepDive: () => _openDeepDive(socket),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3.E Bottom Full-Width Turn All Off Button inside Strip Card
                  _buildTurnAllButton(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryPill(String text, Color color) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTurnAllButton() {
    final anyOn = _selectedStrip!.sockets.any((s) => s.state && !s.isRouter && !s.isPinnedState);
    final mutedBg = _isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight;
    final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: anyOn ? _smartAllOff : _turnAllOn,
        icon: Icon(
          Icons.power_settings_new_rounded,
          size: 18,
          color: anyOn ? Colors.redAccent : Colors.white,
        ),
        label: Text(
          anyOn ? 'إيقاف الكل (الراوتر والمثبّت مستثنى)' : 'تشغيل جميع المخارج',
          style: GoogleFonts.cairo(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: anyOn ? textPrimary : Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: anyOn ? mutedBg : AppColors.emeraldPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ===================== STRIP 3-DOTS MENU (⋮) — ALL 13 FEATURES WIRED TO BACKEND =====================

  void _openDotsMenu() {
    if (_selectedStrip == null) return;
    final strip = _selectedStrip!;
    final bg = _isDark ? AppColors.cardSurfaceDark : Colors.white;
    final borderColor = _isDark ? AppColors.borderDark : AppColors.borderLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: borderColor, width: 1.5)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إعدادات المشترك (${strip.stripName})',
                    style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              Divider(height: 12, color: borderColor),

              // 1. Rename Strip & Room
              _buildDotsMenuItem(
                icon: Icons.edit_outlined,
                iconColor: AppColors.emeraldPrimary,
                title: 'تغيير اسم المشترك والغرفة',
                onTap: () {
                  Navigator.pop(ctx);
                  _openStripSettingsDialog();
                },
              ),

              // 2. Strip Schedule (Multi-Outlet)
              _buildDotsMenuItem(
                icon: Icons.schedule_rounded,
                iconColor: AppColors.emeraldPrimary,
                title: 'جدولة المشترك والمخارج',
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedTabIndex = 1);
                },
              ),

              // 3. Child Lock (Physical Buttons Lock)
              _buildDotsMenuItem(
                icon: Icons.child_care_rounded,
                iconColor: AppColors.warningAmber,
                title: 'قفل أزرار المشترك الفيزيائية (Child Lock)',
                trailing: _buildStatusPill(strip.childLock ? 'مفعل' : 'غير مفعل', strip.childLock),
                onTap: () {
                  Navigator.pop(ctx);
                  _openChildLockDialog();
                },
              ),

              // 4. Biometric Control for Strip
              _buildDotsMenuItem(
                icon: Icons.fingerprint_rounded,
                iconColor: AppColors.emeraldPrimary,
                title: 'التحكم بالبصمة للمشترك',
                trailing: _buildStatusPill(strip.biometricControl ? 'مفعل' : 'غير مفعل', strip.biometricControl),
                onTap: () async {
                  Navigator.pop(ctx);
                  final nextVal = !strip.biometricControl;
                  final ok = await _repo.updateProtection(strip.macAddress, {
                    'biometric_control': nextVal,
                  });
                  if (ok && mounted) {
                    setState(() => strip.biometricControl = nextVal);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(nextVal ? '🔐 تم تفعيل حماية البصمة للمشترك' : '🔓 تم إلغاء حماية البصمة للمشترك'),
                        backgroundColor: AppColors.emeraldPrimary,
                      ),
                    );
                  }
                },
              ),

              // 5. Watt & Voltage Limits + Exempt Outlets
              _buildDotsMenuItem(
                icon: Icons.shield_outlined,
                iconColor: AppColors.emeraldPrimary,
                title: 'حدود الواط والفولت واستثناء المخارج',
                trailing: Text(
                  '${strip.minVoltage.toInt()}V-${strip.maxVoltage.toInt()}V',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openProtectionScreen();
                },
              ),

              // 6. Power Return State (LAST / ON / OFF)
              _buildDotsMenuItem(
                icon: Icons.settings_backup_restore_rounded,
                iconColor: AppColors.routerCyan,
                title: 'حالة العودة بعد انقطاع الكهرباء',
                trailing: Text(
                  strip.powerReturnState == 'ON'
                      ? 'تشغيل'
                      : (strip.powerReturnState == 'OFF' ? 'إيقاف' : 'آخر حالة'),
                  style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.routerCyan),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPowerReturnDialog();
                },
              ),

              // 7. Energy Monitor & 30-Day Run Log
              _buildDotsMenuItem(
                icon: Icons.bar_chart_rounded,
                iconColor: AppColors.emeraldPrimary,
                title: 'مراقب الاستهلاك وسجل الـ 30 يوماً',
                onTap: () {
                  Navigator.pop(ctx);
                  _openEnergyAnalytics();
                },
              ),

              // 8. Strip Health & Diagnostics (24h & 7d)
              _buildDotsMenuItem(
                icon: Icons.monitor_heart_outlined,
                iconColor: const Color(0xFFEF4444),
                title: 'صحة المشترك والتشخيص (24 ساعة / 7 أيام)',
                onTap: () {
                  Navigator.pop(ctx);
                  _openDiagnosticsDialog();
                },
              ),

              // 9. Real Activity Log
              _buildDotsMenuItem(
                icon: Icons.history_rounded,
                iconColor: AppColors.warningAmber,
                title: 'سجل النشاط الفعلي (Activity Log)',
                onTap: () {
                  Navigator.pop(ctx);
                  _openActivityLogSheet();
                },
              ),

              // 10. Family Sharing (Strip or Single Outlet)
              _buildDotsMenuItem(
                icon: Icons.group_outlined,
                iconColor: AppColors.emeraldPrimary,
                title: 'مشاركة المشترك أو مخرج محدد مع العائلة',
                onTap: () {
                  Navigator.pop(ctx);
                  _openFamilyScreen();
                },
              ),

              // 11. Change Wi-Fi Network / Connection Mode
              _buildDotsMenuItem(
                icon: Icons.wifi_find_rounded,
                iconColor: AppColors.routerCyan,
                title: 'تغيير شبكة الواي فاي / وضع الاتصال',
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) => ControllerModeDialog(
                      isDark: _isDark,
                      mac: strip.macAddress,
                    ),
                  );
                },
              ),

              // 12. OTA Firmware Update
              _buildDotsMenuItem(
                icon: Icons.system_update_alt_rounded,
                iconColor: AppColors.emeraldPrimary,
                title: 'تحديث الفيرموير الهوائي (OTA Update)',
                trailing: Text(
                  'v${strip.fwVersion}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.grey),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final res = await _repo.requestOtaUpdate(strip.macAddress);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res?['message']?.toString() ?? '☁️ تم فحص وإرسال طلب التحديث الهوائي للمشترك'),
                        backgroundColor: AppColors.emeraldPrimary,
                      ),
                    );
                  }
                },
              ),

              Divider(height: 16, color: borderColor),

              // 13. Delete / Unlink Strip
              _buildDotsMenuItem(
                icon: Icons.delete_forever_rounded,
                iconColor: Colors.redAccent,
                title: 'حذف المشترك وفك الارتباط',
                isDanger: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteStrip(strip);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? AppColors.emeraldPrimary.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: active ? AppColors.emeraldPrimary : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDotsMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    bool isDanger = false,
  }) {
    final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isDanger ? Colors.redAccent : textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing,
            const SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded, size: 18, color: isDanger ? Colors.redAccent : Colors.grey),
          ],
        ),
      ),
    );
  }

  // ===================== REAL MODALS WIRED TO BACKEND =====================

  // 1. Claim Strip by Serial (MAC)
  void _openClaimBySerialDialog() {
    final macCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'مشترك ذكي');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('ربط مشترك بالسيريال (MAC) 🔗', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: macCtrl,
              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: 'رقم السيريال / MAC Address',
                hintText: 'مثال: AA11BB22CC33',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: 'اسم المشترك',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              final mac = macCtrl.text.trim();
              if (mac.isEmpty) return;
              final res = await _repo.registerStrip(mac, name: nameCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (res['ok'] == true || res['success'] == true) {
                await _loadStrips();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم ربط المشترك بحسابك بنجاح'), backgroundColor: AppColors.emeraldPrimary),
                  );
                }
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ ${res['detail'] ?? res['message'] ?? "تعذر ربط المشترك"}'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text('ربط الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // 2. Smart Scenes Creation & Execution Modal
  void _openCreateSceneDialog() {
    if (_selectedStrip == null) return;
    final nameCtrl = TextEditingController();
    final Map<int, bool?> socketActions = {
      for (final s in _selectedStrip!.sockets) s.socketIndex: s.isRouter ? null : false,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('إنشاء مشهد ذكي جديد 🎬', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    labelText: 'اسم المشهد (مثال: وضع النوم / الخروج)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('اختر حالة كل مخرج عند الضغط على المشهد:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                ..._selectedStrip!.sockets.map((s) {
                  final cur = socketActions[s.socketIndex];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('#${s.socketIndex} ${s.name}', style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800)),
                        ),
                        SegmentedButton<bool?>(
                          segments: const [
                            ButtonSegment(value: null, label: Text('تجاهل', style: TextStyle(fontSize: 10))),
                            ButtonSegment(value: true, label: Text('تشغيل', style: TextStyle(fontSize: 10))),
                            ButtonSegment(value: false, label: Text('إيقاف', style: TextStyle(fontSize: 10))),
                          ],
                          selected: {cur},
                          onSelectionChanged: (val) => setDialogState(() => socketActions[s.socketIndex] = val.first),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldPrimary, foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final List<Map<String, dynamic>> actions = [];
                socketActions.forEach((idx, state) {
                  if (state != null) {
                    actions.add({
                      'mac': _selectedStrip!.macAddress,
                      'socket_index': idx,
                      'state': state,
                    });
                  }
                });
                final ok = await _repo.createScene(name: name, actions: actions);
                if (ctx.mounted) Navigator.pop(ctx);
                if (ok) {
                  await _loadScenes();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم حفظ المشهد الذكي على السيرفر بنجاح'), backgroundColor: AppColors.emeraldPrimary),
                    );
                  }
                }
              },
              child: Text('حفظ المشهد', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteScene(Map<String, dynamic> scene) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
        title: Text('حذف المشهد', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900)),
        content: Text('هل تريد حذف المشهد "${scene['name']}"؟', style: GoogleFonts.cairo(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _repo.deleteScene(scene['id'] as int);
              _loadScenes();
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  // 3. All-Strips Energy Monitor Modal
  void _openAllStripsEnergyMonitorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>?>(
        future: _repo.getAllStripsEnergyMonitor(),
        builder: (context, snapshot) {
          final bg = _isDark ? AppColors.cardSurfaceDark : Colors.white;
          final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
          final data = snapshot.data;
          final items = (data?['strips'] as List?) ?? [];

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '📊 مراقب الاستهلاك لجميع المشتركات',
                  style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary),
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.emeraldPrimary)),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.emeraldPrimary.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${(data?['total_live_watt'] ?? 0).toString()} W',
                              style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.emeraldPrimary),
                            ),
                            Text('السحب اللحظي الكلي', style: GoogleFonts.cairo(fontSize: 10)),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${(data?['total_month_kwh'] ?? 0).toString()} kWh',
                              style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
                            ),
                            Text('استهلاك 30 يوماً', style: GoogleFonts.cairo(fontSize: 10)),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${(data?['total_month_cost_egp'] ?? 0).toString()} ج.م',
                              style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.warningAmber),
                            ),
                            Text('التكلفة بالشرائح', style: GoogleFonts.cairo(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((st) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.power_rounded,
                        color: st['online'] == true ? AppColors.emeraldPrimary : Colors.grey,
                      ),
                      title: Text(st['name']?.toString() ?? '', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800)),
                      subtitle: Text('استهلاك الشهر: ${st['month_kwh']} kWh • ${st['month_cost_egp']} ج.م', style: GoogleFonts.cairo(fontSize: 11)),
                      trailing: Text(
                        '${st['live_watt']} W',
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.emeraldPrimary),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // 4. Power Return State Modal (LAST / ON / OFF)
  void _openPowerReturnDialog() {
    if (_selectedStrip == null) return;
    final strip = _selectedStrip!;
    String current = strip.powerReturnState;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('حالة العودة بعد انقطاع الكهرباء 🔌', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'LAST',
                groupValue: current,
                activeColor: AppColors.emeraldPrimary,
                title: Text('العودة لآخر حالة قبل الانقطاع 🔄', style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800)),
                onChanged: (v) => setDialogState(() => current = v!),
              ),
              RadioListTile<String>(
                value: 'ON',
                groupValue: current,
                activeColor: AppColors.emeraldPrimary,
                title: Text('تشغيل جميع المخارج دائماً ⚡', style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800)),
                onChanged: (v) => setDialogState(() => current = v!),
              ),
              RadioListTile<String>(
                value: 'OFF',
                groupValue: current,
                activeColor: AppColors.emeraldPrimary,
                title: Text('إبقاء جميع المخارج مغلقة للأمان ⏻', style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800)),
                onChanged: (v) => setDialogState(() => current = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldPrimary, foregroundColor: Colors.white),
              onPressed: () async {
                final ok = await _repo.updateProtection(strip.macAddress, {'power_return_state': current});
                if (ctx.mounted) Navigator.pop(ctx);
                if (ok && mounted) {
                  setState(() => strip.powerReturnState = current);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم حفظ حالة العودة بعد انقطاع الكهرباء'), backgroundColor: AppColors.emeraldPrimary),
                  );
                }
              },
              child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Real Strip Health & Diagnostics Sheet (24h & 7d from GET /api/v1/strips/{mac}/health)
  void _openDiagnosticsDialog() {
    if (_selectedStrip == null) return;
    final strip = _selectedStrip!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>?>(
        future: _repo.getStripHealth(strip.macAddress),
        builder: (context, snapshot) {
          final bg = _isDark ? AppColors.cardSurfaceDark : Colors.white;
          final mutedBg = _isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight;
          final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
          final textSecondary = _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
          final h = snapshot.data;
          final p24 = h?['power_24h'] as Map<String, dynamic>?;
          final p7d = h?['power_7d'] as Map<String, dynamic>?;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
                          const Icon(Icons.monitor_heart_rounded, color: Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          Text(
                            'صحة المشترك والتشخيص (Strip Health)',
                            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator(color: AppColors.emeraldPrimary)),
                    )
                  else ...[
                    // 24h & 7d Power Draw Summary
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: mutedBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('⚡ سحب الطاقة خلال 24 ساعة:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.emeraldPrimary)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('الأدنى: ${p24?['min_watt'] ?? 0}W', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800)),
                              Text('المتوسط: ${p24?['avg_watt'] ?? 0}W', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800)),
                              Text('الأقصى: ${p24?['max_watt'] ?? 0}W', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.warningAmber)),
                            ],
                          ),
                          const Divider(height: 16),
                          Text('📅 سحب الطاقة خلال 7 أيام:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.routerCyan)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('الأدنى: ${p7d?['min_watt'] ?? 0}W', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800)),
                              Text('المتوسط: ${p7d?['avg_watt'] ?? 0}W', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800)),
                              Text('الأقصى: ${p7d?['max_watt'] ?? 0}W', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.warningAmber)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDiagRow('حالة الاتصال بالسحابة', (h?['online'] ?? strip.isOnline) ? '🟢 متصل (Online)' : '🔴 غير متصل', textPrimary),
                    _buildDiagRow('الجهد الكهربائي ونطاق الحماية', '${h?['current_voltage'] ?? strip.voltage}V (${h?['voltage_range'] ?? "175-250V"})', textPrimary),
                    _buildDiagRow('مرات فصل حماية الجهد', '${h?['voltage_breach_count'] ?? strip.voltageBreachCount} مرة', textPrimary),
                    _buildDiagRow('حرارة لوحة المشترك', '${h?['board_temp_c'] ?? 28} °C (الحد ${h?['max_temp_c'] ?? 75}°C)', textPrimary),
                    _buildDiagRow('قوة إشارة الواي فاي (RSSI)', '${h?['wifi_rssi_dbm'] ?? -48} dBm (${h?['wifi_quality'] ?? "ممتازة"})', textPrimary),
                    _buildDiagRow('نسبة الاستقرار والاتصال (Uptime)', '${h?['uptime_percent'] ?? 99.8}%', textPrimary),
                    _buildDiagRow('عدد مرات الانقطاع', '${h?['disconnect_count'] ?? 0} مرة', textPrimary),
                    _buildDiagRow('عنوان IP المحلي', h?['ip_address']?.toString() ?? strip.ipAddress ?? '-', textPrimary),
                    _buildDiagRow('إصدار الفيرموير (MCU)', 'v${h?['fw_version'] ?? strip.fwVersion}', textPrimary),
                    _buildDiagRow('معرف الهاردوير (MAC)', strip.macAddress, textSecondary),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w700, color: textPrimary)),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Real Activity Log Sheet (Fetches from GET /api/v1/strips/{mac}/logs)
  void _openActivityLogSheet() {
    if (_selectedStrip == null) return;
    final mac = _selectedStrip!.macAddress;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _repo.getStripLogs(mac),
        builder: (context, snapshot) {
          final bg = _isDark ? AppColors.cardSurfaceDark : Colors.white;
          final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
          final logs = snapshot.data ?? [];

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📜 سجل النشاط الفعلي للمشترك',
                      style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator(color: AppColors.emeraldPrimary)),
                  )
                else if (logs.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text('لا توجد أحداث مسجلة بعد', style: GoogleFonts.cairo(fontSize: 12)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final log = logs[idx];
                        final severity = (log['severity'] ?? 'INFO').toString().toUpperCase();
                        Color iconColor = AppColors.emeraldPrimary;
                        IconData icon = Icons.check_circle_outline_rounded;
                        if (severity == 'CRITICAL' || severity == 'DANGER') {
                          iconColor = Colors.redAccent;
                          icon = Icons.error_outline_rounded;
                        } else if (severity == 'WARN' || severity == 'WARNING') {
                          iconColor = AppColors.warningAmber;
                          icon = Icons.warning_amber_rounded;
                        }
                        final ts = (log['created_at'] ?? '').toString().replaceFirst('T', ' ').split('.').first;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, color: iconColor, size: 20),
                          title: Text(
                            log['message']?.toString() ?? '',
                            style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                          ),
                          subtitle: Text(
                            '${log['category'] ?? "SYSTEM"} • $ts',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 7. Feedback & Tech Support Dialog (POST /api/v1/feedback + WhatsApp Eng. Ahmed Essam)
  void _openFeedbackAndSupportDialog() {
    final msgCtrl = TextEditingController();
    String category = 'suggestion';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('إرسال مقترح / الدعم الفني 💡', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'suggestion', label: Text('مقترح تطوير')),
                    ButtonSegment(value: 'bug', label: Text('مشكلة فنية')),
                  ],
                  selected: {category},
                  onSelectionChanged: (s) => setDialogState(() => category = s.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 3,
                  style: GoogleFonts.cairo(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'اكتب مقترحك أو ملاحظتك هنا وسيتم إرسالها مباشرة للمهندس أحمد عصام...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.emeraldPrimary),
                  title: Text('واتساب المهندس أحمد عصام', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  subtitle: Text('+20 115 284 3472', style: GoogleFonts.jetBrainsMono(fontSize: 11)),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                  onTap: () {
                    final msg = Uri.encodeComponent('مرحباً م. أحمد عصام، أحتاج إلى دعم فني في تطبيق Na7la IoT');
                    _launchExternalUrl('https://wa.me/201152843472?text=$msg');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.work_outline_rounded, color: Color(0xFF0A66C2)),
                  title: Text('حساب LinkedIn الرسمي', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  subtitle: Text('Eng. Ahmed Essam', style: GoogleFonts.cairo(fontSize: 11)),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                  onTap: () => _launchExternalUrl('https://www.linkedin.com/in/ahmed-essam32'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldPrimary, foregroundColor: Colors.white),
              onPressed: () async {
                final text = msgCtrl.text.trim();
                if (text.isEmpty) return;
                final ok = await _repo.submitFeedback(category, text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? '✅ تم إرسال رسالتك وحفظها في السيرفر بنجاح، شكراً لك!' : '❌ تعذر إرسال الرسالة'),
                      backgroundColor: AppColors.emeraldPrimary,
                    ),
                  );
                }
              },
              child: Text('إرسال المقترح 🚀', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // 8. Child Lock Dialog
  void _openChildLockDialog() {
    if (_selectedStrip == null) return;
    bool currentChildLock = _selectedStrip!.childLock;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.child_care_rounded, color: AppColors.warningAmber, size: 26),
              const SizedBox(width: 8),
              Text('قفل أزرار المشترك (Child Lock)', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'يمنع قفل الأطفال فصل الأجهزة أو تشغيلها عند عبث الأطفال بالأزرار الفيزيائية للمشترك، ويحصر التحكم من داخل التطبيق فقط.',
                style: GoogleFonts.cairo(fontSize: 11.5, height: 1.5),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('تفعيل قفل الأزرار الفيزيائية', style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800)),
                value: currentChildLock,
                activeColor: AppColors.emeraldPrimary,
                onChanged: (val) => setDialogState(() => currentChildLock = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldPrimary, foregroundColor: Colors.white),
              onPressed: () async {
                final ok = await _repo.updateChildLock(_selectedStrip!.macAddress, currentChildLock);
                if (ctx.mounted) Navigator.pop(ctx);
                if (ok && mounted) {
                  setState(() => _selectedStrip!.childLock = currentChildLock);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(currentChildLock ? '👶 تم تفعيل قفل الأطفال بنجاح' : '🔓 تم تعطيل قفل الأطفال'),
                      backgroundColor: AppColors.emeraldPrimary,
                    ),
                  );
                }
              },
              child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // 9. Rename Strip & Room Dialog
  void _openStripSettingsDialog() {
    if (_selectedStrip == null) return;
    final nameCtrl = TextEditingController(text: _selectedStrip!.stripName);
    String chosenRoom = _selectedStrip!.roomCategory;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('تعديل اسم ومكان المشترك ✏️', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'اسم المشترك',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: ['living', 'office', 'bedroom', 'kitchen'].contains(chosenRoom) ? chosenRoom : 'living',
                items: const [
                  DropdownMenuItem(value: 'living', child: Text('صالة المعيشة 🛋️')),
                  DropdownMenuItem(value: 'office', child: Text('غرفة المكتب 💻')),
                  DropdownMenuItem(value: 'bedroom', child: Text('غرفة النوم 🛏️')),
                  DropdownMenuItem(value: 'kitchen', child: Text('المطبخ 🍳')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => chosenRoom = val);
                },
                decoration: InputDecoration(
                  labelText: 'الغرفة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldPrimary, foregroundColor: Colors.white),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                final success = await _repo.updateStripMetadata(
                  _selectedStrip!.macAddress,
                  name: newName,
                  roomCategory: chosenRoom,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (success && mounted) {
                  setState(() {
                    _selectedStrip!.stripName = newName;
                    _selectedStrip!.roomCategory = chosenRoom;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم حفظ اسم المشترك بنجاح'), backgroundColor: AppColors.emeraldPrimary),
                  );
                }
              },
              child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStrip(StripModel strip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('تأكيد حذف المشترك ⚠️', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.redAccent)),
        content: Text(
          'هل أنت متأكد من حذف المشترك "${strip.stripName}" (${strip.macAddress})؟\nسيتم فك ربطه من حسابك على السيرفر.',
          style: GoogleFonts.cairo(fontSize: 12, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _repo.deleteStrip(strip.macAddress);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم حذف المشترك ${strip.stripName} بنجاح')),
                );
                _loadStrips();
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  void _showQuotaUpgradeDialog(int quota) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(_tr('quota_reached_title'), style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
        content: Text(_tr('quota_reached_desc'), style: GoogleFonts.cairo(fontSize: 12, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr('btn_close'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final msg = Uri.encodeComponent('مرحباً م. أحمد عصام، أود ترقية حسابي في Na7la IoT إلى خطة برو الاحترافية');
              _launchExternalUrl('https://wa.me/201152843472?text=$msg');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldPrimary, foregroundColor: Colors.white),
            child: Text(_tr('btn_upgrade_whatsapp'), style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showPricingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(_tr('pricing_plans'), style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الخطة المجانية (Free Tier)', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.emeraldPrimary)),
                  const SizedBox(height: 4),
                  Text('• ربط مشترك واحد مجاناً\n• مراقبة حية للواط والأمبير والفولت والحرارة\n• التحكم عن بُعد والجدولة السحابية', style: GoogleFonts.cairo(fontSize: 11, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emeraldPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.emeraldPrimary, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('خطة برو (Pro Tier) ⭐', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.emeraldPrimary)),
                  const SizedBox(height: 4),
                  Text('• ربط حتى 15 مشتركاً ذكياً\n• سجل تشغيل كامل لـ 30 يوماً وتصدير Excel\n• أولوية قصوى للدعم الفني والضمان', style: GoogleFonts.cairo(fontSize: 11, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr('btn_close'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final msg = Uri.encodeComponent('مرحباً م. أحمد عصام، أود ترقية حسابي في Na7la IoT إلى خطة برو الاحترافية');
              _launchExternalUrl('https://wa.me/201152843472?text=$msg');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldPrimary, foregroundColor: Colors.white),
            child: Text(_tr('btn_upgrade_whatsapp'), style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Image.asset('assets/icons/app_icon.png', width: 28, height: 28),
            const SizedBox(width: 8),
            Text('Na7la IoT', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإصدار الاحترافي v2.0.0', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.emeraldPrimary)),
            const SizedBox(height: 6),
            Text('تطوير وبرمجة: م. أحمد عصام (Eng. Ahmed Essam)', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              'منظومة مصرية ذكية متكاملة للتحكم في المشتركات الذكية ومراقبة الطاقة وحساب الفاتورة بالشرائح المصرية وحماية الأجهزة الحساسة.',
              style: GoogleFonts.cairo(fontSize: 11, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr('btn_close'))),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardSurfaceDark : Colors.white,
        title: Text('تسجيل الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟', style: GoogleFonts.cairo(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _repo.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _openEnergyAnalytics() {
    if (_selectedStrip == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EnergyAnalyticsScreen(strip: _selectedStrip!, isDark: _isDark)),
    );
  }

  void _openProtectionScreen() {
    if (_selectedStrip == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProtectionScreen(strip: _selectedStrip!, isDark: _isDark)),
    );
  }

  void _openFamilyScreen() {
    if (_selectedStrip == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FamilySharingScreen(strip: _selectedStrip!, isDark: _isDark)),
    );
  }

  void _openAdminConsole() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminConsoleScreen(isDark: _isDark)),
    );
  }

  Widget _buildEmptyState() {
    final textPrimary = _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cleanCardDecoration(isDark: _isDark, radius: 22),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1024 / 256,
                  child: Image.asset('assets/images/strip_body_transparent.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                Text(
                  'أهلاً بك في Na7la IoT ⚡',
                  style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'لم يتم ربط أي مشترك بحسابك حتى الآن. يمكنك إضافة مشترك جديد عبر الواي فاي أو ربطه بالسيريال.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(fontSize: 12, color: textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final added = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => WizardScreen(isDark: _isDark)),
                          );
                          if (added == true) _loadStrips();
                        },
                        icon: const Icon(Icons.wifi_rounded, size: 18),
                        label: Text('إضافة عبر الواي فاي', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openClaimBySerialDialog,
                        icon: const Icon(Icons.qr_code_rounded, size: 18),
                        label: Text('ربط بالسيريال', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.emeraldPrimary,
                          side: const BorderSide(color: AppColors.emeraldPrimary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== BOTTOM NAVIGATION BAR (Material 3 Clean Style) =====================

  Widget _buildBottomNav() {
    final cardBg = _isDark ? AppColors.cardSurfaceDark : Colors.white;
    final borderColor = _isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, _tr('tab_my_strips'), Icons.power_rounded),
          _buildNavItem(1, _tr('tab_schedules'), Icons.access_time_rounded),
          _buildNavItem(2, _tr('tab_favorites'), Icons.star_border_rounded),
          _buildNavItem(3, _tr('tab_settings'), Icons.settings_outlined),
          _buildNavItem(4, _tr('tab_account'), Icons.person_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildNavItem(int idx, String title, IconData icon) {
    final isSel = _selectedTabIndex == idx;
    final inactiveColor = _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? AppColors.emeraldPrimary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: isSel ? AppColors.emeraldPrimary : inactiveColor),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                color: isSel ? AppColors.emeraldPrimary : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

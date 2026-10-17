import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/secure_storage.dart';
import '../../data/models/strip_model.dart';
import '../../data/models/socket_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/strip_repository.dart';
import '../../data/websockets/ws_manager.dart';
import '../../widgets/honey_jar_gauge.dart';
import '../../widgets/socket_card.dart';
import '../../widgets/pin_biometric_dialog.dart';
import '../analytics/energy_analytics_screen.dart';
import '../protection/protection_screen.dart';
import '../family/family_sharing_screen.dart';
import '../admin/admin_console_screen.dart';
import '../onboarding/wizard_screen.dart';
import 'widgets/socket_deep_dive_sheet.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final _repo = StripRepository();
  final _wsManager = WebSocketManager();

  int _selectedTabIndex = 0;
  bool _isDark = false;
  bool _isLoading = true;
  UserModel? _currentUser;
  List<StripModel> _strips = [];
  StripModel? _selectedStrip;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsManager.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    _isDark = await SecureStorageService.isDarkMode();
    _currentUser = await _repo.getAuthStatus();
    await _loadStrips();
  }

  Future<void> _loadStrips() async {
    setState(() => _isLoading = true);
    final strips = await _repo.getStrips();
    setState(() {
      _strips = strips;
      if (_strips.isNotEmpty) {
        _selectedStrip = _strips.first;
        _connectWebSocket();
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
      });
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
    });
    SecureStorageService.setDarkMode(_isDark);
  }

  void _onToggleSocket(SocketModel socket) {
    if (socket.isLocked) {
      // Require Biometric / PIN unlock
      showDialog(
        context: context,
        builder: (_) => PinBiometricDialog(
          title: socket.name,
          isDark: _isDark,
          onSuccess: () => _flipSocketState(socket),
        ),
      );
    } else {
      _flipSocketState(socket);
    }
  }

  Future<void> _flipSocketState(SocketModel socket) async {
    final newState = !socket.state;
    setState(() => socket.state = newState);
    if (_selectedStrip != null) {
      await _repo.switchSocket(_selectedStrip!.macAddress, socket.socketIndex, newState);
    }
  }

  void _smartAllOff() {
    if (_selectedStrip == null) return;
    for (var s in _selectedStrip!.sockets) {
      if (!s.isRouter) {
        s.state = false;
        _repo.switchSocket(_selectedStrip!.macAddress, s.socketIndex, false);
      }
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🛡️ تم إطفاء الكل مع حماية فيشة الراوتر من الفصل!')),
    );
  }

  void _turnAllOn() {
    if (_selectedStrip == null) return;
    for (var s in _selectedStrip!.sockets) {
      if (!s.isLocked) {
        s.state = true;
        _repo.switchSocket(_selectedStrip!.macAddress, s.socketIndex, true);
      }
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⚡ تم تشغيل جميع الفيش غير المقفولة')),
    );
  }

  void _openDeepDive(SocketModel socket) {
    if (_selectedStrip == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SocketDeepDiveSheet(
        mac: _selectedStrip!.macAddress,
        socket: socket,
        isDark: _isDark,
        onUpdated: (_) => setState(() {}),
      ),
    );
  }

  void _openStripSettingsDialog() {
    if (_selectedStrip == null) return;
    final nameCtrl = TextEditingController(text: _selectedStrip!.stripName);
    String chosenRoom = _selectedStrip!.roomCategory;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: _isDark ? AppColors.darkBorder : AppColors.inkBlack, width: 2.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: AppColors.honeyAmber),
              const SizedBox(width: 8),
              Text('إعدادات المشترك', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('اسم المشترك:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),

                Text('مكان المشترك (الغرفة):', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                const SizedBox(height: 14),

                // Technical Info Card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('معلومات الهاردوير:', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text('MAC: ${_selectedStrip!.macAddress}', style: GoogleFonts.jetBrainsMono(fontSize: 10)),
                      Text('IP: ${_selectedStrip!.ipAddress ?? "-"}', style: GoogleFonts.jetBrainsMono(fontSize: 10)),
                      Text('Firmware: ${_selectedStrip!.fwVersion}', style: GoogleFonts.jetBrainsMono(fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Save Name & Room Button
                ElevatedButton.icon(
                  onPressed: () async {
                    await _repo.updateStripMetadata(
                      _selectedStrip!.macAddress,
                      name: nameCtrl.text.trim(),
                      roomCategory: chosenRoom,
                    );
                    Navigator.of(ctx).pop();
                    _loadStrips();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ بيانات المشترك بنجاح')),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('حفظ التعديلات', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.honeyYellow,
                    foregroundColor: AppColors.inkBlack,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                // Delete Strip Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _confirmDeleteStrip(_selectedStrip!);
                  },
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                  label: Text('حذف المشترك وإلغاء الربط 🗑️', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteStrip(StripModel strip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Colors.redAccent, width: 2.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 8),
            Text('تأكيد حذف المشترك', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف المشترك "${strip.stripName}" (${strip.macAddress})؟\n\nسيتم فك ربطه من حسابك وتصفير إعداداته وإتاحته لأي مستخدم آخر.',
          style: GoogleFonts.cairo(fontSize: 12, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              showDialog(
                context: context,
                builder: (_) => PinBiometricDialog(
                  title: 'تأكيد أمني لحذف المشترك',
                  isDark: _isDark,
                  onSuccess: () async {
                    final ok = await _repo.deleteStrip(strip.macAddress);
                    if (ok) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم حذف المشترك ${strip.stripName} بنجاح')),
                        );
                      }
                      _loadStrips();
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('حدث خطأ أثناء حذف المشترك')),
                        );
                      }
                    }
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('تأكيد الحذف 🗑️', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _isDark ? AppColors.darkBg : AppColors.outerYellow,
        body: const Center(child: CircularProgressIndicator(color: AppColors.inkBlack)),
      );
    }

    return Scaffold(
      backgroundColor: _isDark ? AppColors.darkBg : AppColors.outerYellow,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            _buildHeader(),

            // Active Tab Viewport
            Expanded(
              child: _selectedStrip == null
                  ? _buildEmptyState()
                  : _buildActiveTabContent(),
            ),

            // Bottom Navigation Bar
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/icons/app_icon.png', width: 40, height: 40),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'نحلة IoT',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _isDark ? Colors.white : AppColors.inkBlack,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (_selectedStrip?.isOnline ?? false) ? const Color(0xFF10B981) : Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.inkBlack, width: 1),
                        ),
                        child: Text(
                          (_selectedStrip?.isOnline ?? false) ? 'متصل' : 'أوفلاين',
                          style: GoogleFonts.cairo(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                      ),
                      if (_selectedStrip != null)
                        GestureDetector(
                          onTap: _openStripSettingsDialog,
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.settings_rounded,
                              size: 14,
                              color: _isDark ? Colors.white70 : AppColors.inkBlack,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_strips.length > 1)
                    DropdownButton<StripModel>(
                      value: _selectedStrip,
                      underline: const SizedBox(),
                      isDense: true,
                      items: _strips.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.stripName} (${s.roomCategory})',
                            style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        );
                      }).toList(),
                      onChanged: (newStrip) {
                        if (newStrip != null) {
                          setState(() => _selectedStrip = newStrip);
                          _connectWebSocket();
                        }
                      },
                    )
                  else
                    Text(
                      _selectedStrip?.stripName ?? 'مشترك الصالة الذكي',
                      style: GoogleFonts.cairo(fontSize: 10, color: _isDark ? Colors.white70 : Colors.black54),
                    ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Admin Console Button (Exclusive to ADMIN role)
              if (_currentUser?.isAdmin ?? false)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AdminConsoleScreen(isDark: _isDark)),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.honeyAmber,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inkBlack, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.admin_panel_settings_rounded, size: 14, color: AppColors.inkBlack),
                        const SizedBox(width: 4),
                        Text('الأدمن 👑', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),

              // Prominent Add Strip Button
              GestureDetector(
                onTap: () async {
                  final added = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => WizardScreen(isDark: _isDark)),
                  );
                  if (added == true) _loadStrips();
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isDark ? AppColors.cardSurfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isDark ? AppColors.darkBorder : AppColors.inkBlack, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: _isDark ? Colors.white : AppColors.inkBlack),
                      const SizedBox(width: 2),
                      Text(
                        'إضافة',
                        style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900, color: _isDark ? Colors.white : AppColors.inkBlack),
                      ),
                    ],
                  ),
                ),
              ),

              // Dark Theme Toggle
              GestureDetector(
                onTap: _toggleTheme,
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: AppColors.inkBlack,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.honeyYellow, width: 2),
                  ),
                  child: Icon(
                    _isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    size: 16,
                    color: AppColors.honeyYellow,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return EnergyAnalyticsScreen(strip: _selectedStrip!, isDark: _isDark);
      case 2:
        return ProtectionScreen(strip: _selectedStrip!, isDark: _isDark);
      case 3:
        return FamilySharingScreen(strip: _selectedStrip!, isDark: _isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildHomeTab() {
    final double totalWatts = _selectedStrip!.totalWatt;
    final double totalAmps = _selectedStrip!.totalAmp;
    final double totalKwh = _selectedStrip!.totalKwh;
    final double todayCost = totalKwh * 1.45;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Honey Jar Main Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.inkCardDecoration(isDark: _isDark),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🐝 إجمالي سحب الخلية الآن', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                totalWatts.toStringAsFixed(0),
                                style: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'WATTS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.honeyAmber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.honeyYellow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.inkBlack, width: 1.5),
                            ),
                            child: Text(
                              '📐 تكلفة اليوم: ${todayCost.toStringAsFixed(2)} ج.م',
                              style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.inkBlack),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.inkBlack,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '⚡ ${_selectedStrip!.currentVoltage?.toStringAsFixed(0) ?? 224}V  |  ${totalAmps.toStringAsFixed(2)}A  |  ${totalKwh.toStringAsFixed(1)}kWh',
                              style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: AppColors.honeyYellow, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    HoneyJarGauge(currentWatts: totalWatts, isDark: _isDark),
                  ],
                ),
                const SizedBox(height: 12),
                // Master Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _turnAllOn,
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: Text('تشغيل الكل', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.honeyYellow,
                          foregroundColor: AppColors.inkBlack,
                          side: const BorderSide(color: AppColors.inkBlack, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _smartAllOff,
                        icon: const Icon(Icons.shield_rounded, size: 16, color: AppColors.routerCyan),
                        label: Text('إطفاء ذكي آمن', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.inkBlack,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.honeyAmber, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!(_selectedStrip?.isOnline ?? false))
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade700, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚠️ المشترك غير متصل بالكهرباء أو الواي فاي (أوفلاين) - القراءات متوقفة لحين عودة الاتصال بالسيرفر.',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _isDark ? Colors.white : AppColors.inkBlack,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Outlets Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🔌 المخارج الأربعة المستقلة', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900)),
              Text('اضغط ⚙️ للإعدادات', style: GoogleFonts.cairo(fontSize: 10, color: _isDark ? Colors.white60 : Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),

          // 2x2 Grid of the 4 Sockets
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedStrip!.sockets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final socket = _selectedStrip!.sockets[index];
              return SocketCard(
                socket: socket,
                isDark: _isDark,
                onToggle: () => _onToggleSocket(socket),
                onOpenDeepDive: () => _openDeepDive(socket),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/icons/app_icon.png', width: 90, height: 90),
          const SizedBox(height: 14),
          Text('أهلاً بك في عالم نحلة الذكي!', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900)),
          Text('لم يتم ربط أي مشترك بحسابك حتى الآن', style: GoogleFonts.cairo(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () async {
              final added = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => WizardScreen(isDark: _isDark)),
              );
              if (added == true) _loadStrips();
            },
            icon: const Icon(Icons.add_rounded),
            label: Text('ربط أول مشترك الآن 🚀', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.honeyYellow,
              foregroundColor: AppColors.inkBlack,
              side: const BorderSide(color: AppColors.inkBlack, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _isDark ? AppColors.cardSurfaceDark : AppColors.inkBlack,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _isDark ? AppColors.darkBorder : AppColors.honeyYellow, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, 'الخلية', Icons.home_rounded),
          _buildNavItem(1, 'الفاتورة', Icons.analytics_outlined),
          _buildNavItem(2, 'الحماية', Icons.shield_outlined),
          _buildNavItem(3, 'العائلة', Icons.people_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildNavItem(int idx, String title, IconData icon) {
    final isSel = _selectedTabIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = idx),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: isSel ? AppColors.honeyYellow : Colors.white60),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 9.5,
              fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
              color: isSel ? AppColors.honeyYellow : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

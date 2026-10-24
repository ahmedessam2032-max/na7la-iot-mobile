import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/strip_repository.dart';
import '../auth/login_screen.dart';
import '../home/home_dashboard_screen.dart';

class AdminConsoleScreen extends StatefulWidget {
  final bool isDark;

  const AdminConsoleScreen({super.key, required this.isDark});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  final _repo = StripRepository();
  List<dynamic> _users = [];
  List<dynamic> _strips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    final users = await _repo.getAdminUsers();
    final strips = await _repo.getAdminStrips();
    setState(() {
      _users = users;
      _strips = strips;
      _isLoading = false;
    });
  }

  Future<void> _adjustQuota(int userId, int currentQuota, int delta) async {
    final newQuota = (currentQuota + delta).clamp(1, 20);
    final ok = await _repo.updateAdminUserQuota(userId, newQuota);
    if (ok) {
      _loadAdminData();
    }
  }

  Future<void> _unbindStrip(int stripId, String deviceRef) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
        title: Text('تحرير فتحة الجهاز ($deviceRef)', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text(
          'هل تريد فك ربط فتحة الجهاز "$deviceRef"؟\n(عناوين الـ MAC والـ IP مشفرة بنظام Zero-Knowledge ولا تُكشف أبداً للإدارة).',
          style: GoogleFonts.cairo(fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('تأكيد التحرير'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await _repo.unbindAdminStrip(stripId);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحرير فتحة الجهاز $deviceRef بنجاح')),
        );
        _loadAdminData();
      }
    }
  }

  Future<void> _openChangePasswordDialog() async {
    final currCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    bool obscure = true;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            '🔐 تغيير كلمة مرور الأدمن',
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'سيتم تشفير كلمة المرور الجديدة بـ bcrypt وإبطال جميع الجلسات الأخرى المفتوحة فوراً.',
                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: currCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setModalState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة (8+ خانات وحروف وأرقام)',
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور الجديدة',
                    prefixIcon: const Icon(Icons.verified_user_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      setModalState(() => saving = true);
                      final res = await _repo.changePassword(
                        currentPassword: currCtrl.text,
                        newPassword: newCtrl.text,
                        confirmPassword: confCtrl.text,
                      );
                      setModalState(() => saving = false);
                      if (res['success'] == true && ctx.mounted) {
                        Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'تم تغيير كلمة المرور بنجاح'),
                              backgroundColor: AppColors.emeraldPrimary,
                            ),
                          );
                        }
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'فشل تغيير كلمة المرور'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
              child: Text(saving ? 'جارٍ التشفير...' : 'حفظ وتشفير'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : Colors.white,
        title: Text('تسجيل الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text('هل أنت متأكد من رغبتك في تسجيل الخروج من حساب الأدمن؟', style: GoogleFonts.cairo(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
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

  @override
  Widget build(BuildContext context) {
    final onlineCount = _strips.where((s) => s['is_online'] == true).length;

    return Scaffold(
      backgroundColor: widget.isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          '👑 إدارة المنصة (Admin Console)',
          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : Colors.white,
        foregroundColor: widget.isDark ? Colors.white : AppColors.inkBlack,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded, color: AppColors.emeraldPrimary),
            tooltip: 'تغيير كلمة مرور الأدمن',
            onPressed: _openChangePasswordDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: _loadAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_rounded),
            tooltip: 'التبديل لواجهة المستخدم',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.inkBlack))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KPI Stats Row
                  Row(
                    children: [
                      _buildKpiCard('إجمالي العملاء', '${_users.length}', Icons.people_alt_rounded),
                      const SizedBox(width: 8),
                      _buildKpiCard('إجمالي الأجهزة', '${_strips.length}', Icons.devices_rounded),
                      const SizedBox(width: 8),
                      _buildKpiCard('المتصل الآن', '$onlineCount أونلاين', Icons.wifi_rounded, isHighlight: true),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fleet Strips Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.inkCardDecoration(isDark: widget.isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '⚡ أسطول المشتركات في المنصة',
                              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '${_strips.length} مشترك',
                              style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.honeyAmber),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.emeraldPrimary.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield_rounded, size: 15, color: AppColors.emeraldPrimary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'وضع الخصوصية Zero-Knowledge نشط: عناوين MAC و IP وأسماء المشتركات مشفرة بـ AES-256-GCM ومخفية تماماً.',
                                  style: GoogleFonts.cairo(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_strips.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'لا يوجد أي مشتركات مسجلة على المنصة حالياً (قاعدة البيانات فارغة)',
                                style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ..._strips.map((s) {
                            final int stripId = (s['id'] as num?)?.toInt() ?? 0;
                            final String deviceRef = (s['device_ref'] ?? 'STRIP-#$stripId').toString();
                            final String owner = (s['owner_email'] ?? 'حر').toString();
                            final bool isOnline = s['is_online'] == true;
                            final String fw = (s['fw_version'] ?? '1.0.66').toString();
                            final String model = (s['model'] ?? 'MTTL-W01').toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: widget.isDark ? AppColors.cardMutedDark : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isOnline ? const Color(0xFF10B981) : Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              deviceRef,
                                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppColors.emeraldPrimary.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '🔒 MAC/IP مشفر',
                                                style: GoogleFonts.cairo(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'المالك: $owner  |  $model (FW $fw)',
                                          style: GoogleFonts.cairo(fontSize: 9.5, color: widget.isDark ? Colors.white70 : Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _unbindStrip(stripId, deviceRef),
                                    child: Text(
                                      'تحرير 🔓',
                                      style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Management Table Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AppTheme.inkCardDecoration(isDark: widget.isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '👥 قائمة عملاء المنصة وكوتة المشتركات',
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        ..._users.map((u) {
                          final int uid = u['id'] ?? 0;
                          final int quota = u['max_strips'] ?? 1;
                          final String email = u['email'] ?? '';
                          final String role = u['role'] ?? 'USER';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.isDark ? AppColors.cardMutedDark : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        email,
                                        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: role == 'ADMIN' ? AppColors.honeyAmber : Colors.blueGrey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          role,
                                          style: GoogleFonts.cairo(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.black),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text('كوتة: $quota', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w900)),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                      onPressed: () => _adjustQuota(uid, quota, -1),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                      onPressed: () => _adjustQuota(uid, quota, 1),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: AppTheme.inkCardDecoration(
          isDark: widget.isDark,
          surfaceColor: isHighlight ? (widget.isDark ? AppColors.cardActiveDark : AppColors.honeyYellow) : null,
          radius: 14,
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isHighlight ? AppColors.inkBlack : AppColors.honeyAmber),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

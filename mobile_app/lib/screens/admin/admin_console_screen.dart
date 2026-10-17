import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/strip_repository.dart';

class AdminConsoleScreen extends StatefulWidget {
  final bool isDark;

  const AdminConsoleScreen({super.key, required this.isDark});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  final _repo = StripRepository();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    final users = await _repo.getAdminUsers();
    setState(() {
      _users = users;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDark ? AppColors.darkBg : AppColors.outerYellow,
      appBar: AppBar(
        title: Text(
          '👑 بوابة إدارة المنصة (Admin Console)',
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : AppColors.honeyYellow,
        foregroundColor: AppColors.inkBlack,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAdminData,
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
                      _buildKpiCard('إجمالي المستخدمين', '${_users.length}', Icons.people_alt_rounded),
                      const SizedBox(width: 10),
                      _buildKpiCard('المشتركات النشطة', '1 أونلاين', Icons.power_rounded),
                    ],
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

  Widget _buildKpiCard(String title, String val, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.inkCardDecoration(isDark: widget.isDark, radius: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.honeyYellow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inkBlack, width: 1.5),
              ),
              child: Icon(icon, size: 20, color: AppColors.inkBlack),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.w700)),
                  Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

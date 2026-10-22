import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';

class AccountTab extends StatelessWidget {
  final UserModel? user;
  final bool isDark;
  final int stripsCount;
  final VoidCallback onUpgradeQuota;
  final VoidCallback onLogout;

  const AccountTab({
    super.key,
    required this.user,
    required this.isDark,
    required this.stripsCount,
    required this.onUpgradeQuota,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final maxAllowed = user?.maxStripsAllowed ?? 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3 KPI Matrix (Plan, Max Strips, Current Used) matching HTML #tab-account
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF33312B) : Colors.black12,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                _buildKpiItem(
                  icon: Icons.label_important_outline_rounded,
                  value: maxAllowed > 1 ? 'خطة برو' : 'الخطة المجانية',
                  label: 'الخطة',
                  color: AppColors.honeyYellow,
                ),
                _buildKpiItem(
                  icon: Icons.hub_outlined,
                  value: '$maxAllowed مشترك',
                  label: 'سعة الحساب',
                  color: AppColors.honeyAmber,
                ),
                _buildKpiItem(
                  icon: Icons.power_rounded,
                  value: '$stripsCount من $maxAllowed',
                  label: 'المستخدم حالياً',
                  color: AppColors.routerCyan,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // User Profile Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF33312B) : Colors.black12,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5A31A), Color(0xFFF7E84A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF5A31A).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🐝', style: TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? 'user@na7la-iot.com',
                  style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.honeyYellow.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.honeyYellow, width: 1),
                  ),
                  child: Text(
                    user?.role == 'admin' ? 'المالك الرئيسي للنظام 👑' : 'مستخدم موثق ✅',
                    style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.honeyYellow,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Upgrade Plan CTA Button
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.honeyYellow.withOpacity(0.12),
                  AppColors.honeyAmber.withOpacity(0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.honeyYellow, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ترقية الحساب إلى خطة برو 🚀',
                      style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'سعة حتى 15 مشتركاً وجدولة ذكية غير محدودة',
                      style: GoogleFonts.cairo(fontSize: 9.5, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: onUpgradeQuota,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.honeyYellow,
                    foregroundColor: AppColors.inkBlack,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('ترقية', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Logout Button
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
            label: Text(
              'تسجيل الخروج من الحساب',
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.redAccent),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 9.5, color: isDark ? Colors.white60 : Colors.black54),
          ),
        ],
      ),
    );
  }
}

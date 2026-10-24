import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/strip_repository.dart';
import '../auth/login_screen.dart';

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

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
        title: Text('حذف الحساب نهائياً ⚠️', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.redAccent)),
        content: Text(
          'هل أنت متأكد من حذف حسابك نهائياً؟ سيتم فك ربط المشتركات المسجلة وحذف بيانات الحساب من السيرفر ولا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(fontSize: 12, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('تأكيد الحذف النهائي', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final repo = StripRepository();
      final ok = await repo.deleteMyAccount();
      if (ok && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن حذف الحساب الرئيسي للمالك (Admin) أو حدث خطأ في السيرفر'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxAllowed = user?.maxStripsAllowed ?? 1;
    final cardBg = isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3 KPI Matrix (Plan, Max Strips, Current Used)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Row(
              children: [
                _buildKpiItem(
                  icon: Icons.verified_user_outlined,
                  value: maxAllowed > 1 ? 'خطة برو' : 'الخطة المجانية',
                  label: 'الخطة',
                  color: AppColors.emeraldPrimary,
                ),
                _buildKpiItem(
                  icon: Icons.hub_outlined,
                  value: '$maxAllowed مشترك',
                  label: 'سعة الحساب',
                  color: AppColors.warningAmber,
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
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.emeraldPrimary, AppColors.emeraldDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emeraldPrimary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.person_rounded, size: 34, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? user?.email.split('@').first ?? 'مستخدم Na7la IoT',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
                ),
                Text(
                  user?.email ?? 'user@na7la-iot.com',
                  style: GoogleFonts.cairo(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emeraldPrimary, width: 1),
                  ),
                  child: Text(
                    user?.isAdmin ?? false ? 'المالك الرئيسي للنظام 👑' : 'حساب موثق ✅',
                    style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emeraldPrimary,
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
                  AppColors.emeraldPrimary.withOpacity(0.12),
                  AppColors.emeraldDark.withOpacity(0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.emeraldPrimary, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ترقية الحساب إلى خطة برو 🚀',
                      style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary),
                    ),
                    Text(
                      'سعة حتى 15 مشتركاً وجدولة ذكية غير محدودة',
                      style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: onUpgradeQuota,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              side: const BorderSide(color: Colors.redAccent, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),

          if (!(user?.isAdmin ?? false))
            TextButton.icon(
              onPressed: () => _confirmDeleteAccount(context),
              icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.grey),
              label: Text(
                'حذف الحساب نهائياً',
                style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700),
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
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w900, color: textPrimary),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_locale.dart';
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

  Future<void> _openChangePasswordDialog(BuildContext context) async {
    final currCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    bool obscure = true;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: AppLocaleController.instance.textDirection,
          child: AlertDialog(
            backgroundColor: isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              trBi('🔐 تغيير كلمة المرور المشفرة', '🔐 Change Encrypted Password'),
              style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trBi(
                      'تُشفر كلمة المرور بـ bcrypt مع إبطال فوري لكافة الجلسات المفتوحة على أي أجهزة أخرى.',
                      'Passwords are encrypted with bcrypt and all active sessions on other devices are immediately revoked.',
                    ),
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: currCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: trBi('كلمة المرور الحالية', 'Current Password'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.emeraldPrimary),
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
                      labelText: trBi('كلمة المرور الجديدة (8+ خانات وحروف وأرقام)', 'New Password (8+ chars, letters & numbers)'),
                      prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.emeraldPrimary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: trBi('تأكيد كلمة المرور الجديدة', 'Confirm New Password'),
                      prefixIcon: const Icon(Icons.verified_user_rounded, color: AppColors.emeraldPrimary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: Text(trBi('إلغاء', 'Cancel'), style: GoogleFonts.cairo(color: Colors.grey)),
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
                        final repo = StripRepository();
                        final res = await repo.changePassword(
                          currentPassword: currCtrl.text,
                          newPassword: newCtrl.text,
                          confirmPassword: confCtrl.text,
                        );
                        setModalState(() => saving = false);
                        if (res['success'] == true && ctx.mounted) {
                          Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? trBi('تم تغيير كلمة المرور بنجاح', 'Password updated successfully')),
                                backgroundColor: AppColors.emeraldPrimary,
                              ),
                            );
                          }
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? trBi('تعذر تغيير كلمة المرور', 'Failed to update password')),
                              backgroundColor: AppColors.dangerRed,
                            ),
                          );
                        }
                      },
                child: Text(
                  saving ? trBi('جارٍ التشفير...', 'Encrypting...') : trBi('حفظ كلمة المرور', 'Save Password'),
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openJoinShareDialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocaleController.instance.textDirection,
        child: AlertDialog(
          backgroundColor: isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            trBi('👨‍👩‍👧 الانضمام لمشترك عائلي بكود دعوة', '👨‍👩‍👧 Join Shared Family Strip'),
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: trBi('أدخل كود الدعوة (مثال: NA7LA-XXXX)', 'Enter Invite Code (e.g. NA7LA-XXXX)'),
              prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.emeraldPrimary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(trBi('إلغاء', 'Cancel'), style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final code = codeCtrl.text.trim();
                if (code.isEmpty) return;
                final repo = StripRepository();
                final res = await repo.joinSharedStrip(code);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? res['detail'] ?? trBi('تمت العملية', 'Completed')),
                      backgroundColor: res['ok'] == true ? AppColors.emeraldPrimary : AppColors.dangerRed,
                    ),
                  );
                }
              },
              child: Text(trBi('ربط المشترك بحسابي', 'Link Strip to Account'), style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocaleController.instance.textDirection,
        child: AlertDialog(
          backgroundColor: isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
          title: Text(
            trBi('حذف الحساب نهائياً ⚠️', 'Delete Account Permanently ⚠️'),
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.redAccent),
          ),
          content: Text(
            trBi(
              'هل أنت متأكد من حذف حسابك نهائياً؟ سيتم فك ربط المشتركات المسجلة وحذف بيانات الحساب من السيرفر ولا يمكن التراجع عن هذا الإجراء.',
              'Are you sure you want to permanently delete your account? All paired strips will be unlinked and your account data will be erased.',
            ),
            style: GoogleFonts.cairo(fontSize: 12, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(trBi('إلغاء', 'Cancel'), style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                trBi('تأكيد الحذف النهائي', 'Confirm Permanent Delete'),
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
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
          SnackBar(
            content: Text(
              trBi(
                'لا يمكن حذف الحساب الرئيسي للمالك (Admin) أو حدث خطأ في السيرفر',
                'Cannot delete the primary Admin account or a server error occurred',
              ),
            ),
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
                  value: maxAllowed > 1 ? trBi('خطة برو', 'Pro Plan') : trBi('الخطة المجانية', 'Free Tier'),
                  label: trBi('الخطة', 'Plan'),
                  color: AppColors.emeraldPrimary,
                ),
                _buildKpiItem(
                  icon: Icons.hub_outlined,
                  value: trBi('$maxAllowed مشترك', '$maxAllowed Strips'),
                  label: trBi('سعة الحساب', 'Quota'),
                  color: AppColors.warningAmber,
                ),
                _buildKpiItem(
                  icon: Icons.power_rounded,
                  value: trBi('$stripsCount من $maxAllowed', '$stripsCount / $maxAllowed'),
                  label: trBi('المستخدم حالياً', 'Active Now'),
                  color: AppColors.routerCyan,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
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
                    child: Icon(Icons.person_rounded, size: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.fullName ?? user?.email.split('@').first ?? trBi('مستخدم Na7la IoT', 'Na7la IoT User'),
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
                    user?.isAdmin ?? false
                        ? trBi('المالك الرئيسي للنظام 👑', 'Platform Owner (Admin) 👑')
                        : trBi('حساب موثق ✅', 'Verified Account ✅'),
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
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trBi('تغيير كلمة المرور وحماية الجلسات 🔐', 'Change Password & Session Security 🔐'),
                        style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary),
                      ),
                      Text(
                        trBi(
                          'تشفير bcrypt + إبطال فوري لأي جلسة مفتوحة على جهاز آخر',
                          'bcrypt encryption + instant revocation of sessions on other devices',
                        ),
                        style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openChangePasswordDialog(context),
                  icon: const Icon(Icons.lock_reset_rounded, size: 15),
                  label: Text(trBi('تغيير', 'Change'), style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trBi('الانضمام لمشترك عائلي مشترك 👨‍👩‍👧', 'Join a Shared Family Strip 👨‍👩‍👧'),
                        style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary),
                      ),
                      Text(
                        trBi(
                          'أدخل كود الدعوة المرسل إليك للتحكم بالمشترك أو المخرج',
                          'Enter an invite code sent to you to control a shared strip or outlet',
                        ),
                        style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openJoinShareDialog(context),
                  icon: const Icon(Icons.vpn_key_rounded, size: 15),
                  label: Text(trBi('إدخال الكود', 'Enter Code'), style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trBi('ترقية الحساب إلى خطة برو 🚀', 'Upgrade Account to Pro Plan 🚀'),
                        style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary),
                      ),
                      Text(
                        trBi(
                          'سعة حتى 15 مشتركاً وجدولة ذكية غير محدودة',
                          'Up to 15 smart strips & unlimited cloud schedules',
                        ),
                        style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onUpgradeQuota,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(trBi('ترقية', 'Upgrade'), style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldPrimary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.engineering_rounded, color: AppColors.emeraldPrimary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trBi(
                              'تطوير وتصميم: م. أحمد عصام (Eng. Ahmed Essam)',
                              'Engineered by: Eng. Ahmed Essam',
                            ),
                            style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary),
                          ),
                          Text(
                            'IoT Systems & Cloud Software Architect • Na7la IoT v2.0.0',
                            style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse('https://wa.me/201152843472'), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.chat_rounded, size: 16, color: AppColors.emeraldPrimary),
                        label: Text(
                          trBi('واتساب المطور', 'WhatsApp Support'),
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.emeraldPrimary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse('https://www.linkedin.com/in/ahmed-essam32'), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.business_center_rounded, size: 16, color: AppColors.routerCyan),
                        label: Text('LinkedIn', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.routerCyan)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.routerCyan),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '﴿ وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ ۚ عَلَيْهِ تَوَكَّلْتُ وَإِلَيْهِ أُنِيبُ ﴾',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
            label: Text(
              trBi('تسجيل الخروج من الحساب', 'Sign Out from Account'),
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.redAccent),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),

          if (!(user?.isAdmin ?? false))
            TextButton.icon(
              onPressed: () => _confirmDeleteAccount(context),
              icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.grey),
              label: Text(
                trBi('حذف الحساب نهائياً', 'Delete Account Permanently'),
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

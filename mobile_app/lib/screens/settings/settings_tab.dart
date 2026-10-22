import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_locale.dart';
import '../../data/models/strip_model.dart';

class SettingsTab extends StatelessWidget {
  final StripModel strip;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenProtection;
  final VoidCallback onOpenFamily;
  final VoidCallback onOpenAdminConsole;

  const SettingsTab({
    super.key,
    required this.strip,
    required this.isDark,
    required this.onToggleTheme,
    required this.onOpenProtection,
    required this.onOpenFamily,
    required this.onOpenAdminConsole,
  });

  @override
  Widget build(BuildContext context) {
    final locale = AppLocaleController.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Appearance & Language
          _buildSectionHeader('المظهر واللغة'),
          _buildCard(
            children: [
              _buildRow(
                icon: Icons.palette_outlined,
                title: 'مظهر التطبيق',
                valueBadge: isDark ? 'داكن (عسلي) 🌙' : 'فاتح ☀️',
                onTap: onToggleTheme,
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildRow(
                icon: Icons.language_rounded,
                title: 'لغة الواجهة',
                valueBadge: locale.isArabic ? 'العربية' : 'English',
                onTap: () => locale.toggleLanguage(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Security & Protection
          _buildSectionHeader('حماية المشترك والأجهزة'),
          _buildCard(
            children: [
              _buildRow(
                icon: Icons.shield_outlined,
                title: 'حماية الجهد والفولت الكهربائي',
                valueBadge: '${strip.minVoltage.toInt()}V - ${strip.maxVoltage.toInt()}V',
                onTap: onOpenProtection,
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildRow(
                icon: Icons.people_outline_rounded,
                title: 'مشاركة الصلاحيات مع أفراد البيت',
                valueBadge: 'إدارة العائلة',
                onTap: onOpenFamily,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 3: Management
          _buildSectionHeader('إدارة المنصة المتقدمة'),
          _buildCard(
            children: [
              _buildRow(
                icon: Icons.admin_panel_settings_outlined,
                title: 'بوابة إدارة المنصة (الأدمن)',
                valueBadge: '👑 Console',
                onTap: onOpenAdminConsole,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4, left: 4),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AppColors.honeyYellow,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF33312B) : Colors.black12,
          width: 1.5,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String title,
    required String valueBadge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.honeyYellow),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.honeyYellow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueBadge,
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
    );
  }
}

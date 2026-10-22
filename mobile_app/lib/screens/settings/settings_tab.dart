import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/security/biometric_service.dart';
import '../../core/localization/app_locale.dart';
import '../../data/models/strip_model.dart';
import '../../widgets/pin_biometric_dialog.dart';

class SettingsTab extends StatefulWidget {
  final StripModel strip;
  final bool isDark;
  final bool isAdmin;
  final VoidCallback onOpenProtection;
  final VoidCallback onOpenFamily;
  final VoidCallback onOpenAdminConsole;

  const SettingsTab({
    super.key,
    required this.strip,
    required this.isDark,
    this.isAdmin = false,
    required this.onOpenProtection,
    required this.onOpenFamily,
    required this.onOpenAdminConsole,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _tariffPrice = 1.45;
  bool _hasPin = false;
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final price = await SecureStorageService.getTariffPrice();
    final hasPin = await BiometricService.hasPin();
    final appLock = await SecureStorageService.isAppLockEnabled();
    if (mounted) {
      setState(() {
        _tariffPrice = price;
        _hasPin = hasPin;
        _appLockEnabled = appLock;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      final success = await BiometricService.authenticateBiometric(
        reason: 'أكّد هويتك بالبصمة أو رمز الجهاز لتفعيل قفل التطبيق',
      );
      if (success) {
        await SecureStorageService.setAppLockEnabled(true);
        setState(() => _appLockEnabled = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('سيُطلب فتح التطبيق بالبصمة من الآن 🔐')),
          );
        }
      }
    } else {
      final success = await BiometricService.authenticateBiometric(
        reason: 'أكّد هويتك بالبصمة أو رمز الجهاز لإلغاء قفل التطبيق',
      );
      if (success) {
        await SecureStorageService.setAppLockEnabled(false);
        setState(() => _appLockEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء قفل التطبيق 🔓')),
          );
        }
      }
    }
  }

  void _openTariffDialog() {
    final controller = TextEditingController(text: _tariffPrice.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تسعيرة الكيلوواط بالساعة ⚡',
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أدخل سعر الكيلوواط في شريحتك المنزلية لحساب فاتورة الكهرباء اليومية بدقة:',
              style: GoogleFonts.cairo(fontSize: 11, color: widget.isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                suffixText: 'ج.م / kWh',
                filled: true,
                fillColor: widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.honeyYellow,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final newP = double.tryParse(controller.text.trim()) ?? 1.45;
              await SecureStorageService.saveTariffPrice(newP);
              setState(() => _tariffPrice = newP);
              Navigator.pop(ctx);
            },
            child: Text('حفظ التسعيرة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _openPinSetupDialog() {
    showDialog(
      context: context,
      builder: (_) => PinBiometricDialog(
        title: _hasPin ? 'تغيير رمز PIN الماستر' : 'إعداد رمز PIN الماستر',
        isDark: widget.isDark,
        onSuccess: () {
          _loadSettings();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث رمز الحماية بنجاح 🛡️')),
          );
        },
      ),
    );
  }

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
                icon: Icons.language_rounded,
                title: 'لغة التطبيق',
                valueBadge: locale.isArabic ? 'العربية' : 'English',
                onTap: () {
                  locale.setLocale(Locale(locale.isArabic ? 'en' : 'ar'));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Security & Protection
          _buildSectionHeader('الأمان والحماية المتقدمة'),
          _buildCard(
            children: [
              _buildRow(
                icon: Icons.shield_outlined,
                title: 'حماية الجهد والفولت الكهربائي',
                valueBadge: '${widget.strip.minVoltage.toInt()}V - ${widget.strip.maxVoltage.toInt()}V',
                onTap: widget.onOpenProtection,
              ),
              Divider(height: 1, color: widget.isDark ? AppColors.borderDark : AppColors.borderLight),
              _buildRow(
                icon: Icons.lock_outline_rounded,
                title: 'رمز PIN الماستر',
                valueBadge: _hasPin ? 'مفعّل 🔐' : 'تعيين الرمز ⚠️',
                onTap: _openPinSetupDialog,
              ),
              Divider(height: 1, color: widget.isDark ? AppColors.borderDark : AppColors.borderLight),
              _buildSwitchRow(
                icon: Icons.fingerprint_rounded,
                title: 'قفل التطبيق بالبصمة',
                subtitle: 'طلب البصمة أو رمز الجهاز عند فتح التطبيق',
                value: _appLockEnabled,
                onChanged: _toggleAppLock,
              ),
              Divider(height: 1, color: widget.isDark ? AppColors.borderDark : AppColors.borderLight),
              _buildRow(
                icon: Icons.electric_bolt_outlined,
                title: 'سعر الكيلوواط (تسعيرة الفاتورة)',
                valueBadge: '${_tariffPrice.toStringAsFixed(2)} ج.م',
                onTap: _openTariffDialog,
              ),
              Divider(height: 1, color: widget.isDark ? AppColors.borderDark : AppColors.borderLight),
              _buildRow(
                icon: Icons.people_outline_rounded,
                title: 'مشاركة الصلاحيات مع أفراد البيت',
                valueBadge: 'إدارة العائلة',
                onTap: widget.onOpenFamily,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 3: Admin Console (Strictly gated by isAdmin)
          if (widget.isAdmin) ...[
            _buildSectionHeader('إدارة المنصة المتقدمة (الأدمن)'),
            _buildCard(
              children: [
                _buildRow(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'بوابة إدارة المنصة (الأدمن)',
                  valueBadge: '👑 Console',
                  onTap: widget.onOpenAdminConsole,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Section 4: Device & System Info
          _buildSectionHeader('معلومات الجهاز والاتصال'),
          _buildCard(
            children: [
              _buildRow(
                icon: Icons.memory_rounded,
                title: 'موديل المشترك',
                valueBadge: widget.strip.model,
                onTap: () {},
              ),
              Divider(height: 1, color: widget.isDark ? AppColors.borderDark : AppColors.borderLight),
              _buildRow(
                icon: Icons.tag_rounded,
                title: 'عنوان MAC المشترك',
                valueBadge: widget.strip.macAddress,
                onTap: () {},
              ),
              Divider(height: 1, color: widget.isDark ? AppColors.borderDark : AppColors.borderLight),
              _buildRow(
                icon: Icons.system_update_rounded,
                title: 'إصدار الفيرموير (OTA)',
                valueBadge: 'v${widget.strip.fwVersion}',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: widget.isDark ? AppColors.honeyYellow : const Color(0xFFD97706),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final cardBg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
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
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

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
                  style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800, color: textPrimary),
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

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.honeyYellow),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800, color: textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: value,
            activeColor: AppColors.honeyYellow,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

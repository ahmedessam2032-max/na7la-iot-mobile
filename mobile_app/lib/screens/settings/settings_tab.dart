import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/security/biometric_service.dart';
import '../../core/localization/app_locale.dart';
import '../../data/models/strip_model.dart';
import '../../data/repositories/strip_repository.dart';
import '../../widgets/pin_biometric_dialog.dart';

class SettingsTab extends StatefulWidget {
  final StripModel strip;
  final bool isDark;
  final bool isAdmin;
  final VoidCallback onOpenProtection;
  final VoidCallback onOpenFamily;
  final VoidCallback onOpenAdminConsole;
  final VoidCallback? onToggleTheme;

  const SettingsTab({
    super.key,
    required this.strip,
    required this.isDark,
    this.isAdmin = false,
    required this.onOpenProtection,
    required this.onOpenFamily,
    required this.onOpenAdminConsole,
    this.onToggleTheme,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final StripRepository _repo = StripRepository();
  double _tariffPrice = 1.45;
  String _tariffMode = 'egyptian_tiers'; // egyptian_tiers | flat
  bool _hasPin = false;
  bool _appLockEnabled = false;

  // Notification preferences persisted to backend
  Map<String, bool> _notifPrefs = {
    'offline': true,
    'voltage': true,
    'watt_limit': true,
    'schedule': true,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final price = await SecureStorageService.getTariffPrice();
    final hasPin = await BiometricService.hasPin();
    final appLock = await SecureStorageService.isAppLockEnabled();
    final user = await _repo.getAuthStatus();
    if (mounted) {
      setState(() {
        _tariffPrice = user?.electricityRateEgp ?? price;
        _tariffMode = user?.tariffMode ?? 'egyptian_tiers';
        if (user != null && user.notifPrefs.isNotEmpty) {
          user.notifPrefs.forEach((k, v) {
            _notifPrefs[k] = v == true;
          });
        }
        _hasPin = hasPin;
        _appLockEnabled = appLock;
      });
    }
  }

  Future<void> _updateNotifPref(String key, bool val) async {
    setState(() => _notifPrefs[key] = val);
    await _repo.updateUserPreferences({'notif_prefs': _notifPrefs});
  }

  Future<void> _toggleAppLock(bool value) async {
    final success = await BiometricService.authenticateBiometric(
      reason: value
          ? 'أكّد هويتك بالبصمة أو رمز الجهاز لتفعيل قفل التطبيق'
          : 'أكّد هويتك بالبصمة أو رمز الجهاز لإلغاء قفل التطبيق',
    );
    if (success) {
      await SecureStorageService.setAppLockEnabled(value);
      setState(() => _appLockEnabled = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'سيُطلب فتح التطبيق بالبصمة من الآن 🔐' : 'تم إلغاء قفل التطبيق 🔓'),
          ),
        );
      }
    }
  }

  void _openTariffDialog() {
    final controller = TextEditingController(text: _tariffPrice.toStringAsFixed(2));
    String selectedMode = _tariffMode;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'نظام تسعيرة الكهرباء ⚡',
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'egyptian_tiers',
                groupValue: selectedMode,
                activeColor: AppColors.emeraldPrimary,
                title: Text(
                  'الشرائح المصرية (7 شرائح تصاعدية)',
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'حساب تلقائي حسب شرائح وزارة الكهرباء المصرية (0.68 ~ 2.23 ج.م)',
                  style: GoogleFonts.cairo(fontSize: 10),
                ),
                onChanged: (v) => setDialogState(() => selectedMode = v!),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'flat',
                groupValue: selectedMode,
                activeColor: AppColors.emeraldPrimary,
                title: Text(
                  'سعر ثابت للكيلوواط (Flat Rate)',
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                onChanged: (v) => setDialogState(() => selectedMode = v!),
              ),
              if (selectedMode == 'flat') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    suffixText: 'ج.م / kWh',
                    filled: true,
                    fillColor: widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
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
                final newP = double.tryParse(controller.text.trim()) ?? 1.45;
                await SecureStorageService.saveTariffPrice(newP);
                await _repo.updateUserPreferences({
                  'tariff_mode': selectedMode,
                  'electricity_rate_egp': newP,
                });
                if (mounted) {
                  setState(() {
                    _tariffPrice = newP;
                    _tariffMode = selectedMode;
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('حفظ التسعيرة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _openPinSetupDialog() {
    if (!_hasPin) {
      showDialog(
        context: context,
        builder: (_) => PinBiometricDialog(
          title: 'إعداد رمز PIN الماستر',
          isDark: widget.isDark,
          onSuccess: () {
            _loadSettings();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تفعيل رمز الحماية والبصمة بنجاح 🛡️'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final cardBg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
          final titleColor = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
          final subtitleColor = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
          final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: borderColor, width: 1.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'إدارة رمز PIN الماستر والحماية',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppColors.emeraldPrimary, size: 22),
                  ),
                  title: Text('تغيير رمز PIN الماستر', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor)),
                  subtitle: Text('تعيين رمز حماية جديد مكون من 4 أرقام', style: GoogleFonts.cairo(fontSize: 10, color: subtitleColor)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => PinBiometricDialog(
                        title: 'تغيير رمز PIN الماستر',
                        isDark: widget.isDark,
                        onSuccess: () {
                          _loadSettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تحديث رمز الحماية بنجاح 🛡️'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_open_rounded, color: Colors.redAccent, size: 22),
                  ),
                  title: Text('إلغاء قفل الفيش نهائياً', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.redAccent)),
                  subtitle: Text('إيقاف الحماية وإلغاء قفل جميع المخارج', style: GoogleFonts.cairo(fontSize: 10, color: subtitleColor)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => PinBiometricDialog(
                        title: 'تأكيد الهوية لإلغاء القفل',
                        isDark: widget.isDark,
                        onSuccessWithPin: (pin) async {
                          await SecureStorageService.savePin('');
                          for (final s in widget.strip.sockets) {
                            if (s.isLocked) {
                              s.isLocked = false;
                              try {
                                await _repo.lockSocket(widget.strip.macAddress, s.socketIndex, false, pin: pin);
                              } catch (_) {}
                            }
                          }
                          await _loadSettings();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إلغاء قفل الفيش وإيقاف الرمز بنجاح 🔓'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        onSuccess: () {},
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocaleController.instance,
      builder: (context, _) {
        final locale = AppLocaleController.instance;
        final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Appearance & Language
              _buildSectionHeader(locale.tr('settings_sec_appearance')),
              _buildCard(
                children: [
                  _buildSwitchRow(
                    icon: widget.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    title: locale.isArabic ? 'المظهر الداكن (Dark Mode)' : 'Dark Mode',
                    subtitle: locale.isArabic ? 'التبديل بين الوضع الفاتح والداكن' : 'Toggle Light / Dark theme',
                    value: widget.isDark,
                    onChanged: (_) => widget.onToggleTheme?.call(),
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildRow(
                    icon: Icons.language_rounded,
                    title: locale.tr('settings_app_language'),
                    valueBadge: locale.isArabic ? 'العربية 🇪🇬' : 'English 🇬🇧',
                    onTap: () => locale.toggleLanguage(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 2: Notifications (WattQ 1.0.27 Parity)
              _buildSectionHeader(locale.isArabic ? 'التنبيهات والإشعارات الذكية 🔔' : 'Smart Notifications 🔔'),
              _buildCard(
                children: [
                  _buildSwitchRow(
                    icon: Icons.wifi_off_rounded,
                    title: locale.isArabic ? 'انقطاع وعودة اتصال المشترك' : 'Strip Offline / Online Alerts',
                    subtitle: locale.isArabic ? 'إشعار فوري عند انقطاع الكهرباء أو الواي فاي' : 'Notify when strip disconnects or reconnects',
                    value: _notifPrefs['offline'] ?? true,
                    onChanged: (v) => _updateNotifPref('offline', v),
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildSwitchRow(
                    icon: Icons.shield_outlined,
                    title: locale.isArabic ? 'تنبيهات فصل الجهد والحماية' : 'Voltage Protection Alerts',
                    subtitle: locale.isArabic ? 'إشعار عند فصل المخارج بسبب ارتفاع أو انخفاض الفولت' : 'Notify on voltage cutoff events',
                    value: _notifPrefs['voltage'] ?? true,
                    onChanged: (v) => _updateNotifPref('voltage', v),
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildSwitchRow(
                    icon: Icons.bolt_rounded,
                    title: locale.isArabic ? 'تجاوز حدود استهلاك الواط' : 'High Wattage Alerts',
                    subtitle: locale.isArabic ? 'إشعار عند تخطي المخرج لحد التنبيه أو الفصل' : 'Notify when socket exceeds watt limit',
                    value: _notifPrefs['watt_limit'] ?? true,
                    onChanged: (v) => _updateNotifPref('watt_limit', v),
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildSwitchRow(
                    icon: Icons.schedule_rounded,
                    title: locale.isArabic ? 'تنفيذ الجداول والمؤقتات' : 'Schedule Execution Alerts',
                    subtitle: locale.isArabic ? 'إشعار عند تشغيل أو إيقاف الفيش عبر الجدول' : 'Notify when scheduled timers trigger',
                    value: _notifPrefs['schedule'] ?? true,
                    onChanged: (v) => _updateNotifPref('schedule', v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 3: Security, Protection & Tariff
              _buildSectionHeader(locale.tr('settings_sec_security')),
              _buildCard(
                children: [
                  _buildRow(
                    icon: Icons.shield_outlined,
                    title: locale.tr('settings_voltage_protection'),
                    valueBadge: '${widget.strip.minVoltage.toInt()}V - ${widget.strip.maxVoltage.toInt()}V',
                    onTap: widget.onOpenProtection,
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildRow(
                    icon: Icons.electric_bolt_outlined,
                    title: locale.tr('settings_tariff_price'),
                    valueBadge: _tariffMode == 'egyptian_tiers'
                        ? (locale.isArabic ? '7 شرائح مصرية' : '7 Egyptian Tiers')
                        : '${_tariffPrice.toStringAsFixed(2)} ${locale.tr('egp')}',
                    onTap: _openTariffDialog,
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildRow(
                    icon: Icons.lock_outline_rounded,
                    title: locale.tr('settings_master_pin'),
                    valueBadge: _hasPin ? locale.tr('settings_pin_active') : locale.tr('settings_pin_inactive'),
                    onTap: _openPinSetupDialog,
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildSwitchRow(
                    icon: Icons.fingerprint_rounded,
                    title: locale.tr('settings_biometric_lock'),
                    subtitle: locale.tr('settings_biometric_sub'),
                    value: _appLockEnabled,
                    onChanged: _toggleAppLock,
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildRow(
                    icon: Icons.people_outline_rounded,
                    title: locale.tr('settings_family_sharing'),
                    valueBadge: locale.isArabic ? 'إدارة العائلة' : 'Family',
                    onTap: widget.onOpenFamily,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 4: Admin Console
              if (widget.isAdmin) ...[
                _buildSectionHeader(locale.tr('settings_admin_portal')),
                _buildCard(
                  children: [
                    _buildRow(
                      icon: Icons.admin_panel_settings_outlined,
                      title: locale.tr('settings_admin_portal'),
                      valueBadge: '👑 Console',
                      onTap: widget.onOpenAdminConsole,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Section 5: Device & System Info
              _buildSectionHeader(locale.tr('settings_sec_system')),
              _buildCard(
                children: [
                  _buildRow(
                    icon: Icons.memory_rounded,
                    title: locale.tr('settings_strip_model'),
                    valueBadge: widget.strip.model,
                    onTap: () {},
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildRow(
                    icon: Icons.tag_rounded,
                    title: locale.tr('settings_mac_address'),
                    valueBadge: widget.strip.macAddress,
                    onTap: () {},
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildRow(
                    icon: Icons.system_update_rounded,
                    title: locale.tr('settings_fw_version'),
                    valueBadge: 'v${widget.strip.fwVersion}',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Developer Credit & Quranic Verse Card (Eng. Ahmed Essam)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.emeraldPrimary.withOpacity(0.4), width: 1.2),
                ),
                child: Column(
                  children: [
                    Text(
                      '﴿ إِنَّ اللَّهَ وَمَلَائِكَتَهُ يُصَلُّونَ عَلَى النَّبِيِّ ۚ يَا أَيُّهَا الَّذِينَ آمَنُوا صَلُّوا عَلَيْهِ وَسَلِّمُوا تَسْلِيمًا ﴾',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldPrimary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 10),
                    Text(
                      'Made with ❤️ by Eng. Ahmed Essam',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: widget.isDark ? Colors.white : AppColors.inkBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            launchUrl(
                              Uri.parse('https://wa.me/201152843472'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: AppColors.emeraldPrimary),
                          label: Text(
                            'واتساب الدعم',
                            style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.emeraldPrimary),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            launchUrl(
                              Uri.parse('https://www.linkedin.com/in/ahmed-essam32'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.work_outline_rounded, size: 15, color: Color(0xFF0A66C2)),
                          label: Text(
                            'LinkedIn',
                            style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF0A66C2)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0A66C2)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
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
          color: AppColors.emeraldPrimary,
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
                Icon(icon, size: 18, color: AppColors.emeraldPrimary),
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
                color: AppColors.emeraldPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueBadge,
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
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.emeraldPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
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
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.emeraldPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

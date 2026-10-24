import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/services/lan_controller_service.dart';

class ControllerModeDialog extends StatefulWidget {
  final bool isDark;
  final String mac;

  const ControllerModeDialog({
    super.key,
    required this.isDark,
    required this.mac,
  });

  @override
  State<ControllerModeDialog> createState() => _ControllerModeDialogState();
}

class _ControllerModeDialogState extends State<ControllerModeDialog> {
  final _lanService = LanControllerService();
  bool _isLocalRunning = false;

  @override
  void initState() {
    super.initState();
    _isLocalRunning = _lanService.isRunning;
  }

  Future<void> _toggleLocalMode(bool enable) async {
    if (enable) {
      final ok = await _lanService.startLocalHub();
      setState(() => _isLocalRunning = ok);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? trBi('🏠 تم تشغيل الخادم المحلي على منفذ 10086 بنجاح', '🏠 Local TCP hub started on port 10086')
                  : trBi('❌ تعذر فتح المنفذ المحلي 10086 على الهاتف', '❌ Could not bind local port 10086 on device'),
            ),
            backgroundColor: ok ? AppColors.emeraldActive : Colors.redAccent,
          ),
        );
      }
    } else {
      _lanService.dispose();
      setState(() => _isLocalRunning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trBi('🌐 تم الرجوع للوضع السحابي الافتراضي', '🌐 Switched back to default Cloud Mode')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final borderCol = widget.isDark ? AppColors.borderDark : AppColors.borderLight;
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Directionality(
      textDirection: AppLocaleController.instance.textDirection,
      child: AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: borderCol, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emeraldActive.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.router_rounded, color: AppColors.emeraldActive, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trBi('نمط الاتصال بالمشترك', 'Strip Connection Mode'),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15, color: textPrimary),
                  ),
                  Text(
                    trBi('سحابي أو محلي بدون إنترنت', 'Cloud or Offline LAN Mode'),
                    style: GoogleFonts.cairo(fontSize: 10.5, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                trBi(
                  'يمكنك الاختيار بين التحكم عبر سحابة نحلة العالمية أو التحكم المباشر داخل شبكة الواي فاي المنزلية بدون إنترنت.',
                  'Choose between controlling via Na7la Cloud anywhere or direct local LAN control inside your home Wi-Fi.',
                ),
                style: GoogleFonts.cairo(fontSize: 11.5, height: 1.4, color: textSecondary),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: !_isLocalRunning
                      ? AppColors.emeraldActive.withOpacity(0.12)
                      : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: !_isLocalRunning ? AppColors.emeraldActive : borderCol,
                    width: !_isLocalRunning ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<bool>(
                      value: false,
                      groupValue: _isLocalRunning,
                      activeColor: AppColors.emeraldActive,
                      onChanged: (val) => _toggleLocalMode(false),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trBi('🌐 الوضع السحابي (Cloud Mode)', '🌐 Cloud Mode (AWS)'),
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: textPrimary),
                          ),
                          Text(
                            trBi('سيرفر AWS (13.61.25.9) - تحكم من أي مكان بالخارج', 'AWS Cloud (13.61.25.9) - Control from anywhere'),
                            style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isLocalRunning
                      ? AppColors.routerCyan.withOpacity(0.12)
                      : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isLocalRunning ? AppColors.routerCyan : borderCol,
                    width: _isLocalRunning ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: _isLocalRunning,
                      activeColor: AppColors.routerCyan,
                      onChanged: (val) => _toggleLocalMode(true),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trBi('🏠 الوضع المحلي (Offline LAN Mode)', '🏠 Offline LAN Mode'),
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: textPrimary),
                          ),
                          Text(
                            trBi('خادم TCP مدمج بالهاتف - استجابة فورية دون إنترنت', 'Built-in phone TCP server - instant offline response'),
                            style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_isLocalRunning) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldActive.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emeraldActive),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_tethering_rounded, size: 18, color: AppColors.emeraldActive),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lanService.hasConnectedStrip
                              ? trBi('المشترك متصل مباشرة بالهاتف محلياً ⚡', 'Strip is connected directly to your phone ⚡')
                              : trBi('الخادم المحلي يستمع على 10086 بانتظار اتصال المشترك...', 'Local hub listening on 10086 waiting for strip...'),
                          style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(trBi('إغلاق', 'Close'), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: AppColors.emeraldActive)),
          ),
        ],
      ),
    );
  }
}

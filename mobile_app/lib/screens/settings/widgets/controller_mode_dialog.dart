import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
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
            content: Text(ok
                ? '🏠 تم تشغيل الخادم المحلي على منفذ 10086 بنجاح'
                : '❌ تعذر فتح المنفذ المحلي 10086 على الهاتف'),
            backgroundColor: ok ? AppColors.honeyAmber : Colors.redAccent,
          ),
        );
      }
    } else {
      _lanService.dispose();
      setState(() => _isLocalRunning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🌐 تم الرجوع للوضع السحابي الافتراضي')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack, width: 2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.honeyYellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.router_rounded, color: AppColors.honeyYellow, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نمط الاتصال بالمشترك',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                Text(
                  'Controller Target Mode',
                  style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey),
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
              'يمكنك الاختيار بين التحكم عبر سحابة نحلة العالمية أو التحكم المباشر داخل شبكة الواي فاي المنزلية بدون إنترنت.',
              style: GoogleFonts.cairo(fontSize: 11.5, height: 1.4, color: widget.isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),

            // Mode 1: Cloud Mode
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !_isLocalRunning ? AppColors.honeyYellow.withOpacity(0.12) : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: !_isLocalRunning ? AppColors.honeyYellow : (widget.isDark ? Colors.white12 : Colors.black12),
                  width: !_isLocalRunning ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: _isLocalRunning,
                    activeColor: AppColors.honeyYellow,
                    onChanged: (val) => _toggleLocalMode(false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🌐 الوضع السحابي (Cloud Mode)', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900)),
                        Text('سيرفر AWS (13.61.25.9) - تحكم من أي مكان بالخارج', style: GoogleFonts.cairo(fontSize: 9.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Mode 2: Local LAN Mode
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isLocalRunning ? AppColors.routerCyan.withOpacity(0.12) : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isLocalRunning ? AppColors.routerCyan : (widget.isDark ? Colors.white12 : Colors.black12),
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
                        Text('🏠 الوضع المحلي (Offline LAN Mode)', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900)),
                        Text('خادم TCP مدمج بالهاتف - استجابة فورية دون إنترنت', style: GoogleFonts.cairo(fontSize: 9.5, color: Colors.grey)),
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
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_tethering_rounded, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lanService.hasConnectedStrip
                            ? 'المشترك متصل مباشرة بالهاتف محلياً ⚡'
                            : 'الخادم المحلي يستمع على 10086 بانتظار اتصال المشترك...',
                        style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700),
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
          child: Text('إغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

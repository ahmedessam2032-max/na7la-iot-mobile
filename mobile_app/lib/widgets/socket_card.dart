import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/localization/app_locale.dart';
import '../core/theme/app_theme.dart';
import '../data/models/socket_model.dart';

class SocketCard extends StatelessWidget {
  final SocketModel socket;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;
  final VoidCallback? onOpenDeepDive;
  final VoidCallback? onLockToggle;
  final bool isCompact;
  final bool? isDark;
  final double? voltage;

  const SocketCard({
    super.key,
    required this.socket,
    required this.onToggle,
    this.onLongPress,
    this.onOpenDeepDive,
    this.onLockToggle,
    this.isCompact = true,
    this.isDark,
    this.voltage,
  });

  IconData _resolveIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'router':
      case 'wifi':
        return Icons.router_rounded;
      case 'tv':
      case 'monitor':
        return Icons.tv_rounded;
      case 'ac_unit':
      case 'fridge':
      case 'kitchen':
        return Icons.kitchen_rounded;
      case 'computer':
      case 'pc':
        return Icons.computer_rounded;
      case 'phone_android':
      case 'charger':
        return Icons.charging_station_rounded;
      case 'water_drop':
      case 'heater':
        return Icons.water_drop_rounded;
      default:
        return Icons.power_rounded;
    }
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00:00';
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final bool isOn = socket.isOn;
    final Color activeBase = AppColors.parseHexColor(
      socket.colorHex,
      fallback: AppColors.emeraldActive,
    );
    final Color activeDarker = HSLColor.fromColor(activeBase)
        .withLightness((HSLColor.fromColor(activeBase).lightness - 0.08).clamp(0.15, 0.85))
        .toColor();

    final Color textPrimary = dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color textSecondary = dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final Color cardBg = dark ? AppColors.cardMutedDark : Colors.white;
    final Color borderColor = isOn
        ? activeBase.withOpacity(dark ? 0.85 : 0.75)
        : (dark ? AppColors.borderDark : AppColors.borderLight);

    final menuCallback = onOpenDeepDive ?? onLongPress;

    final int timerSec = socket.autoOffDelaySec ?? 0;
    final bool hasActiveTimer = timerSec > 0 || socket.doorbellMode;
    final String timerDisplay = socket.doorbellMode
        ? '🔔 ${socket.doorbellPulseSec}s'
        : _formatDuration(timerSec);

    final double tempVal = (socket.tempC ?? 28).toDouble();
    final bool isHot = tempVal >= 55;

    return GestureDetector(
      onTap: menuCallback,
      onLongPress: menuCallback,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: isOn ? 1.6 : 1.1,
          ),
          boxShadow: [
            if (isOn)
              BoxShadow(
                color: activeBase.withOpacity(dark ? 0.22 : 0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.18 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. Header: Circular Appliance Icon + Outlet Name + Status/Lock/Menu Icons
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isOn
                        ? LinearGradient(
                            colors: [activeBase, activeDarker],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isOn
                        ? null
                        : (dark ? Colors.white.withOpacity(0.07) : const Color(0xFFF1F5F9)),
                  ),
                  child: Icon(
                    _resolveIcon(socket.icon),
                    size: 16,
                    color: isOn ? Colors.white : textSecondary,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    trOutletName(socket.name, socket.index),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      height: 1.15,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (socket.isRouter)
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Text('🌐', style: TextStyle(fontSize: 10)),
                      ),
                    if (socket.compressorProtect)
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Text('❄️', style: TextStyle(fontSize: 10)),
                      ),
                    if (socket.isPinnedState)
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Text('📌', style: TextStyle(fontSize: 10)),
                      ),
                    if (socket.linkGroup > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Text(
                          '🔗${socket.linkGroup}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: onLockToggle ?? menuCallback,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        decoration: socket.isLocked
                            ? BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.16),
                                borderRadius: BorderRadius.circular(7),
                              )
                            : null,
                        child: Icon(
                          socket.isLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 14,
                          color: socket.isLocked
                              ? const Color(0xFFF59E0B)
                              : textSecondary.withOpacity(0.65),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: menuCallback,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.more_vert_rounded,
                          size: 16,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 2. Thin Divider
            Divider(
              height: 8,
              thickness: 0.8,
              color: dark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            ),

            // 3. Five Structured Smart-Meter Telemetry Rows
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMetricRow(
                    label: trBi('القدرة:', 'Power:'),
                    value: '${socket.watt.toStringAsFixed(1)} W',
                    labelColor: textSecondary,
                    valueColor: isOn && socket.watt > 0 ? activeBase : textPrimary,
                    isBoldValue: true,
                  ),
                  _buildMetricRow(
                    label: trBi('العداد:', 'Meter:'),
                    value: '${socket.kwh.toStringAsFixed(3)} kWh',
                    labelColor: textSecondary,
                    valueColor: textPrimary,
                  ),
                  _buildMetricRow(
                    label: trBi('التيار:', 'Current:'),
                    value: '${socket.amp.toStringAsFixed(2)} A',
                    labelColor: textSecondary,
                    valueColor: textPrimary,
                  ),
                  _buildMetricRow(
                    label: trBi('الحرارة:', 'Temp:'),
                    value: '${tempVal.toStringAsFixed(1)} °C',
                    labelColor: textSecondary,
                    valueColor: isHot ? Colors.redAccent : textPrimary,
                    isBoldValue: isHot,
                  ),
                  _buildTimerRow(
                    label: trBi('المؤقت:', 'Timer:'),
                    value: timerDisplay,
                    hasActiveTimer: hasActiveTimer,
                    activeBase: activeBase,
                    labelColor: textSecondary,
                    valueColor: textSecondary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            // 4. Dedicated Bottom ON / OFF Pill Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isOn
                        ? LinearGradient(
                            colors: [activeBase, activeDarker],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: isOn
                        ? null
                        : (dark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.power_settings_new_rounded,
                        size: 14,
                        color: isOn ? Colors.white : textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOn
                            ? trBi('تشغيل • ON', 'ON')
                            : trBi('إيقاف • OFF', 'OFF'),
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: isOn ? Colors.white : textSecondary,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required Color labelColor,
    required Color valueColor,
    bool isBoldValue = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: labelColor,
            height: 1.1,
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: isBoldValue ? FontWeight.w800 : FontWeight.w700,
              color: valueColor,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerRow({
    required String label,
    required String value,
    required bool hasActiveTimer,
    required Color activeBase,
    required Color labelColor,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: labelColor,
            height: 1.1,
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            padding: hasActiveTimer
                ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
                : EdgeInsets.zero,
            decoration: hasActiveTimer
                ? BoxDecoration(
                    color: activeBase.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(5),
                  )
                : null,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: hasActiveTimer ? FontWeight.w800 : FontWeight.w600,
                color: hasActiveTimer ? activeBase : valueColor,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

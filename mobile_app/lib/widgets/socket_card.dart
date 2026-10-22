import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../data/models/socket_model.dart';

class SocketCard extends StatelessWidget {
  final SocketModel socket;
  final bool isDark;
  final double voltage;
  final VoidCallback onToggle;
  final VoidCallback onOpenDeepDive;

  const SocketCard({
    super.key,
    required this.socket,
    required this.isDark,
    this.voltage = 228.0,
    required this.onToggle,
    required this.onOpenDeepDive,
  });

  IconData _getSocketIcon(String iconName) {
    if (socket.isRouter) return Icons.router_rounded;
    switch (iconName.toLowerCase()) {
      case 'fridge':
      case 'refrigerator':
      case 'kitchen':
      case 'snowflake':
        return Icons.kitchen_rounded;
      case 'router':
      case 'wifi':
        return Icons.router_rounded;
      case 'ac':
      case 'air_conditioner':
      case 'wind':
        return Icons.ac_unit_rounded;
      case 'tv':
      case 'screen':
        return Icons.tv_rounded;
      case 'charger':
      case 'smartphone':
      case 'phone':
        return Icons.smartphone_rounded;
      case 'heater':
      case 'water_heater':
        return Icons.water_damage_rounded;
      case 'computer':
      case 'pc':
      case 'laptop':
        return Icons.computer_rounded;
      case 'lamp':
      case 'light':
        return Icons.lightbulb_rounded;
      default:
        return Icons.power_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOn = socket.state;

    // Theme-driven styling (Ceramic White in Light, Midnight Obsidian in Dark)
    final Color cardBg;
    final Color borderColor;
    final List<BoxShadow> shadows;

    if (isOn) {
      if (isDark) {
        cardBg = const Color(0xFF172033);
        borderColor = AppColors.honeyYellow;
        shadows = [
          BoxShadow(
            color: AppColors.honeyYellow.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ];
      } else {
        cardBg = const Color(0xFFFFFBEB); // Warm Ivory
        borderColor = AppColors.honeyYellow;
        shadows = [
          BoxShadow(
            color: AppColors.honeyYellow.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
      }
    } else {
      if (isDark) {
        cardBg = AppColors.cardSurfaceDark;
        borderColor = AppColors.borderDark;
        shadows = [
          const BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ];
      } else {
        cardBg = AppColors.cardSurfaceLight;
        borderColor = AppColors.borderLight;
        shadows = [
          const BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ];
      }
    }

    final Color textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final Color accentColor = isOn ? AppColors.honeyYellow : textSecondary;

    final int displayTemp = socket.currentTempC > 0 ? socket.currentTempC : 28;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isOn ? 1.5 : 1.2),
          boxShadow: shadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: 3-Dots Menu & Voltage Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Action Menu (3-dots)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpenDeepDive,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 16,
                      color: textSecondary,
                    ),
                  ),
                ),

                // Voltage / Router Badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (socket.isRouter) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.routerCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.routerCyan.withOpacity(0.4), width: 0.8),
                        ),
                        child: Text(
                          'راوتر 🛡️',
                          style: GoogleFonts.cairo(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.routerCyan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOn ? '${voltage.toStringAsFixed(0)}V' : '0V',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOn ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)) : textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Center Content: Device Vector Icon & Socket Name
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOn
                              ? AppColors.honeyYellow.withOpacity(isDark ? 0.2 : 0.15)
                              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                        ),
                        child: Icon(
                          _getSocketIcon(socket.icon),
                          size: 22,
                          color: isOn ? AppColors.honeyYellow : textSecondary,
                        ),
                      ),
                      if (socket.isLocked)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded, size: 9, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    socket.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Row: Live Wattage & Temperature Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Live Wattage
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOn ? socket.currentWatt.toStringAsFixed(1) : '0.0',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isOn ? accentColor : textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'W',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),

                // Temperature + Socket Index Badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.thermostat_rounded,
                      size: 11,
                      color: displayTemp > 45 ? Colors.redAccent : textSecondary,
                    ),
                    Text(
                      '$displayTemp°',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: displayTemp > 45 ? Colors.redAccent : textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${socket.socketIndex}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

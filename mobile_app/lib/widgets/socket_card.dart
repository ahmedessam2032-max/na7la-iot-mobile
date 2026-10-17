import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../data/models/socket_model.dart';

class SocketCard extends StatelessWidget {
  final SocketModel socket;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onOpenDeepDive;

  const SocketCard({
    super.key,
    required this.socket,
    required this.isDark,
    required this.onToggle,
    required this.onOpenDeepDive,
  });

  IconData _resolveIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'router':
      case 'wifi':
        return Icons.router_rounded;
      case 'fridge':
      case 'snowflake':
        return Icons.ac_unit_rounded;
      case 'ac':
      case 'air_conditioner':
      case 'wind':
        return Icons.air_rounded;
      case 'phone':
      case 'smartphone':
      case 'charger':
        return Icons.battery_charging_full_rounded;
      case 'tv':
      case 'screen':
        return Icons.tv_rounded;
      case 'heater':
      case 'fire':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.power_rounded;
    }
  }

  String _resolveTag() {
    if (socket.isLocked) return '🔒 مقفول بـ PIN';
    if (socket.isRouter) return '🛡️ محمي ضد الفصل';
    if (socket.compressorProtect) return '❄️ حماية كمبريسور';
    if (socket.minWattCutoff != null) return '🔋 فصل شاحن ذكي';
    return socket.state ? '⚡ يعمل حالياً' : '🛑 متوقف';
  }

  @override
  Widget build(BuildContext context) {
    Color cardBg;
    if (socket.state) {
      if (socket.isRouter) {
        cardBg = isDark ? AppColors.routerBgDark : AppColors.routerBgLight;
      } else {
        cardBg = isDark ? AppColors.cardActiveDark : AppColors.honeyAmber;
      }
    } else {
      cardBg = isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight;
    }

    return Container(
      height: 154,
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.inkCardDecoration(
        isDark: isDark,
        surfaceColor: cardBg,
        radius: 20,
        shadowOffset: 3.5,
        borderColor: socket.state && socket.isRouter
            ? AppColors.routerCyan
            : (socket.state ? AppColors.honeyAmber : null),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Socket Icon & Settings Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: socket.state
                      ? (socket.isRouter ? AppColors.routerCyan : AppColors.inkBlack)
                      : (isDark ? AppColors.cardSurfaceDark : Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.inkBlack,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _resolveIcon(socket.icon),
                  size: 18,
                  color: socket.state
                      ? (socket.isRouter ? Colors.black : AppColors.honeyYellow)
                      : (isDark ? Colors.white70 : AppColors.inkBlack),
                ),
              ),
              Row(
                children: [
                  if (socket.isLocked)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                    ),
                  GestureDetector(
                    onTap: onOpenDeepDive,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        size: 16,
                        color: isDark ? Colors.white70 : AppColors.inkBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Middle: Socket Name & Tag
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      socket.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.inkBlack,
                      ),
                    ),
                  ),
                  Text(
                    '#${socket.socketIndex}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.inkBlack,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _resolveTag(),
                  style: GoogleFonts.cairo(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.honeyYellow,
                  ),
                ),
              ),
            ],
          ),

          // Bottom Row: Live Watts & Power Switch
          Container(
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    text: socket.state ? socket.currentWatt.toStringAsFixed(0) : '0',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.inkBlack,
                    ),
                    children: [
                      TextSpan(
                        text: ' W',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.honeyAmber,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 44,
                    height: 24,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: socket.state
                          ? AppColors.inkBlack
                          : (isDark ? Colors.white24 : Colors.black26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.inkBlack,
                        width: 1.5,
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: socket.state ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: socket.state
                              ? (socket.isRouter ? AppColors.routerCyan : AppColors.honeyYellow)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

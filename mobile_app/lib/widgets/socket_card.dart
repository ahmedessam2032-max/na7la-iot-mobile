import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../data/models/socket_model.dart';

class SocketCard extends StatelessWidget {
  final SocketModel socket;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final VoidCallback? onLockToggle;
  final bool isCompact;
  final bool? isDark;

  const SocketCard({
    super.key,
    required this.socket,
    required this.onToggle,
    required this.onLongPress,
    this.onLockToggle,
    this.isCompact = true,
    this.isDark,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isOn = socket.isOn;
    final Color activeBase = AppColors.parseHexColor(socket.colorHex, fallback: AppColors.emeraldActive);
    final Color activeDarker = HSLColor.fromColor(activeBase)
        .withLightness((HSLColor.fromColor(activeBase).lightness - 0.08).clamp(0.15, 0.85))
        .toColor();

    final Color fgPrimary = isOn
        ? Colors.white
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final Color fgSecondary = isOn
        ? Colors.white.withOpacity(0.92)
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return GestureDetector(
      onTap: onToggle,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isOn
              ? LinearGradient(
                  colors: [activeBase, activeDarker],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isOn
              ? null
              : (isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOn
                ? Colors.white.withOpacity(0.18)
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: 1.1,
          ),
          boxShadow: [
            if (isOn)
              BoxShadow(
                color: activeBase.withOpacity(isDark ? 0.32 : 0.26),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Amps + Active Feature Badges (Left in LTR / Right in RTL) & '⋮' Menu Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 3-Dots Outlet Menu Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onLongPress,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isOn
                            ? Colors.black.withOpacity(0.16)
                            : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 17,
                        color: fgPrimary,
                      ),
                    ),
                  ),
                ),

                // Amps + Active Badges (Link group, Doorbell, Pin state, Lock, Compressor)
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (socket.isPinnedState)
                          _buildMiniBadge('📌', isOn, isDark),
                        if (socket.isLocked || socket.isRouter)
                          GestureDetector(
                            onTap: onLockToggle,
                            child: _buildMiniBadge('🔒', isOn, isDark),
                          ),
                        if (socket.doorbellMode)
                          _buildMiniBadge('🔔', isOn, isDark),
                        if (socket.linkGroup > 0)
                          _buildMiniBadge('🔗${socket.linkGroup}', isOn, isDark),
                        if (socket.compressorProtect)
                          _buildMiniBadge('❄️', isOn, isDark),
                        const SizedBox(width: 4),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '${socket.amp.toStringAsFixed(socket.amp > 0 && socket.amp < 0.1 ? 2 : 1)}A',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: fgSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Center: Icon + Bold Socket Name
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _resolveIcon(socket.icon),
                    size: 18,
                    color: fgPrimary.withOpacity(isOn ? 0.95 : 0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      socket.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: fgPrimary,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Row: Watts (⚡ W) & Temperature (🌡️ °C)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: isOn ? Colors.yellowAccent : AppColors.honeyYellow,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${socket.watt.toStringAsFixed(1)} W',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: fgSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.thermostat_rounded,
                        size: 13,
                        color: (socket.tempC ?? 28) >= 55
                            ? Colors.redAccent
                            : fgSecondary.withOpacity(0.85),
                      ),
                      const SizedBox(width: 1),
                      Text(
                        '${socket.tempC ?? 28}°',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: fgSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, bool isOn, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isOn
            ? Colors.black.withOpacity(0.20)
            : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: isOn ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }
}

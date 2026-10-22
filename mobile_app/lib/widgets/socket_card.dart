import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../data/models/socket_model.dart';

/// 1. SocketCard: العرض المدمج 2x2 المتطابق 100% مع واجهة HTML المعتمدة (WattQ / Na7la 2x2)
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
    this.voltage = 225.0,
    required this.onToggle,
    required this.onOpenDeepDive,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOn = socket.state;

    // Styling matching HTML .outlet-box.on and .outlet-box.off
    final BoxDecoration cardDeco = isOn
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7E84A), Color(0xFFF5A31A)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF181818), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(245, 163, 26, 0.38),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          )
        : BoxDecoration(
            color: isDark ? const Color(0xFF29261E) : const Color(0xFFEFE4B0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF443F33) : Colors.black12,
              width: 1.5,
            ),
          );

    final Color textColor = isOn ? const Color(0xFF161510) : (isDark ? const Color(0xFFDDD3BA) : Colors.black87);
    final Color subTextColor = isOn ? const Color(0xFF2C2818) : (isDark ? const Color(0xFF9E967D) : Colors.black54);

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: 3-Dots Menu & Voltage Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpenDeepDive,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isOn ? Colors.black.withOpacity(0.08) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 16,
                      color: textColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isOn ? Colors.black.withOpacity(0.12) : (isDark ? Colors.black26 : Colors.black.withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOn ? '${voltage.toStringAsFixed(0)}V' : '0V',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),

            // Center Row: Lock icon + Socket Name
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (socket.isLocked) ...[
                    Icon(Icons.lock_rounded, size: 13, color: textColor),
                    const SizedBox(width: 4),
                  ] else if (socket.isRouter) ...[
                    Icon(Icons.router_rounded, size: 13, color: textColor),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      socket.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Row: Live Watts + Bolt Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      isOn ? socket.currentWatt.toStringAsFixed(1) : '0.0',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: isOn ? const Color(0xFF161510) : AppColors.honeyAmber,
                    ),
                  ],
                ),
                Text(
                  '#${socket.socketIndex}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. ProSocketCard: كرت المقبس في العرض التفصيلي الكامل (Full Detailed View)
class ProSocketCard extends StatelessWidget {
  final SocketModel socket;
  final bool isDark;
  final double voltage;
  final VoidCallback onToggle;
  final VoidCallback onToggleLock;
  final VoidCallback onOpenDeepDive;

  const ProSocketCard({
    super.key,
    required this.socket,
    required this.isDark,
    this.voltage = 225.0,
    required this.onToggle,
    required this.onToggleLock,
    required this.onOpenDeepDive,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOn = socket.state;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181714) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOn
              ? const Color(0xFF2ECC71).withOpacity(0.4)
              : (isDark ? const Color(0xFF2C2A22) : Colors.black12),
          width: 1.5,
        ),
        boxShadow: isOn
            ? [
                BoxShadow(
                  color: const Color(0xFF2ECC71).withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Lock Button + Title Wrap + Number Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onToggleLock,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: socket.isLocked
                            ? Colors.red.shade900.withOpacity(0.3)
                            : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: socket.isLocked ? Colors.red.shade400 : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        socket.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 14,
                        color: socket.isLocked ? Colors.red.shade300 : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onOpenDeepDive,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        size: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (socket.isRouter) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.routerCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 10, color: AppColors.routerCyan),
                          const SizedBox(width: 4),
                          Text(
                            'راوتر محمي',
                            style: GoogleFonts.cairo(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.routerCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    socket.name,
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.inkBlack,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'مخرج #${socket.socketIndex}',
                      style: GoogleFonts.cairo(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Prominent Power Pill Button
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isOn
                    ? const LinearGradient(
                        colors: [Color(0xFFF5A31A), Color(0xFFF7E84A)],
                      )
                    : null,
                color: isOn ? null : (isDark ? const Color(0xFF1F1E19) : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOn
                      ? const Color(0xFFFFF394)
                      : (isDark ? const Color(0xFF38352A) : Colors.black12),
                  width: 1.5,
                ),
                boxShadow: isOn
                    ? [
                        const BoxShadow(
                          color: Color.fromRGBO(245, 163, 26, 0.45),
                          blurRadius: 18,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.power_settings_new_rounded,
                        size: 18,
                        color: isOn ? const Color(0xFF14130E) : (isDark ? const Color(0xFF9E967D) : Colors.black54),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOn ? '🟢 شغال (اضغط للإطفاء)' : '🔴 مطفأ (اضغط للتشغيل)',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: isOn ? const Color(0xFF14130E) : (isDark ? const Color(0xFF9E967D) : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isOn ? '${voltage.toStringAsFixed(0)}V' : '0V',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: isOn ? const Color(0xFF14130E) : (isDark ? const Color(0xFF9E967D) : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quad Telemetry Matrix (Power, Current, Energy, Temp)
          Row(
            children: [
              _buildTelemetryTile(
                title: '⚡ القدرة',
                value: isOn ? '${socket.currentWatt.toStringAsFixed(1)} W' : '0.0 W',
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildTelemetryTile(
                title: '🔌 التيار',
                value: isOn ? '${socket.currentAmp.toStringAsFixed(2)} A' : '0.00 A',
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildTelemetryTile(
                title: '📊 الطاقة',
                value: '${socket.totalKwh.toStringAsFixed(2)} kWh',
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildTelemetryTile(
                title: '🌡️ الحرارة',
                value: '${socket.currentTempC} °C',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTile({
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1D17) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isDark ? const Color(0xFF2E2B21) : Colors.black12,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.inkBlack,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

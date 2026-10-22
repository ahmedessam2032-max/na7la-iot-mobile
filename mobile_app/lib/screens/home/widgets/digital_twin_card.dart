import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../data/models/strip_model.dart';
import '../../../../data/models/socket_model.dart';
import '../../../../core/theme/app_theme.dart';

class DigitalTwinCard extends StatelessWidget {
  final StripModel strip;
  final bool isDark;
  final Function(SocketModel socket) onToggleSocket;
  final VoidCallback onToggleAll;

  const DigitalTwinCard({
    super.key,
    required this.strip,
    required this.isDark,
    required this.onToggleSocket,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14130F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.honeyYellow.withOpacity(0.35) : AppColors.honeyYellow,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.55) : Colors.amber.withOpacity(0.08),
            offset: const Offset(0, 6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: strip.isOnline ? const Color(0xFF10B981) : Colors.grey,
                      boxShadow: strip.isOnline
                          ? [const BoxShadow(color: Color(0xFF10B981), blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'التوأم الرقمي الحي ⚡ (MTTL-W01)',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.inkBlack,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.honeyAmber.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.honeyAmber.withOpacity(0.4)),
                ),
                child: Text(
                  'تفاعلي مباشر 👆',
                  style: GoogleFonts.cairo(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.honeyAmber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // The Hardware Stage with Aspect Ratio 1024 / 256
          AspectRatio(
            aspectRatio: 1024 / 256,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Strip Photo (Transparent Background)
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/strip_body_transparent.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    // Socket 1 Hotspot & LED
                    _buildSocketHotspot(
                      socketIndex: 1,
                      left: w * 0.035,
                      top: h * 0.06,
                      width: w * 0.15,
                      height: h * 0.88,
                    ),
                    _buildLedDot(
                      socketIndex: 1,
                      centerX: w * 0.105,
                      centerY: h * 0.765,
                    ),

                    // Socket 2 (Router) Hotspot & LED
                    _buildSocketHotspot(
                      socketIndex: 2,
                      left: w * 0.200,
                      top: h * 0.06,
                      width: w * 0.15,
                      height: h * 0.88,
                    ),
                    _buildLedDot(
                      socketIndex: 2,
                      centerX: w * 0.272,
                      centerY: h * 0.765,
                    ),

                    // Socket 3 Hotspot & LED
                    _buildSocketHotspot(
                      socketIndex: 3,
                      left: w * 0.365,
                      top: h * 0.06,
                      width: w * 0.15,
                      height: h * 0.88,
                    ),
                    _buildLedDot(
                      socketIndex: 3,
                      centerX: w * 0.438,
                      centerY: h * 0.765,
                    ),

                    // Socket 4 Hotspot & LED
                    _buildSocketHotspot(
                      socketIndex: 4,
                      left: w * 0.530,
                      top: h * 0.06,
                      width: w * 0.15,
                      height: h * 0.88,
                    ),
                    _buildLedDot(
                      socketIndex: 4,
                      centerX: w * 0.605,
                      centerY: h * 0.765,
                    ),

                    // Master Power Button Hotspot
                    Positioned(
                      left: w * 0.810,
                      top: h * 0.18,
                      width: w * 0.14,
                      height: h * 0.62,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(100),
                          onTap: onToggleAll,
                        ),
                      ),
                    ),

                    // Wi-Fi / Cloud Indicator LED
                    Positioned(
                      left: w * 0.795 - 4.0,
                      top: h * 0.470 - 4.0,
                      width: 8,
                      height: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: strip.isOnline ? const Color(0xFF00F0FF) : const Color(0xFF6B7280),
                          border: Border.all(color: Colors.white, width: 1),
                          boxShadow: strip.isOnline
                              ? [
                                  const BoxShadow(color: Color(0xFF00F0FF), blurRadius: 6, spreadRadius: 1),
                                  const BoxShadow(color: Color(0x9900F0FF), blurRadius: 12, spreadRadius: 2),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Status & Legend Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendItem(const Color(0xFF00E676), 'يعمل'),
                      const SizedBox(width: 10),
                      _buildLegendItem(const Color(0xFFFF1744), 'مطفأ'),
                      const SizedBox(width: 10),
                      _buildLegendItem(const Color(0xFF00F0FF), 'متصل'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '👆 انقر للتبديل',
                    style: GoogleFonts.cairo(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white60 : Colors.black54,
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

  Widget _buildSocketHotspot({
    required int socketIndex,
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final socket = strip.sockets.firstWhere(
      (s) => s.socketIndex == socketIndex,
      orElse: () => strip.sockets[0],
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onToggleSocket(socket),
        ),
      ),
    );
  }

  Widget _buildLedDot({
    required int socketIndex,
    required double centerX,
    required double centerY,
  }) {
    final socket = strip.sockets.firstWhere(
      (s) => s.socketIndex == socketIndex,
      orElse: () => strip.sockets[0],
    );

    final isOn = socket.state;
    final ledColor = isOn ? const Color(0xFF00E676) : const Color(0xFFFF1744);
    final borderColor = isOn ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

    return Positioned(
      left: centerX - 6.5,
      top: centerY - 6.5,
      width: 13,
      height: 13,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ledColor,
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: ledColor,
                blurRadius: isOn ? 10 : 8,
                spreadRadius: isOn ? 2 : 1,
              ),
              BoxShadow(
                color: ledColor.withOpacity(isOn ? 0.7 : 0.5),
                blurRadius: isOn ? 20 : 14,
                spreadRadius: isOn ? 4 : 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 3.5,
              height: 3.5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color, blurRadius: 4, spreadRadius: 1)],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}

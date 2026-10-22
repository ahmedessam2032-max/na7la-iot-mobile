import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/strip_model.dart';
import '../../data/models/socket_model.dart';
import 'widgets/repeating_cycle_sheet.dart';

class SchedulesTab extends StatelessWidget {
  final StripModel strip;
  final bool isDark;
  final Function(SocketModel socket) onOpenScheduleSheet;

  const SchedulesTab({
    super.key,
    required this.strip,
    required this.isDark,
    required this.onOpenScheduleSheet,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4 Matrix Grid (Schedule, Timer, Cycle, Auto-Off) matching HTML #tab-schedules
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF33312B) : Colors.black12,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                _buildSummaryItem(
                  icon: Icons.calendar_month_outlined,
                  count: '1',
                  label: 'جدولة',
                  color: AppColors.honeyYellow,
                ),
                _buildSummaryItem(
                  icon: Icons.timer_outlined,
                  count: '0',
                  label: 'مؤقت',
                  color: AppColors.honeyAmber,
                ),
                _buildSummaryItem(
                  icon: Icons.sync_rounded,
                  count: '0',
                  label: 'دوري',
                  color: AppColors.routerCyan,
                ),
                _buildSummaryItem(
                  icon: Icons.power_settings_new_rounded,
                  count: '1',
                  label: 'إطفاء ذاتي',
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⏰ جداول ومؤقتات المخارج',
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
              ),
              Text(
                'تعمل بالسحابة حتى لو الهاتف مطفأ',
                style: GoogleFonts.cairo(fontSize: 9.5, color: isDark ? Colors.white54 : Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List of Outlets with Schedule status
          ...strip.sockets.map((socket) {
            final hasSchedule = socket.minWattCutoff != null || socket.compressorProtect;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181714) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2B21) : Colors.black12,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: socket.state
                              ? (socket.isRouter ? AppColors.routerCyan.withOpacity(0.2) : AppColors.honeyYellow.withOpacity(0.2))
                              : (isDark ? Colors.white10 : Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: socket.state ? AppColors.honeyYellow : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            socket.name,
                            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            hasSchedule ? 'مجدول تلقائياً (حماية / مؤقت)' : 'لا توجد جدولة مفعلة',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: hasSchedule ? AppColors.honeyYellow : (isDark ? Colors.white54 : Colors.black45),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => RepeatingCycleSheet(
                              mac: strip.macAddress,
                              socket: socket,
                              isDark: isDark,
                              onCycleChanged: () => onOpenScheduleSheet(socket),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.routerCyan,
                          side: const BorderSide(color: AppColors.routerCyan, width: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'دورة 🔄',
                          style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () => onOpenScheduleSheet(socket),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF26241D) : Colors.black.withOpacity(0.06),
                          foregroundColor: AppColors.honeyYellow,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppColors.honeyYellow, width: 1),
                          ),
                        ),
                        child: Text(
                          'ضبط ⚙️',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String count,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            count,
            style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
          ),
        ],
      ),
    );
  }
}

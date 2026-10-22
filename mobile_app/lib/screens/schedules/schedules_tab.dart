import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/strip_model.dart';
import '../../data/models/socket_model.dart';
import '../../data/models/schedule_model.dart';
import '../../data/repositories/strip_repository.dart';

class SchedulesTab extends StatefulWidget {
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
  State<SchedulesTab> createState() => _SchedulesTabState();
}

class _SchedulesTabState extends State<SchedulesTab> {
  final StripRepository _repo = StripRepository();
  bool _isLoading = true;
  List<ScheduleModel> _allSchedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final List<ScheduleModel> loaded = [];
    for (final sock in widget.strip.sockets) {
      try {
        final list = await _repo.getSocketSchedules(widget.strip.macAddress, sock.socketIndex);
        loaded.addAll(list);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _allSchedules = loaded;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSchedule(ScheduleModel sched) async {
    final success = await _repo.toggleSchedule(sched.id);
    if (success) {
      setState(() {
        final idx = _allSchedules.indexWhere((s) => s.id == sched.id);
        if (idx != -1) {
          _allSchedules[idx] = sched.copyWith(isActive: !sched.isActive);
        }
      });
    }
  }

  Future<void> _deleteSchedule(ScheduleModel sched) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
        title: Text('حذف الجدولة', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900)),
        content: Text('هل أنت متأكد من حذف هذه الجدولة نهائياً؟', style: GoogleFonts.cairo(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _repo.deleteSchedule(sched.id);
      if (success) {
        setState(() {
          _allSchedules.removeWhere((x) => x.id == sched.id);
        });
      }
    }
  }

  void _openAddScheduleModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddScheduleSheet(
        strip: widget.strip,
        isDark: widget.isDark,
        onCreated: () => _loadSchedules(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;
    final cardBg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;

    final int timerCount = _allSchedules.where((s) => s.scheduleType == 'TIMER').length;
    final int cycleCount = _allSchedules.where((s) => s.scheduleType == 'CYCLE').length;
    final int cronCount = _allSchedules.where((s) => s.scheduleType == 'CRON').length;
    final int autoOffCount = _allSchedules.where((s) => s.scheduleType == 'AUTO_OFF').length;

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      color: AppColors.honeyYellow,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Summary Matrix
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Row(
                children: [
                  _buildSummaryItem('مؤقت', '$timerCount', Icons.timer_outlined, AppColors.honeyAmber),
                  _buildSummaryItem('دوري', '$cycleCount', Icons.sync_rounded, AppColors.routerCyan),
                  _buildSummaryItem('أسبوعي', '$cronCount', Icons.calendar_month_outlined, AppColors.honeyYellow),
                  _buildSummaryItem('إطفاء دائم', '$autoOffCount', Icons.power_settings_new_rounded, const Color(0xFF10B981)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Header Row + Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جداول ومؤقتات المخارج ⏰',
                      style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: textPrimary),
                    ),
                    Text(
                      'تُنفذ بالسحابة تلقائياً حتى لو كان هاتفك مطفأ',
                      style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _openAddScheduleModal,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    'إضافة جدول',
                    style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.honeyYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.honeyYellow)),
              )
            else if (_allSchedules.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.schedule_rounded, size: 48, color: textSecondary.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد جداول أو مؤقتات نشطة حالياً',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أضف مؤقتاً لإطفاء الشاحن، أو دورة متكررة للثلاجة، أو جدولاً للمكتب',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openAddScheduleModal,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('إنشاء جدول جديد الآن', style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.honeyYellow,
                        side: const BorderSide(color: AppColors.honeyYellow),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_allSchedules.length, (index) {
                final s = _allSchedules[index];
                final sock = widget.strip.sockets.firstWhere(
                  (x) => x.id == s.socketId,
                  orElse: () => SocketModel(id: s.socketId, socketIndex: 1, name: 'مخرج'),
                );

                String typeBadge = 'مؤقت تنازلي';
                IconData typeIcon = Icons.timer_outlined;
                Color typeColor = AppColors.honeyAmber;

                if (s.scheduleType == 'CYCLE') {
                  typeBadge = 'دورة متكررة (${(s.cycleOnSec ?? 0) ~/ 60}د تشغيل / ${(s.cycleOffSec ?? 0) ~/ 60}د إطفاء)';
                  typeIcon = Icons.sync_rounded;
                  typeColor = AppColors.routerCyan;
                } else if (s.scheduleType == 'CRON') {
                  typeBadge = 'جدول أسبوعي (${s.cronExpression ?? ""})';
                  typeIcon = Icons.calendar_month_outlined;
                  typeColor = AppColors.honeyYellow;
                } else if (s.scheduleType == 'AUTO_OFF') {
                  typeBadge = 'إطفاء تلقائي دائم (${(s.autoOffDelaySec ?? 0) ~/ 60}د)';
                  typeIcon = Icons.power_settings_new_rounded;
                  typeColor = const Color(0xFF10B981);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(typeIcon, size: 20, color: typeColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  sock.name,
                                  style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800, color: textPrimary),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#${sock.socketIndex}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w800, color: textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              typeBadge,
                              style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: s.isActive,
                        activeColor: AppColors.honeyYellow,
                        onChanged: (_) => _toggleSchedule(s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        onPressed: () => _deleteSchedule(s),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String count, IconData icon, Color color) {
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            count,
            style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 9.5, fontWeight: FontWeight.w700, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AddScheduleSheet extends StatefulWidget {
  final StripModel strip;
  final bool isDark;
  final VoidCallback onCreated;

  const _AddScheduleSheet({
    required this.strip,
    required this.isDark,
    required this.onCreated,
  });

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  final StripRepository _repo = StripRepository();
  int _selectedSocketIndex = 1;
  String _scheduleType = 'TIMER'; // TIMER / CYCLE / CRON
  int _timerMinutes = 30;
  int _cycleOnMinutes = 20;
  int _cycleOffMinutes = 40;
  bool _targetState = false; // Turn OFF after timer
  bool _isSaving = false;

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    bool ok = false;
    if (_scheduleType == 'TIMER') {
      ok = await _repo.createSchedule(
        mac: widget.strip.macAddress,
        socketIndex: _selectedSocketIndex,
        scheduleType: 'TIMER',
        targetState: _targetState,
        timerDurationSec: _timerMinutes * 60,
      );
    } else if (_scheduleType == 'CYCLE') {
      ok = await _repo.createCycleSchedule(
        mac: widget.strip.macAddress,
        socketIndex: _selectedSocketIndex,
        cycleOnSec: _cycleOnMinutes * 60,
        cycleOffSec: _cycleOffMinutes * 60,
      );
    } else if (_scheduleType == 'CRON') {
      ok = await _repo.createSchedule(
        mac: widget.strip.macAddress,
        socketIndex: _selectedSocketIndex,
        scheduleType: 'CRON',
        targetState: _targetState,
        cronExpression: '0 23 * * *', // Daily 11:00 PM
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        widget.onCreated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إنشاء الجدول، تحقق من الاتصال بالسيرفر')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: borderColor, width: 1.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'إنشاء جدول أو مؤقت جديد ⏱️',
              style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary),
            ),
            const SizedBox(height: 14),

            // Select Socket
            Text('اختر المخرج:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: widget.strip.sockets.map((s) {
                final isSelected = s.socketIndex == _selectedSocketIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSocketIndex = s.socketIndex),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.honeyYellow : (widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.honeyYellow : borderColor,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '#${s.socketIndex} ${s.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.black : textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Schedule Type Selector (Timer / Cycle / Cron)
            Text('نوع الجدولة:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildTypeBtn('مؤقت تنازلي', 'TIMER', Icons.timer_outlined),
                const SizedBox(width: 6),
                _buildTypeBtn('دورة متكررة', 'CYCLE', Icons.sync_rounded),
                const SizedBox(width: 6),
                _buildTypeBtn('جدول أسبوعي', 'CRON', Icons.calendar_month_outlined),
              ],
            ),
            const SizedBox(height: 16),

            // Type Options
            if (_scheduleType == 'TIMER') ...[
              Text('المدة التنازلية:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary)),
              const SizedBox(height: 6),
              Row(
                children: [15, 30, 60, 120].map((m) {
                  final isSel = _timerMinutes == m;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _timerMinutes = m),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.honeyYellow : (widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? AppColors.honeyYellow : borderColor),
                        ),
                        child: Text(
                          '$m دقيقة',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: isSel ? Colors.black : textPrimary),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('إطفاء الفيشة بعد انتهاء الوقت', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800)),
                subtitle: Text('إذا كانت مغلقة، سيتم تشغيل الفيشة بعد انتهاء الوقت', style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary)),
                value: !_targetState,
                activeColor: AppColors.honeyYellow,
                onChanged: (val) => setState(() => _targetState = !val),
              ),
            ] else if (_scheduleType == 'CYCLE') ...[
              Text('مدة التشغيل: $_cycleOnMinutes دقيقة | مدة الإيقاف: $_cycleOffMinutes دقيقة', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Slider(
                value: _cycleOnMinutes.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                activeColor: AppColors.honeyYellow,
                label: '$_cycleOnMinutes دقيقة تشغيل',
                onChanged: (val) => setState(() => _cycleOnMinutes = val.toInt()),
              ),
              Slider(
                value: _cycleOffMinutes.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                activeColor: AppColors.routerCyan,
                label: '$_cycleOffMinutes دقيقة إيقاف',
                onChanged: (val) => setState(() => _cycleOffMinutes = val.toInt()),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'جدولة يومية أوتوماتيكية: إطفاء تلقائي للمخرج يومياً الساعة 11:00 مساءً لحماية وتوفير الطاقة',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary),
                ),
              ),
            ],

            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.honeyYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text('حفظ وتشغيل الجدول بالسيرفر 🚀', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBtn(String label, String value, IconData icon) {
    final isSel = _scheduleType == value;
    final borderColor = isSel ? AppColors.honeyYellow : (widget.isDark ? AppColors.borderDark : AppColors.borderLight);
    final bg = isSel ? AppColors.honeyYellow : (widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight);
    final text = isSel ? Colors.black : (widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _scheduleType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSel ? Colors.black : AppColors.honeyYellow),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: text)),
            ],
          ),
        ),
      ),
    );
  }
}

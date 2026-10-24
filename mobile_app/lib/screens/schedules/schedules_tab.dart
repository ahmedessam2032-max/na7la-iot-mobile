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
    List<ScheduleModel> loaded = await _repo.getStripSchedules(widget.strip.macAddress);
    if (loaded.isEmpty) {
      for (final sock in widget.strip.sockets) {
        try {
          final list = await _repo.getSocketSchedules(widget.strip.macAddress, sock.socketIndex);
          loaded.addAll(list);
        } catch (_) {}
      }
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
    if (success && mounted) {
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
      if (success && mounted) {
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

  String _formatDuration(int sec) {
    if (sec < 60) return '$sec ثانية';
    if (sec % 60 == 0) return '${sec ~/ 60} دقيقة';
    return '${sec ~/ 60}د و ${sec % 60}ث';
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
      color: AppColors.emeraldPrimary,
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
                  _buildSummaryItem('جدول زمني', '$cronCount', Icons.calendar_month_outlined, AppColors.emeraldPrimary),
                  _buildSummaryItem('مؤقت', '$timerCount', Icons.timer_outlined, AppColors.warningAmber),
                  _buildSummaryItem('دورة متكررة', '$cycleCount', Icons.sync_rounded, AppColors.routerCyan),
                  _buildSummaryItem('إطفاء تلقائي', '$autoOffCount', Icons.power_settings_new_rounded, const Color(0xFF8B5CF6)),
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
                      'جداول ومؤقتات المشترك والمخارج ⏰',
                      style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: textPrimary),
                    ),
                    Text(
                      'تُنفذ سحابياً وتلقائياً حتى لو كان هاتفك مغلقاً',
                      style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _openAddScheduleModal,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    'جدول جديد',
                    style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                child: Center(child: CircularProgressIndicator(color: AppColors.emeraldPrimary)),
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
                      'يمكنك جدولة مخرج واحد أو عدة مخارج معاً بالثواني أو الدقائق أو الساعات',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openAddScheduleModal,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('إنشاء جدول جديد الآن', style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emeraldPrimary,
                        side: const BorderSide(color: AppColors.emeraldPrimary),
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
                  (x) => x.id == s.socketId || x.socketIndex == s.socketIndex,
                  orElse: () => SocketModel(id: s.socketId, socketIndex: s.socketIndex ?? 1, name: s.socketName ?? 'مخرج'),
                );

                String typeBadge = 'مؤقت تنازلي (${_formatDuration(s.timerDurationSec ?? 60)} -> ${s.targetState ? "تشغيل" : "إيقاف"})';
                IconData typeIcon = Icons.timer_outlined;
                Color typeColor = AppColors.warningAmber;

                if (s.scheduleType == 'CYCLE') {
                  typeBadge = 'دورة متكررة (${_formatDuration(s.cycleOnSec ?? 60)} تشغيل / ${_formatDuration(s.cycleOffSec ?? 60)} إيقاف)';
                  typeIcon = Icons.sync_rounded;
                  typeColor = AppColors.routerCyan;
                } else if (s.scheduleType == 'CRON') {
                  typeBadge = 'جدول (${s.cronExpression ?? ""}) -> ${s.targetState ? "تشغيل" : "إيقاف"}${s.holdState ? " 📌 تثبيت" : ""}';
                  typeIcon = Icons.calendar_month_outlined;
                  typeColor = AppColors.emeraldPrimary;
                } else if (s.scheduleType == 'AUTO_OFF') {
                  typeBadge = 'إطفاء تلقائي بعد التشغيل بـ (${_formatDuration(s.autoOffDelaySec ?? 60)})';
                  typeIcon = Icons.power_settings_new_rounded;
                  typeColor = const Color(0xFF8B5CF6);
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
                              style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: s.isActive,
                        activeColor: AppColors.emeraldPrimary,
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
  final Set<int> _selectedSockets = {1};
  String _scheduleType = 'CRON'; // CRON | TIMER | CYCLE | AUTO_OFF

  // CRON fields
  TimeOfDay _cronTime = const TimeOfDay(hour: 23, minute: 0);
  bool _targetState = false; // false = OFF, true = ON
  bool _holdState = false;

  // TIMER fields
  bool _timerInSeconds = false;
  int _timerValue = 30; // 30 min or 30 sec

  // CYCLE fields
  int _cycleOnMinutes = 20;
  int _cycleOffMinutes = 40;

  // AUTO_OFF fields
  bool _autoOffInSeconds = false;
  int _autoOffValue = 15;

  bool _isSaving = false;

  Future<void> _submit() async {
    if (_selectedSockets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مخرجاً واحداً على الأقل')),
      );
      return;
    }

    setState(() => _isSaving = true);
    bool ok = false;
    final indices = _selectedSockets.toList()..sort();
    final primaryIdx = indices.first;

    if (_scheduleType == 'TIMER') {
      final sec = _timerInSeconds ? _timerValue : (_timerValue * 60);
      ok = await _repo.createSchedule(
        mac: widget.strip.macAddress,
        socketIndex: primaryIdx,
        scheduleType: 'TIMER',
        targetState: _targetState,
        timerDurationSec: sec,
        socketIndices: indices,
      );
    } else if (_scheduleType == 'CYCLE') {
      for (final idx in indices) {
        ok = await _repo.createCycleSchedule(
          mac: widget.strip.macAddress,
          socketIndex: idx,
          cycleOnSec: _cycleOnMinutes * 60,
          cycleOffSec: _cycleOffMinutes * 60,
        );
      }
    } else if (_scheduleType == 'CRON') {
      final cronExpr = '${_cronTime.minute} ${_cronTime.hour} * * *';
      ok = await _repo.createSchedule(
        mac: widget.strip.macAddress,
        socketIndex: primaryIdx,
        scheduleType: 'CRON',
        targetState: _targetState,
        cronExpression: cronExpr,
        holdState: _holdState,
        socketIndices: indices,
      );
    } else if (_scheduleType == 'AUTO_OFF') {
      final sec = _autoOffInSeconds ? _autoOffValue : (_autoOffValue * 60);
      for (final idx in indices) {
        ok = await _repo.configSocket(widget.strip.macAddress, idx, {
          'auto_off_delay_sec': sec,
        });
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        widget.onCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ وتفعيل الجدول على السيرفر السحابي بنجاح'),
            backgroundColor: AppColors.emeraldPrimary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ فشل إنشاء الجدول، تحقق من الاتصال بالسيرفر')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final mutedBg = widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight;
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                'جدولة المشترك والمخارج (4 أنماط) ⏱️',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary),
              ),
              const SizedBox(height: 12),

              // Multi-Socket Selector
              Text(
                'اختر المخارج المطلوب جدولتها (يمكنك اختيار أكثر من مخرج):',
                style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: widget.strip.sockets.map((s) {
                  final isSelected = _selectedSockets.contains(s.socketIndex);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected && _selectedSockets.length > 1) {
                            _selectedSockets.remove(s.socketIndex);
                          } else {
                            _selectedSockets.add(s.socketIndex);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.emeraldPrimary : mutedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.emeraldPrimary : borderColor,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          '#${s.socketIndex} ${s.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // 4 Schedule Type Tabs
              Row(
                children: [
                  _buildTypeBtn('جدول', 'CRON', Icons.calendar_month_outlined),
                  const SizedBox(width: 5),
                  _buildTypeBtn('مؤقت', 'TIMER', Icons.timer_outlined),
                  const SizedBox(width: 5),
                  _buildTypeBtn('دورة', 'CYCLE', Icons.sync_rounded),
                  const SizedBox(width: 5),
                  _buildTypeBtn('إطفاء تلقائي', 'AUTO_OFF', Icons.power_settings_new_rounded),
                ],
              ),
              const SizedBox(height: 16),

              // Type Options
              if (_scheduleType == 'CRON') ...[
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _cronTime,
                    );
                    if (picked != null) {
                      setState(() => _cronTime = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: mutedBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.emeraldPrimary.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'وقت التنفيذ اليومي:',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: textPrimary),
                        ),
                        Row(
                          children: [
                            Text(
                              _cronTime.format(context),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.emeraldPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.emeraldPrimary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _targetState ? 'الإجراء: تشغيل المخرج ⚡' : 'الإجراء: إيقاف المخرج ⏻',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: textPrimary),
                  ),
                  value: _targetState,
                  activeColor: AppColors.emeraldPrimary,
                  onChanged: (v) => setState(() => _targetState = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '📌 تثبيت الحالة (Hold State)',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: textPrimary),
                  ),
                  subtitle: Text(
                    'إجبار المخرج على البقاء في هذه الحالة طوال فترة الجدول حتى لو ضُغط الزر الفيزيائي',
                    style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                  ),
                  value: _holdState,
                  activeColor: AppColors.emeraldPrimary,
                  onChanged: (v) => setState(() => _holdState = v),
                ),
              ] else if (_scheduleType == 'TIMER') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'وحدة المؤقت التنازلي:',
                      style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('ثواني')),
                        ButtonSegment(value: false, label: Text('دقائق')),
                      ],
                      selected: {_timerInSeconds},
                      onSelectionChanged: (s) => setState(() => _timerInSeconds = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: (_timerInSeconds ? [10, 30, 60, 120] : [15, 30, 60, 120]).map((val) {
                    final isSel = _timerValue == val;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _timerValue = val),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.emeraldPrimary : mutedBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSel ? AppColors.emeraldPrimary : borderColor),
                          ),
                          child: Text(
                            '$val ${_timerInSeconds ? "ث" : "د"}',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isSel ? Colors.white : textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _targetState ? 'تشغيل بعد انتهاء المؤقت ⚡' : 'إيقاف بعد انتهاء المؤقت ⏻',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: textPrimary),
                  ),
                  value: _targetState,
                  activeColor: AppColors.emeraldPrimary,
                  onChanged: (val) => setState(() => _targetState = val),
                ),
              ] else if (_scheduleType == 'CYCLE') ...[
                Text(
                  'مدة التشغيل: $_cycleOnMinutes دقيقة | مدة الإيقاف: $_cycleOffMinutes دقيقة',
                  style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                Slider(
                  value: _cycleOnMinutes.toDouble(),
                  min: 1,
                  max: 120,
                  divisions: 119,
                  activeColor: AppColors.emeraldPrimary,
                  onChanged: (val) => setState(() => _cycleOnMinutes = val.toInt()),
                ),
                Slider(
                  value: _cycleOffMinutes.toDouble(),
                  min: 1,
                  max: 120,
                  divisions: 119,
                  activeColor: AppColors.routerCyan,
                  onChanged: (val) => setState(() => _cycleOffMinutes = val.toInt()),
                ),
              ] else if (_scheduleType == 'AUTO_OFF') ...[
                Text(
                  'إطفاء المخرج تلقائياً في كل مرة يتم تشغيله فيها بعد مرور:',
                  style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الوحدة الزمنية:', style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800)),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('ثواني')),
                        ButtonSegment(value: false, label: Text('دقائق')),
                      ],
                      selected: {_autoOffInSeconds},
                      onSelectionChanged: (s) => setState(() => _autoOffInSeconds = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: (_autoOffInSeconds ? [10, 30, 60, 300] : [5, 15, 30, 60]).map((val) {
                    final isSel = _autoOffValue == val;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _autoOffValue = val),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.emeraldPrimary : mutedBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSel ? AppColors.emeraldPrimary : borderColor),
                          ),
                          child: Text(
                            '$val ${_autoOffInSeconds ? "ث" : "د"}',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isSel ? Colors.white : textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'حفظ وتفعيل الجدول بالسيرفر 🚀',
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBtn(String label, String value, IconData icon) {
    final isSel = _scheduleType == value;
    final borderColor = isSel ? AppColors.emeraldPrimary : (widget.isDark ? AppColors.borderDark : AppColors.borderLight);
    final bg = isSel ? AppColors.emeraldPrimary : (widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight);
    final text = isSel ? Colors.white : (widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

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
              Icon(icon, size: 16, color: isSel ? Colors.white : AppColors.emeraldPrimary),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.cairo(fontSize: 9.5, fontWeight: FontWeight.w800, color: text)),
            ],
          ),
        ),
      ),
    );
  }
}

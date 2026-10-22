import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/socket_model.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/repositories/strip_repository.dart';

class RepeatingCycleSheet extends StatefulWidget {
  final String mac;
  final SocketModel socket;
  final bool isDark;
  final VoidCallback onCycleChanged;

  const RepeatingCycleSheet({
    super.key,
    required this.mac,
    required this.socket,
    required this.isDark,
    required this.onCycleChanged,
  });

  @override
  State<RepeatingCycleSheet> createState() => _RepeatingCycleSheetState();
}

class _RepeatingCycleSheetState extends State<RepeatingCycleSheet> {
  final _repo = StripRepository();
  bool _isLoading = true;
  bool _isSaving = false;
  ScheduleModel? _activeCycle;

  late TextEditingController _onMinutesCtrl;
  late TextEditingController _offMinutesCtrl;
  bool _startImmediately = true;

  @override
  void initState() {
    super.initState();
    _onMinutesCtrl = TextEditingController(text: '15');
    _offMinutesCtrl = TextEditingController(text: '45');
    _loadSchedules();
  }

  @override
  void dispose() {
    _onMinutesCtrl.dispose();
    _offMinutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final schedules = await _repo.getSocketSchedules(widget.mac, widget.socket.socketIndex);
    ScheduleModel? cycle;
    for (final s in schedules) {
      if (s.scheduleType == 'CYCLE' && s.isActive) {
        cycle = s;
        break;
      }
    }
    setState(() {
      _activeCycle = cycle;
      if (cycle != null) {
        if (cycle.cycleOnSec != null) {
          _onMinutesCtrl.text = (cycle.cycleOnSec! ~/ 60).toString();
        }
        if (cycle.cycleOffSec != null) {
          _offMinutesCtrl.text = (cycle.cycleOffSec! ~/ 60).toString();
        }
      }
      _isLoading = false;
    });
  }

  void _applyPreset(int onMin, int offMin) {
    setState(() {
      _onMinutesCtrl.text = onMin.toString();
      _offMinutesCtrl.text = offMin.toString();
    });
  }

  Future<void> _startCycle() async {
    final onMin = int.tryParse(_onMinutesCtrl.text.trim()) ?? 15;
    final offMin = int.tryParse(_offMinutesCtrl.text.trim()) ?? 45;

    if (onMin < 1 || offMin < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مدة دقيقة واحدة على الأقل لكل من التشغيل والإيقاف')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await _repo.createCycleSchedule(
      mac: widget.mac,
      socketIndex: widget.socket.socketIndex,
      cycleOnSec: onMin * 60,
      cycleOffSec: offMin * 60,
      initialOn: _startImmediately,
    );
    setState(() => _isSaving = false);

    if (ok) {
      widget.onCycleChanged();
      await _loadSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔄 تم تفعيل الدورة المتكررة بنجاح ($onMinد تشغيل / $offMinد إيقاف)'),
            backgroundColor: AppColors.honeyAmber,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل بدء الدورة المتكررة. تحقق من الاتصال بالسيرفر')),
        );
      }
    }
  }

  Future<void> _stopCycle() async {
    if (_activeCycle == null) return;
    setState(() => _isSaving = true);
    final ok = await _repo.deleteSchedule(_activeCycle!.id);
    setState(() => _isSaving = false);

    if (ok) {
      widget.onCycleChanged();
      await _loadSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🛑 تم إيقاف وحذف الدورة المتكررة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack, width: 2),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: const Icon(Icons.sync_rounded, size: 24, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دورات التشغيل المتكررة (Repeating Cycles)',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      Text(
                        'للمخرج: ${widget.socket.name}',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.honeyYellow, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(color: AppColors.honeyYellow)),
              )
            else ...[
              // Active Cycle Status Banner
              if (_activeCycle != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'الدورة المتكررة قيد العمل حالياً 🔄',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF10B981)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• تشغيل: ${_activeCycle!.cycleOnSec != null ? (_activeCycle!.cycleOnSec! ~/ 60) : 0} دقيقة\n'
                        '• إيقاف: ${_activeCycle!.cycleOffSec != null ? (_activeCycle!.cycleOffSec! ~/ 60) : 0} دقيقة\n'
                        '• الإجراء القادم: ${_activeCycle!.targetState ? "تشغيل" : "إطفاء"}',
                        style: GoogleFonts.cairo(fontSize: 11.5, height: 1.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _stopCycle,
                        icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 18),
                        label: Text(
                          'إيقاف وحذف الدورة الحالية 🛑',
                          style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Presets Grid
              Text(
                'النماذج السريعة الجاهزة (Quick Presets):',
                style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetChip('❄️ ثلاجة وتبريد (20د تشغيل / 40د إيقاف)', () => _applyPreset(20, 40)),
                  _buildPresetChip('🌊 مضخة وفلتر (30د تشغيل / 60د إيقاف)', () => _applyPreset(30, 60)),
                  _buildPresetChip('💨 شفاط وتهوية (10د تشغيل / 20د إيقاف)', () => _applyPreset(10, 20)),
                  _buildPresetChip('💡 إضاءة نباتات (8س تشغيل / 16س إيقاف)', () => _applyPreset(480, 960)),
                ],
              ),
              const SizedBox(height: 18),

              // Custom Durations
              Text(
                'تخصيص أزمنة الدورة:',
                style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('وقت التشغيل (بالدقائق):', style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _onMinutesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: 'دقيقة',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('وقت الإيقاف (بالدقائق):', style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _offMinutesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: 'دقيقة',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Start Immediately switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'البدء بالتشغيل فوراً',
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'تشغيل المقبس بالهاردوير الآن وبدء عداد وقت التشغيل',
                  style: GoogleFonts.cairo(fontSize: 10, color: widget.isDark ? Colors.white60 : Colors.black54),
                ),
                value: _startImmediately,
                activeColor: AppColors.honeyAmber,
                onChanged: (val) => setState(() => _startImmediately = val),
              ),
              const SizedBox(height: 16),

              // Safety Tip
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.honeyYellow.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.honeyYellow.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 18, color: AppColors.honeyYellow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تعمل الدورة سحابياً على السيرفر مباشرة، وتستمر بدقة حتى لو كان الهاتف مغلقاً.',
                        style: GoogleFonts.cairo(fontSize: 10, height: 1.3, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _startCycle,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkBlack),
                      )
                    : Text(
                        _activeCycle != null ? 'تحديث الدورة المتكررة 🔄' : 'بدء تشغيل الدورة المتكررة ▶️',
                        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.honeyYellow,
                  foregroundColor: AppColors.inkBlack,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.inkBlack, width: 2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: FontWeight.w800)),
      backgroundColor: widget.isDark ? AppColors.cardMutedDark : AppColors.honeyYellow.withOpacity(0.18),
      side: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.inkBlack, width: 1.5),
      onPressed: onTap,
    );
  }
}

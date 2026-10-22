import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/socket_model.dart';
import '../../../data/repositories/strip_repository.dart';
import '../../schedules/widgets/repeating_cycle_sheet.dart';

class SocketDeepDiveSheet extends StatefulWidget {
  final String mac;
  final SocketModel socket;
  final bool isDark;
  final Function(SocketModel updatedSocket) onUpdated;

  const SocketDeepDiveSheet({
    super.key,
    required this.mac,
    required this.socket,
    required this.isDark,
    required this.onUpdated,
  });

  @override
  State<SocketDeepDiveSheet> createState() => _SocketDeepDiveSheetState();
}

class _SocketDeepDiveSheetState extends State<SocketDeepDiveSheet> {
  final _repo = StripRepository();
  late TextEditingController _nameController;
  late TextEditingController _minWattController;
  late TextEditingController _cutoffDelayController;
  late TextEditingController _maxWattController;
  late TextEditingController _autoOffDelayController;

  late bool _isLocked;
  late bool _isRouter;
  late bool _compressorProtect;
  late String _powerOnBehavior;

  late bool _enableLowWattCutoff;
  late bool _enableOverloadGuard;
  late bool _enableAutoOff;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.socket.name);
    _isLocked = widget.socket.isLocked;
    _isRouter = widget.socket.isRouter;
    _compressorProtect = widget.socket.compressorProtect;
    _powerOnBehavior = widget.socket.powerOnBehavior;

    _enableLowWattCutoff = widget.socket.minWattCutoff != null && widget.socket.minWattCutoff! > 0;
    _minWattController = TextEditingController(
      text: widget.socket.minWattCutoff != null ? widget.socket.minWattCutoff!.toStringAsFixed(1) : '2.5',
    );
    _cutoffDelayController = TextEditingController(
      text: ((widget.socket.cutoffDelaySec > 0 ? widget.socket.cutoffDelaySec : 300) ~/ 60).toString(),
    );

    _enableOverloadGuard = widget.socket.maxWattLimit != null && widget.socket.maxWattLimit! > 0;
    _maxWattController = TextEditingController(
      text: widget.socket.maxWattLimit != null ? widget.socket.maxWattLimit!.toStringAsFixed(0) : '2200',
    );

    _enableAutoOff = widget.socket.autoOffDelaySec != null && widget.socket.autoOffDelaySec! > 0;
    _autoOffDelayController = TextEditingController(
      text: ((widget.socket.autoOffDelaySec ?? 1200) ~/ 60).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minWattController.dispose();
    _cutoffDelayController.dispose();
    _maxWattController.dispose();
    _autoOffDelayController.dispose();
    super.dispose();
  }

  void _applyPreset(String type) {
    setState(() {
      if (type == 'fridge') {
        _compressorProtect = true;
        _isRouter = false;
        widget.socket.icon = 'kitchen';
        widget.socket.compressorDelaySec = 180;
        _enableOverloadGuard = true;
        _maxWattController.text = '800';
      } else if (type == 'ac') {
        _compressorProtect = true;
        _isRouter = false;
        widget.socket.icon = 'ac';
        widget.socket.compressorDelaySec = 300;
        _enableOverloadGuard = true;
        _maxWattController.text = '2500';
      } else if (type == 'router') {
        _isRouter = true;
        _isLocked = true;
        _compressorProtect = false;
        widget.socket.icon = 'router';
        _enableOverloadGuard = true;
        _maxWattController.text = '50';
      } else if (type == 'charger') {
        widget.socket.icon = 'charger';
        _isRouter = false;
        _enableLowWattCutoff = true;
        _minWattController.text = '2.5';
        _cutoffDelayController.text = '5';
      } else if (type == 'heater') {
        widget.socket.icon = 'heater';
        _isRouter = false;
        _enableAutoOff = true;
        _autoOffDelayController.text = '25';
      } else if (type == 'tv') {
        widget.socket.icon = 'tv';
        _isRouter = false;
        _enableOverloadGuard = true;
        _maxWattController.text = '300';
      }
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    final double? minW = _enableLowWattCutoff ? double.tryParse(_minWattController.text.trim()) : null;
    final int cutoffSec = _enableLowWattCutoff
        ? ((int.tryParse(_cutoffDelayController.text.trim()) ?? 5) * 60)
        : 600;

    final double? maxW = _enableOverloadGuard ? double.tryParse(_maxWattController.text.trim()) : null;
    final int? autoOffSec = _enableAutoOff
        ? ((int.tryParse(_autoOffDelayController.text.trim()) ?? 20) * 60)
        : null;

    final payload = {
      'name': _nameController.text.trim(),
      'icon': widget.socket.icon,
      'is_router': _isRouter,
      'compressor_protect': _compressorProtect,
      'compressor_delay_sec': widget.socket.compressorDelaySec,
      'min_watt_cutoff': minW,
      'cutoff_delay_sec': cutoffSec,
      'max_watt_limit': maxW,
      'auto_off_delay_sec': autoOffSec,
      'power_on_behavior': _powerOnBehavior,
    };

    await _repo.configSocket(widget.mac, widget.socket.socketIndex, payload);

    if (_isLocked != widget.socket.isLocked) {
      await _repo.lockSocket(widget.mac, widget.socket.socketIndex, _isLocked);
    }

    widget.socket.name = _nameController.text.trim();
    widget.socket.isLocked = _isLocked;
    widget.socket.isRouter = _isRouter;
    widget.socket.compressorProtect = _compressorProtect;
    widget.socket.minWattCutoff = minW;
    widget.socket.cutoffDelaySec = cutoffSec;
    widget.socket.maxWattLimit = maxW;
    widget.socket.autoOffDelaySec = autoOffSec;
    widget.socket.powerOnBehavior = _powerOnBehavior;

    widget.onUpdated(widget.socket);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildPresetBtn(String label, IconData icon, VoidCallback onTap) {
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;
    final bg = widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight;
    final textColor = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppColors.honeyYellow),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBehaviorBtn(String label, String value) {
    final bool isSelected = _powerOnBehavior == value;
    final Color selectedBg = AppColors.honeyYellow;
    final Color unselectedBg = widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight;
    final Color borderColor = isSelected ? AppColors.honeyYellow : (widget.isDark ? AppColors.borderDark : AppColors.borderLight);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _powerOnBehavior = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : unselectedBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.black : (widget.isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
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
        border: Border(
          top: BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Notch Handle
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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.honeyYellow.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.honeyYellow),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'إعدادات وحماية المخرج #${widget.socket.socketIndex}',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Outlet Name Input
            Text(
              'اسم المخرج:',
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: _nameController,
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3x2 Appliance Presets Grid
            Text(
              'قوالب الحماية السريعة:',
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildPresetBtn('ثلاجة', Icons.kitchen_rounded, () => _applyPreset('fridge')),
                const SizedBox(width: 8),
                _buildPresetBtn('تكييف', Icons.ac_unit_rounded, () => _applyPreset('ac')),
                const SizedBox(width: 8),
                _buildPresetBtn('راوتر', Icons.router_rounded, () => _applyPreset('router')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPresetBtn('شاحن', Icons.smartphone_rounded, () => _applyPreset('charger')),
                const SizedBox(width: 8),
                _buildPresetBtn('سخان', Icons.water_damage_rounded, () => _applyPreset('heater')),
                const SizedBox(width: 8),
                _buildPresetBtn('شاشة', Icons.tv_rounded, () => _applyPreset('tv')),
              ],
            ),
            const SizedBox(height: 16),

            // Divider
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 12),

            // --- SMART WATT LOGIC & GUARDS ---
            Text(
              'منظومة حماية الواط التفاعلية:',
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.honeyYellow),
            ),
            const SizedBox(height: 8),

            // 1. Smart Low-Watt Cutoff (فصل الشحن التلقائي)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.battery_charging_full_rounded, size: 16, color: AppColors.honeyAmber),
                          const SizedBox(width: 6),
                          Text(
                            'فصل الشحن الذكي (Low-Watt Cutoff)',
                            style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                          ),
                        ],
                      ),
                      Switch(
                        value: _enableLowWattCutoff,
                        activeColor: AppColors.honeyYellow,
                        onChanged: (val) => setState(() => _enableLowWattCutoff = val),
                      ),
                    ],
                  ),
                  Text(
                    'يفصل المخرج تلقائياً أول ما يقل سحب الجهاز عن حد معين (حماية لبطارية الهاتف)',
                    style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary),
                  ),
                  if (_enableLowWattCutoff) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('إذا قل الواط عن:', style: GoogleFonts.cairo(fontSize: 10, color: textSecondary)),
                              const SizedBox(height: 3),
                              TextField(
                                controller: _minWattController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  suffixText: 'واط',
                                  isDense: true,
                                  filled: true,
                                  fillColor: bg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('المهلة قبل الفصل:', style: GoogleFonts.cairo(fontSize: 10, color: textSecondary)),
                              const SizedBox(height: 3),
                              TextField(
                                controller: _cutoffDelayController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  suffixText: 'دقائق',
                                  isDense: true,
                                  filled: true,
                                  fillColor: bg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 2. Overload Watt Guard (درع التحميل الزائد للمخرج)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orangeAccent),
                          const SizedBox(width: 6),
                          Text(
                            'درع التحميل الزائد للمخرج (Overload Guard)',
                            style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                          ),
                        ],
                      ),
                      Switch(
                        value: _enableOverloadGuard,
                        activeColor: AppColors.honeyYellow,
                        onChanged: (val) => setState(() => _enableOverloadGuard = val),
                      ),
                    ],
                  ),
                  Text(
                    'فصل فوري إذا تجاوز سحب الجهاز هذا الرقم لحماية الأسلاك والمشترك',
                    style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary),
                  ),
                  if (_enableOverloadGuard) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _maxWattController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'أقصى واط مسموح للمخرج',
                        suffixText: 'واط (Max W)',
                        isDense: true,
                        filled: true,
                        fillColor: bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. Inching Mode (يفصل لوحده بعد المدة كل ما يتشغّل)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: AppColors.honeyAmber),
                          const SizedBox(width: 6),
                          Text(
                            'الإطفاء التلقائي الدائم (Inching Mode)',
                            style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                          ),
                        ],
                      ),
                      Switch(
                        value: _enableAutoOff,
                        activeColor: AppColors.honeyYellow,
                        onChanged: (val) => setState(() => _enableAutoOff = val),
                      ),
                    ],
                  ),
                  Text(
                    'يفصل المخرج لوحده بعد المدة كل ما يتشغّل (مثالي للسخانات وغلايات الشاي والمكواة)',
                    style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary),
                  ),
                  if (_enableAutoOff) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _autoOffDelayController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'المدة بالدقائق',
                        suffixText: 'دقيقة',
                        isDense: true,
                        filled: true,
                        fillColor: bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Compressor Protection & Router Options
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('درع الكمبروسر للثلاجة (180 ثانية)', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800)),
              subtitle: Text('تأخير إعادة التشغيل 3 دقائق لحماية الموتور بعد انقطاع الكهرباء', style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary)),
              value: _compressorProtect,
              activeColor: AppColors.honeyYellow,
              onChanged: (val) => setState(() => _compressorProtect = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('قفل المخرج برمز PIN والبصمة', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800)),
              subtitle: Text('حماية المخرج من العبث اليدوي أو التبديل غير المصرح به', style: GoogleFonts.cairo(fontSize: 9.5, color: textSecondary)),
              value: _isLocked,
              activeColor: AppColors.honeyYellow,
              onChanged: (val) => setState(() => _isLocked = val),
            ),
            const SizedBox(height: 8),

            // Power-On Behavior Selector
            Text(
              'سلوك المخرج بعد عودة الكهرباء (Power-on Behavior):',
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildBehaviorBtn('تشغيل (ON)', 'ON'),
                const SizedBox(width: 6),
                _buildBehaviorBtn('إطفاء (OFF)', 'OFF'),
                const SizedBox(width: 6),
                _buildBehaviorBtn('آخر حالة (LAST)', 'LAST'),
              ],
            ),
            const SizedBox(height: 14),

            // Repeating Cycles Action Button
            OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => RepeatingCycleSheet(
                    mac: widget.mac,
                    socket: widget.socket,
                    isDark: widget.isDark,
                    onCycleChanged: () {
                      widget.onUpdated(widget.socket);
                    },
                  ),
                );
              },
              icon: const Icon(Icons.repeat_rounded, size: 16),
              label: Text(
                'ضبط دورة تشغيل متكررة (Repeating Cycles)',
                style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.honeyYellow,
                side: BorderSide(color: AppColors.honeyYellow.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
            const SizedBox(height: 16),

            // Save Changes CTA
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.honeyYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        'حفظ التغييرات وحماية المخرج 🛡️',
                        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

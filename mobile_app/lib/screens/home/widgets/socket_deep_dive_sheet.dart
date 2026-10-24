import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/socket_model.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/repositories/strip_repository.dart';

class SocketDeepDiveSheet extends StatefulWidget {
  final String stripMac;
  final SocketModel socket;
  final List<SocketModel> allSockets;
  final VoidCallback onSaved;

  const SocketDeepDiveSheet({
    super.key,
    required this.stripMac,
    required this.socket,
    required this.allSockets,
    required this.onSaved,
  });

  @override
  State<SocketDeepDiveSheet> createState() => _SocketDeepDiveSheetState();
}

class _SocketDeepDiveSheetState extends State<SocketDeepDiveSheet> {
  final StripRepository _repo = StripRepository();
  late SocketModel _sock;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sock = widget.socket;
  }

  Future<void> _applyPatch(Map<String, dynamic> patch, {String? successMsg}) async {
    setState(() => _busy = true);
    final ok = await _repo.configSocket(widget.stripMac, _sock.index, patch);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onSaved();
      if (successMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppColors.emeraldActive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ الإعدادات على السيرفر'),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 1. Rename & Icon Modal
  void _openRenameModal() {
    final nameCtrl = TextEditingController(text: _sock.name);
    String selectedIcon = _sock.icon;
    final icons = [
      {'id': 'power_plug', 'label': 'فيشة', 'icon': Icons.power_rounded},
      {'id': 'tv', 'label': 'شاشة', 'icon': Icons.tv_rounded},
      {'id': 'computer', 'label': 'كمبيوتر', 'icon': Icons.computer_rounded},
      {'id': 'router', 'label': 'راوتر', 'icon': Icons.router_rounded},
      {'id': 'fridge', 'label': 'ثلاجة/تكييف', 'icon': Icons.kitchen_rounded},
      {'id': 'charger', 'label': 'شاحن', 'icon': Icons.charging_station_rounded},
      {'id': 'heater', 'label': 'سخان', 'icon': Icons.water_drop_rounded},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('✏️ تغيير اسم وأيقونة المخرج', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم المخرج',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('الأيقونة:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: icons.map((ic) {
                  final sel = selectedIcon == ic['id'];
                  return ChoiceChip(
                    selected: sel,
                    selectedColor: AppColors.emeraldActive.withOpacity(0.2),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ic['icon'] as IconData, size: 16, color: sel ? AppColors.emeraldActive : null),
                        const SizedBox(width: 4),
                        Text(ic['label'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    onSelected: (_) => setDialogState(() => selectedIcon = ic['id'] as String),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldActive,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  _sock = _sock.copyWith(name: newName, icon: selectedIcon);
                });
                await _applyPatch({'name': newName, 'icon': selectedIcon}, successMsg: 'تم تحديث اسم المخرج إلى "$newName"');
                if (mounted) Navigator.pop(context);
              },
              child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Outlet Color Picker Modal (6 Colors from WattQ 1.0.27)
  void _openColorPickerModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎨 اختر لون المخرج عند التشغيل', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: AppColors.outletPalette.map((item) {
            final hex = item['hex'] as String;
            final color = item['color'] as Color;
            final label = item['name'] as String;
            final isSelected = _sock.colorHex.toUpperCase() == hex.toUpperCase();
            return GestureDetector(
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _sock = _sock.copyWith(colorHex: hex));
                await _applyPatch({'color_hex': hex}, successMsg: 'تم تغيير لون المخرج إلى $label');
                if (mounted) Navigator.pop(context);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.white,
                        width: isSelected ? 3.5 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 26) : null,
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 3. 4-Tab Outlet Schedule Modal (Schedule / Timer with Sec-Min / Cycle / Auto-Off)
  void _openOutletScheduleModal() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OutletScheduleModal(
        stripMac: widget.stripMac,
        socket: _sock,
        onChanged: widget.onSaved,
      ),
    );
  }

  // 4. Watt Limits & Alert Modal (Cut off above W / Cut off below W / Persist Delay / Alert at W / Reset kWh)
  void _openWattLimitsModal() {
    final maxWattCtrl = TextEditingController(text: _sock.maxWattLimit.toInt().toString());
    final minWattCtrl = TextEditingController(text: _sock.minWattCutoff != null ? _sock.minWattCutoff.toString() : '');
    final delayCtrl = TextEditingController(text: _sock.cutoffDelaySec.toString());
    final alertWattCtrl = TextEditingController(text: _sock.alertWattThreshold != null ? _sock.alertWattThreshold!.toInt().toString() : '');
    bool compressorGuard = _sock.compressorProtect;
    int compressorDelay = _sock.compressorDelaySec;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('⚡ حدود الواط والحماية — ${_sock.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField(
                    controller: maxWattCtrl,
                    label: 'فصل التيار عند تجاوز (Cut off above W)',
                    hint: 'مثال: 2500 واط',
                    suffix: 'W',
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField(
                          controller: minWattCtrl,
                          label: 'فصل عند انخفاض السحب تحت (Cut off below W)',
                          hint: 'مثال: 3.0 (لفصل الشاحن)',
                          suffix: 'W',
                          icon: Icons.battery_charging_full_rounded,
                          allowDecimal: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 115,
                        child: _buildNumberField(
                          controller: delayCtrl,
                          label: 'مهلة الثبات',
                          hint: '60',
                          suffix: 'ثانية',
                          icon: Icons.timer_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField(
                    controller: alertWattCtrl,
                    label: 'تنبيه فقط عند تجاوز واط (Alert at W — بدون فصل)',
                    hint: 'اختياري: مثال 1500 واط',
                    suffix: 'W',
                    icon: Icons.notifications_active_outlined,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: compressorGuard,
                          activeColor: AppColors.emeraldActive,
                          title: const Text('❄️ درع حماية الكمبروسر (للثلاجات والتكييف)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          subtitle: Text('منع إعادة التشغيل السريع قبل مرور $compressorDelay ثانية', style: const TextStyle(fontSize: 11)),
                          onChanged: (v) => setSheetState(() => compressorGuard = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await _repo.resetEnergy(widget.stripMac, _sock.index);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'تم تصفير عداد الكيلوواط لهذا المخرج بنجاح' : 'تعذر تصفير العداد'),
                              backgroundColor: ok ? AppColors.emeraldActive : AppColors.dangerRed,
                            ),
                          );
                          if (ok) widget.onSaved();
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('تصفير kWh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emeraldActive,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final maxW = double.tryParse(maxWattCtrl.text.trim()) ?? 2500.0;
                            final minW = minWattCtrl.text.trim().isEmpty ? null : double.tryParse(minWattCtrl.text.trim());
                            final delayS = int.tryParse(delayCtrl.text.trim()) ?? 60;
                            final alertW = alertWattCtrl.text.trim().isEmpty ? null : double.tryParse(alertWattCtrl.text.trim());
                            Navigator.pop(ctx);
                            await _applyPatch({
                              'max_watt_limit': maxW,
                              'min_watt_cutoff': minW,
                              'cutoff_delay_sec': delayS,
                              'alert_watt_threshold': alertW,
                              'compressor_protect': compressorGuard,
                              'compressor_delay_sec': compressorDelay,
                            }, successMsg: 'تم حفظ حدود الواط والتنبيهات بنجاح');
                            if (mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('حفظ الحدود', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 5. Link Group Modal (Groups 1..4)
  void _openLinkGroupModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔗 ربط المخرج في مجموعة متزامنة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المخارج المشتركة في نفس المجموعة تعمل وتنطفئ معاً تلقائياً عند تبديل أي مخرج منها:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            ...[0, 1, 2, 3, 4].map((grp) {
              final selected = _sock.linkGroup == grp;
              final title = grp == 0 ? 'بدون ربط (مستقل)' : 'مجموعة ربط رقم $grp (🔗$grp)';
              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: selected ? AppColors.emeraldActive.withOpacity(0.12) : null,
                leading: Icon(
                  grp == 0 ? Icons.link_off_rounded : Icons.link_rounded,
                  color: selected ? AppColors.emeraldActive : Colors.grey,
                ),
                title: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
                trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.emeraldActive) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _sock = _sock.copyWith(linkGroup: grp));
                  await _applyPatch(
                    {'link_group': grp},
                    successMsg: grp == 0 ? 'تم إلغاء ربط المخرج بالمجموعات' : 'تم ربط المخرج في مجموعة #$grp بنجاح',
                  );
                  if (mounted) Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // 6. Doorbell Mode Modal
  void _openDoorbellModal() {
    bool enabled = _sock.doorbellMode;
    int pulseSec = _sock.doorbellPulseSec;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🔔 وضع الجرس اللحظي (Doorbell Mode)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'عند تفعيل وضع الجرس، يعمل المخرج كنبضة لحظية ثم ينطفئ تلقائياً بعد عدد الثواني المحدد:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.emeraldActive,
                title: const Text('تفعيل وضع الجرس', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                value: enabled,
                onChanged: (v) => setDialogState(() => enabled = v),
              ),
              if (enabled) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مدة النبضة قبل الفصل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text('$pulseSec ثانية', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.emeraldActive)),
                  ],
                ),
                Slider(
                  value: pulseSec.toDouble(),
                  min: 1,
                  max: 15,
                  divisions: 14,
                  activeColor: AppColors.emeraldActive,
                  onChanged: (v) => setDialogState(() => pulseSec = v.round()),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldActive, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _sock = _sock.copyWith(doorbellMode: enabled, doorbellPulseSec: pulseSec));
                await _applyPatch(
                  {'doorbell_mode': enabled, 'doorbell_pulse_sec': pulseSec},
                  successMsg: enabled ? 'تم تفعيل وضع الجرس ($pulseSec ثانية)' : 'تم إيقاف وضع الجرس',
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // 7. Quick Appliance Protection Presets (Na7la Exclusive)
  Future<void> _applyQuickPreset(String presetKey) async {
    Map<String, dynamic> patch = {};
    String label = '';
    switch (presetKey) {
      case 'fridge':
        label = 'ثلاجة / ديب فريزر (درع كمبروسر 180 ثانية + حد 600W)';
        patch = {
          'name': 'ثلاجة',
          'icon': 'fridge',
          'max_watt_limit': 600.0,
          'compressor_protect': true,
          'compressor_delay_sec': 180,
          'min_watt_cutoff': null,
          'is_router': false,
        };
        break;
      case 'ac':
        label = 'تكييف (درع كمبروسر 180 ثانية + حد 2600W)';
        patch = {
          'name': 'تكييف',
          'icon': 'fridge',
          'max_watt_limit': 2600.0,
          'compressor_protect': true,
          'compressor_delay_sec': 180,
          'min_watt_cutoff': null,
          'is_router': false,
        };
        break;
      case 'router':
        label = 'راوتر الإنترنت (محمي من الإطفاء الشامل وفصل الفولت)';
        patch = {
          'name': 'الراوتر',
          'icon': 'router',
          'max_watt_limit': 120.0,
          'compressor_protect': false,
          'is_router': true,
          'is_locked': true,
        };
        break;
      case 'charger':
        label = 'شاحن ذكي (فصل تلقائي عند اكتمال الشحن < 2.5W لمدة 60 ثانية)';
        patch = {
          'name': 'شاحن',
          'icon': 'charger',
          'max_watt_limit': 150.0,
          'min_watt_cutoff': 2.5,
          'cutoff_delay_sec': 60,
          'compressor_protect': false,
          'is_router': false,
        };
        break;
      case 'heater':
        label = 'سخان / كاتل (حد أمان 2200W + إطفاء تلقائي بعد 45 دقيقة)';
        patch = {
          'name': 'سخان',
          'icon': 'heater',
          'max_watt_limit': 2200.0,
          'auto_off_delay_sec': 2700,
          'compressor_protect': false,
          'is_router': false,
        };
        break;
      case 'pc':
        label = 'كمبيوتر / شاشة (حد 800W)';
        patch = {
          'name': 'كمبيوتر',
          'icon': 'computer',
          'max_watt_limit': 800.0,
          'compressor_protect': false,
          'is_router': false,
        };
        break;
    }
    await _applyPatch(patch, successMsg: 'تم تطبيق قالب الحماية: $label');
    if (mounted) Navigator.pop(context);
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String suffix,
    required IconData icon,
    bool allowDecimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon, size: 18, color: AppColors.emeraldActive),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.cardSurfaceDark : Colors.white;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final activeColor = AppColors.parseHexColor(_sock.colorHex, fallback: AppColors.emeraldActive);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header: Outlet Name + Live Metrics Pill
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: activeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.power_rounded, color: activeColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_sock.name} (مخرج ${_sock.index})',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '⚡ ${_sock.watt.toStringAsFixed(1)}W  •  ${_sock.amp.toStringAsFixed(2)}A  •  🌡️ ${_sock.tempC ?? 28}°C  •  ${_sock.kwh.toStringAsFixed(2)} kWh',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: subColor),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emeraldActive),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // 1. Add to Favorites
            _buildMenuRow(
              icon: _sock.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: _sock.isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
              subtitle: 'الوصول السريع للمخرج من تبويب المفضلة',
              onTap: () async {
                final next = !_sock.isFavorite;
                setState(() => _sock = _sock.copyWith(isFavorite: next));
                await _applyPatch(
                  {'is_favorite': next},
                  successMsg: next ? 'تمت إضافة "${_sock.name}" إلى المفضلة ⭐' : 'تمت إزالة "${_sock.name}" من المفضلة',
                );
                if (mounted) Navigator.pop(context);
              },
            ),

            // 2. Rename Outlet
            _buildMenuRow(
              icon: Icons.edit_outlined,
              iconColor: AppColors.emeraldActive,
              title: 'تغيير اسم وأيقونة المخرج',
              subtitle: _sock.name,
              onTap: _openRenameModal,
            ),

            // 3. Outlet Colour (6 Colors)
            _buildMenuRow(
              icon: Icons.palette_outlined,
              iconColor: activeColor,
              title: 'لون المخرج (Outlet colour)',
              subtitle: 'اختر من 6 ألوان مميزة لحالة التشغيل',
              trailing: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              onTap: _openColorPickerModal,
            ),

            // 4. Schedule Outlet (4 Tabs: Schedule / Timer / Cycle / Auto-off)
            _buildMenuRow(
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'جدولة المخرج والمؤقت بالثواني',
              subtitle: _sock.autoOffDelaySec != null && _sock.autoOffDelaySec! > 0
                  ? 'إطفاء تلقائي مفعل بعد ${_sock.autoOffDelaySec} ثانية'
                  : 'جدول زمني • مؤقت بالثواني/الدقائق • دورة • إطفاء تلقائي',
              onTap: _openOutletScheduleModal,
            ),

            // 5. Watt Limits & Alert
            _buildMenuRow(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'حدود الواط والتنبيه (Watt limits)',
              subtitle: 'أقصى سحب: ${_sock.maxWattLimit.toInt()}W'
                  '${_sock.minWattCutoff != null ? " • فصل خمول < ${_sock.minWattCutoff}W" : ""}'
                  '${_sock.alertWattThreshold != null ? " • تنبيه عند ${_sock.alertWattThreshold!.toInt()}W" : ""}',
              onTap: _openWattLimitsModal,
            ),

            // 6. Restart Outlet (OFF 5s -> ON)
            _buildMenuRow(
              icon: Icons.restart_alt_rounded,
              iconColor: const Color(0xFF06B6D4),
              title: 'إعادة تشغيل المخرج (Restart — 5 ثوانٍ)',
              subtitle: 'يفصل التيار 5 ثوانٍ ثم يعيد التشغيل تلقائياً في السيرفر',
              onTap: () async {
                Navigator.pop(context);
                final res = await _repo.restartSocket(widget.stripMac, _sock.index);
                widget.onSaved();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'جاري إعادة تشغيل المخرج...'),
                    backgroundColor: res['ok'] == true ? AppColors.emeraldActive : AppColors.dangerRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),

            // 7. Link Group (1..4)
            _buildMenuRow(
              icon: Icons.link_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'ربط في مجموعة (Link group)',
              subtitle: _sock.linkGroup > 0 ? 'مربوط حالياً في مجموعة #${_sock.linkGroup} (🔗${_sock.linkGroup})' : 'غير مربوط بمجموعة',
              onTap: _openLinkGroupModal,
            ),

            // 8. Doorbell Mode
            _buildMenuRow(
              icon: Icons.notifications_active_rounded,
              iconColor: const Color(0xFFF97316),
              title: 'وضع الجرس اللحظي (Doorbell mode)',
              subtitle: _sock.doorbellMode ? 'مفعل (نبضة ${_sock.doorbellPulseSec} ثوانٍ ثم إطفاء)' : 'غير مفعل',
              onTap: _openDoorbellModal,
            ),

            // 9. Pin Current State
            _buildMenuRow(
              icon: Icons.push_pin_rounded,
              iconColor: _sock.isPinnedState ? AppColors.dangerRed : Colors.grey,
              title: _sock.isPinnedState ? 'إلغاء تثبيت الحالة (Unpin state)' : 'تثبيت الحالة الحالية (Pin current state)',
              subtitle: _sock.isPinnedState
                  ? 'المخرج مثبّت حالياً وممنوع تغييره يدوياً أو من التطبيق'
                  : 'منع تشغيل أو إطفاء المخرج نهائياً حتى إلغاء التثبيت',
              trailing: Switch(
                value: _sock.isPinnedState,
                activeColor: AppColors.emeraldActive,
                onChanged: (val) async {
                  setState(() => _sock = _sock.copyWith(isPinnedState: val));
                  await _applyPatch(
                    {'is_pinned_state': val},
                    successMsg: val
                        ? 'تم تثبيت حالة "${_sock.name}" الحالية 📌'
                        : 'تم إلغاء تثبيت حالة "${_sock.name}"',
                  );
                  if (mounted) Navigator.pop(context);
                },
              ),
              onTap: () async {
                final val = !_sock.isPinnedState;
                setState(() => _sock = _sock.copyWith(isPinnedState: val));
                await _applyPatch(
                  {'is_pinned_state': val},
                  successMsg: val
                      ? 'تم تثبيت حالة "${_sock.name}" الحالية 📌'
                      : 'تم إلغاء تثبيت حالة "${_sock.name}"',
                );
                if (mounted) Navigator.pop(context);
              },
            ),

            // 10. Router Protection Toggle
            _buildMenuRow(
              icon: Icons.router_rounded,
              iconColor: _sock.isRouter ? AppColors.routerCyan : Colors.grey,
              title: 'حماية الراوتر (استثناء من إيقاف الكل وفصل الفولت)',
              subtitle: _sock.isRouter ? 'مفعل — محمي من الفصل الشامل' : 'غير مفعل',
              trailing: Switch(
                value: _sock.isRouter,
                activeColor: AppColors.routerCyan,
                onChanged: (val) async {
                  setState(() => _sock = _sock.copyWith(isRouter: val));
                  await _applyPatch(
                    {'is_router': val},
                    successMsg: val ? 'تم تفعيل حماية الراوتر لهذا المخرج 🌐' : 'تم إلغاء وضع الراوتر',
                  );
                  if (mounted) Navigator.pop(context);
                },
              ),
              onTap: () async {
                final val = !_sock.isRouter;
                setState(() => _sock = _sock.copyWith(isRouter: val));
                await _applyPatch(
                  {'is_router': val},
                  successMsg: val ? 'تم تفعيل حماية الراوتر لهذا المخرج 🌐' : 'تم إلغاء وضع الراوتر',
                );
                if (mounted) Navigator.pop(context);
              },
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Quick Protection Presets Bar (Na7la Exclusive)
            Text(
              '🛡️ قوالب الحماية الذكية السريعة بضغطة واحدة:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: subColor),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip('❄️ ثلاجة', 'fridge', isDark),
                  _buildPresetChip('🌬️ تكييف', 'ac', isDark),
                  _buildPresetChip('🌐 راوتر', 'router', isDark),
                  _buildPresetChip('📱 شاحن ذكي', 'charger', isDark),
                  _buildPresetChip('🔥 سخان', 'heater', isDark),
                  _buildPresetChip('💻 كمبيوتر', 'pc', isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 19),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildPresetChip(String label, String key, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ActionChip(
        backgroundColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        label: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
        onPressed: () => _applyQuickPreset(key),
      ),
    );
  }
}

// =============================================================================
// 4-Tab Outlet Schedule Modal (Schedule / Timer / Cycle / Auto-Off)
// =============================================================================
class _OutletScheduleModal extends StatefulWidget {
  final String stripMac;
  final SocketModel socket;
  final VoidCallback onChanged;

  const _OutletScheduleModal({
    required this.stripMac,
    required this.socket,
    required this.onChanged,
  });

  @override
  State<_OutletScheduleModal> createState() => _OutletScheduleModalState();
}

class _OutletScheduleModalState extends State<_OutletScheduleModal> with SingleTickerProviderStateMixin {
  final StripRepository _repo = StripRepository();
  late TabController _tabCtrl;
  List<ScheduleModel> _schedules = [];
  bool _loading = true;

  // Tab 1: Schedule (CRON)
  TimeOfDay _pickedTime = const TimeOfDay(hour: 22, minute: 0);
  bool _cronTargetOn = true;
  bool _holdState = false;

  // Tab 2: Timer (Countdown with Minutes / Seconds toggle!)
  final TextEditingController _timerValCtrl = TextEditingController(text: '15');
  bool _timerInSeconds = false; // false = Minutes, true = Seconds
  bool _timerTargetOn = false;

  // Tab 3: Cycle (Repeating On/Off with Minutes / Seconds toggle!)
  final TextEditingController _cycleOnCtrl = TextEditingController(text: '10');
  final TextEditingController _cycleOffCtrl = TextEditingController(text: '10');
  bool _cycleInSeconds = false;

  // Tab 4: Auto-Off (Inching / Auto shutoff after N seconds/minutes)
  final TextEditingController _autoOffCtrl = TextEditingController();
  bool _autoOffInSeconds = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    final curAuto = widget.socket.autoOffDelaySec;
    if (curAuto != null && curAuto > 0) {
      if (curAuto % 60 == 0) {
        _autoOffCtrl.text = (curAuto ~/ 60).toString();
        _autoOffInSeconds = false;
      } else {
        _autoOffCtrl.text = curAuto.toString();
        _autoOffInSeconds = true;
      }
    } else {
      _autoOffCtrl.text = '30';
    }
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _loading = true);
    final list = await _repo.getSocketSchedules(widget.stripMac, widget.socket.index);
    if (!mounted) return;
    setState(() {
      _schedules = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🕒 جدولة ومؤقت — ${widget.socket.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.emeraldActive,
            indicatorColor: AppColors.emeraldActive,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            tabs: const [
              Tab(text: 'جدول يومي'),
              Tab(text: 'مؤقت ذكي'),
              Tab(text: 'دورة ترددية'),
              Tab(text: 'إطفاء تلقائي'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildCronTab(),
                _buildTimerTab(),
                _buildCycleTab(),
                _buildAutoOffTab(),
              ],
            ),
          ),
          const Divider(height: 16),
          // Active schedules list for this socket
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الجداول والمؤقتات المسجلة لهذا المخرج (${_schedules.length}):',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 115,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldActive))
                : _schedules.isEmpty
                    ? const Center(child: Text('لا توجد جداول مسجلة حالياً', style: TextStyle(fontSize: 12, color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _schedules.length,
                        itemBuilder: (ctx, i) {
                          final sc = _schedules[i];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              sc.scheduleType == 'TIMER'
                                  ? Icons.timer_rounded
                                  : (sc.scheduleType == 'CYCLE' ? Icons.loop_rounded : Icons.schedule_rounded),
                              color: sc.isActive ? AppColors.emeraldActive : Colors.grey,
                              size: 18,
                            ),
                            title: Text(
                              '${sc.scheduleType} → ${sc.targetState ? "تشغيل" : "إيقاف"}'
                              '${sc.holdState ? " 🔒" : ""}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              sc.cronExpression ??
                                  (sc.durationSec != null ? 'المدة: ${sc.durationSec} ثانية' : '') +
                                      (sc.autoOffDelaySec != null ? 'إطفاء بعد: ${sc.autoOffDelaySec} ثانية' : ''),
                              style: const TextStyle(fontSize: 10.5),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: sc.isActive,
                                  activeColor: AppColors.emeraldActive,
                                  onChanged: (_) async {
                                    await _repo.toggleSchedule(sc.id);
                                    await _loadSchedules();
                                    widget.onChanged();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.dangerRed),
                                  onPressed: () async {
                                    await _repo.deleteSchedule(sc.id);
                                    await _loadSchedules();
                                    widget.onChanged();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCronTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('وقت التنفيذ اليومي:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            trailing: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: _pickedTime);
                if (picked != null) setState(() => _pickedTime = picked);
              },
              icon: const Icon(Icons.access_time_rounded, size: 18),
              label: Text(_pickedTime.format(context), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          Row(
            children: [
              const Text('الإجراء المطلوب:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('تشغيل (ON)'),
                selected: _cronTargetOn,
                selectedColor: AppColors.emeraldActive.withOpacity(0.2),
                onSelected: (_) => setState(() => _cronTargetOn = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('إيقاف (OFF)'),
                selected: !_cronTargetOn,
                selectedColor: AppColors.dangerRed.withOpacity(0.2),
                onSelected: (_) => setState(() => _cronTargetOn = false),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _holdState,
            activeColor: AppColors.emeraldActive,
            title: const Text('🔒 تثبيت حالة الجدولة (Hold state)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            subtitle: const Text('منع التغيير اليدوي أثناء سريان الجدول', style: TextStyle(fontSize: 11)),
            onChanged: (v) => setState(() => _holdState = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldActive, foregroundColor: Colors.white),
              onPressed: () async {
                final hh = _pickedTime.hour.toString().padLeft(2, '0');
                final mm = _pickedTime.minute.toString().padLeft(2, '0');
                final ok = await _repo.createSchedule(
                  mac: widget.stripMac,
                  socketIndex: widget.socket.index,
                  scheduleType: 'CRON',
                  cronExpression: '$hh:$mm',
                  targetState: _cronTargetOn,
                  holdState: _holdState,
                );
                if (ok) {
                  await _loadSchedules();
                  widget.onChanged();
                }
              },
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('إضافة الجدول الزمني', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _timerValCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _timerInSeconds ? 'المدة بالثواني' : 'المدة بالدقائق',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ToggleButtons(
                isSelected: [!_timerInSeconds, _timerInSeconds],
                borderRadius: BorderRadius.circular(10),
                selectedColor: Colors.white,
                fillColor: AppColors.emeraldActive,
                onPressed: (idx) => setState(() => _timerInSeconds = (idx == 1)),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('دقائق', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('ثواني', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('الإجراء عند انتهاء المؤقت:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('إيقاف (OFF)'),
                selected: !_timerTargetOn,
                selectedColor: AppColors.dangerRed.withOpacity(0.2),
                onSelected: (_) => setState(() => _timerTargetOn = false),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('تشغيل (ON)'),
                selected: _timerTargetOn,
                selectedColor: AppColors.emeraldActive.withOpacity(0.2),
                onSelected: (_) => setState(() => _timerTargetOn = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldActive, foregroundColor: Colors.white),
              onPressed: () async {
                final raw = int.tryParse(_timerValCtrl.text.trim()) ?? 1;
                final totalSec = _timerInSeconds ? raw : (raw * 60);
                final ok = await _repo.createSchedule(
                  mac: widget.stripMac,
                  socketIndex: widget.socket.index,
                  scheduleType: 'TIMER',
                  timerDurationSec: totalSec,
                  targetState: _timerTargetOn,
                );
                if (ok) {
                  await _loadSchedules();
                  widget.onChanged();
                }
              },
              icon: const Icon(Icons.timer_rounded),
              label: const Text('بدء المؤقت التنازلي الآن', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('وحدة دورة التشغيل والإيقاف:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ToggleButtons(
                isSelected: [!_cycleInSeconds, _cycleInSeconds],
                borderRadius: BorderRadius.circular(10),
                constraints: const BoxConstraints(minHeight: 32, minWidth: 58),
                selectedColor: Colors.white,
                fillColor: AppColors.emeraldActive,
                onPressed: (idx) => setState(() => _cycleInSeconds = (idx == 1)),
                children: const [
                  Text('دقائق', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                  Text('ثواني', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cycleOnCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'مدة التشغيل (ON)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _cycleOffCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'مدة الإيقاف (OFF)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldActive, foregroundColor: Colors.white),
              onPressed: () async {
                final onRaw = int.tryParse(_cycleOnCtrl.text.trim()) ?? 10;
                final offRaw = int.tryParse(_cycleOffCtrl.text.trim()) ?? 10;
                final onSec = _cycleInSeconds ? onRaw : (onRaw * 60);
                final offSec = _cycleInSeconds ? offRaw : (offRaw * 60);
                final ok = await _repo.createCycleSchedule(
                  mac: widget.stripMac,
                  socketIndex: widget.socket.index,
                  cycleOnSec: onSec,
                  cycleOffSec: offSec,
                );
                if (ok) {
                  await _loadSchedules();
                  widget.onChanged();
                }
              },
              icon: const Icon(Icons.loop_rounded),
              label: const Text('تفعيل الدورة الترددية', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoOffTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ينطفئ المخرج تلقائياً في كل مرة يتم تشغيله فيها بعد المدة المحددة:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _autoOffCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _autoOffInSeconds ? 'مهلة الإطفاء التلقائي (ثواني)' : 'مهلة الإطفاء التلقائي (دقائق)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ToggleButtons(
                isSelected: [!_autoOffInSeconds, _autoOffInSeconds],
                borderRadius: BorderRadius.circular(10),
                selectedColor: Colors.white,
                fillColor: AppColors.emeraldActive,
                onPressed: (idx) => setState(() => _autoOffInSeconds = (idx == 1)),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('دقائق', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('ثواني', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: () async {
                  await _repo.configSocket(widget.stripMac, widget.socket.index, {'auto_off_delay_sec': 0});
                  await _loadSchedules();
                  widget.onChanged();
                },
                child: const Text('إلغاء الإطفاء التلقائي'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldActive, foregroundColor: Colors.white),
                  onPressed: () async {
                    final raw = int.tryParse(_autoOffCtrl.text.trim()) ?? 30;
                    final sec = _autoOffInSeconds ? raw : (raw * 60);
                    await _repo.configSocket(widget.stripMac, widget.socket.index, {'auto_off_delay_sec': sec});
                    await _loadSchedules();
                    widget.onChanged();
                  },
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('حفظ الإطفاء التلقائي', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

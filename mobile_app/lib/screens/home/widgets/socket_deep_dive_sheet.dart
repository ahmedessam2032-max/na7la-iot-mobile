import 'package:flutter/material.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/socket_model.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/repositories/strip_repository.dart';
import '../../../widgets/pin_biometric_dialog.dart';

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
        SnackBar(
          content: Text(trBi('تعذر حفظ الإعدادات على السيرفر', 'Failed to save settings to server')),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 1. Rename & Icon Modal
  void _openRenameModal() {
    final nameCtrl = TextEditingController(text: trOutletName(_sock.name, _sock.index));
    String selectedIcon = _sock.icon;
    final icons = [
      {'id': 'power_plug', 'label': trBi('فيشة', 'Plug'), 'icon': Icons.power_rounded},
      {'id': 'tv', 'label': trBi('شاشة', 'TV/Monitor'), 'icon': Icons.tv_rounded},
      {'id': 'computer', 'label': trBi('كمبيوتر', 'PC'), 'icon': Icons.computer_rounded},
      {'id': 'router', 'label': trBi('راوتر', 'Router'), 'icon': Icons.router_rounded},
      {'id': 'fridge', 'label': trBi('ثلاجة/تكييف', 'Fridge/AC'), 'icon': Icons.kitchen_rounded},
      {'id': 'charger', 'label': trBi('شاحن', 'Charger'), 'icon': Icons.charging_station_rounded},
      {'id': 'heater', 'label': trBi('سخان', 'Heater'), 'icon': Icons.water_drop_rounded},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: AppLocaleController.instance.textDirection,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(trBi('✏️ تغيير اسم وأيقونة المخرج', '✏️ Edit Outlet Name & Icon'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: trBi('اسم المخرج', 'Outlet Name'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(trBi('الأيقونة:', 'Icon:'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(trBi('إلغاء', 'Cancel'))),
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
                  await _applyPatch(
                    {'name': newName, 'icon': selectedIcon},
                    successMsg: trBi('تم تحديث اسم المخرج إلى "$newName"', 'Outlet renamed to "$newName"'),
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: Text(trBi('حفظ', 'Save'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Outlet Color Picker Modal (6 Colors from WattQ)
  void _openColorPickerModal() {
    final isEn = AppLocaleController.instance.isEnglish;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocaleController.instance.textDirection,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(trBi('🎨 اختر لون المخرج عند التشغيل', '🎨 Choose Active Outlet Color'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: AppColors.outletPalette.map((item) {
              final hex = item['hex'] as String;
              final color = item['color'] as Color;
              final label = (isEn ? (item['nameEn'] ?? item['name']) : item['name']) as String;
              final isSelected = _sock.colorHex.toUpperCase() == hex.toUpperCase();
              return GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _sock = _sock.copyWith(colorHex: hex));
                  await _applyPatch(
                    {'color_hex': hex},
                    successMsg: trBi('تم تغيير لون المخرج إلى $label', 'Outlet color changed to $label'),
                  );
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

  // 4. Watt Limits & Alert Modal
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
      backgroundColor: AppThemeController.instance.isDark ? AppColors.cardSurfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = AppThemeController.instance.isDark;
          return Directionality(
            textDirection: AppLocaleController.instance.textDirection,
            child: Padding(
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
                        Expanded(
                          child: Text(
                            trBi('⚡ حدود الواط والحماية — ${trOutletName(_sock.name, _sock.index)}', '⚡ Watt Limits & Protection — ${trOutletName(_sock.name, _sock.index)}'),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: maxWattCtrl,
                      label: trBi('فصل التيار عند تجاوز (Cut off above W)', 'Cut off power above (W)'),
                      hint: trBi('مثال: 2500 واط', 'e.g. 2500 W'),
                      suffix: 'W',
                      icon: Icons.warning_amber_rounded,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            controller: minWattCtrl,
                            label: trBi('فصل عند انخفاض السحب تحت (Cut off below W)', 'Idle cut-off below (W)'),
                            hint: trBi('مثال: 3.0 (لفصل الشاحن)', 'e.g. 3.0 (Charger auto-off)'),
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
                            label: trBi('مهلة الثبات', 'Persist Delay'),
                            hint: '60',
                            suffix: trBi('ثانية', 'sec'),
                            icon: Icons.timer_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: alertWattCtrl,
                      label: trBi('تنبيه فقط عند تجاوز واط (بدون فصل)', 'Alert-only threshold (W — no cut-off)'),
                      hint: trBi('اختياري: مثال 1500 واط', 'Optional: e.g. 1500 W'),
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
                            title: Text(
                              trBi('❄️ درع حماية الكمبروسر (للثلاجات والتكييف)', '❄️ Compressor Guard (Fridge & AC)'),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              trBi('منع إعادة التشغيل السريع قبل مرور $compressorDelay ثانية', 'Prevent rapid restart before $compressorDelay seconds'),
                              style: const TextStyle(fontSize: 11),
                            ),
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
                                content: Text(ok
                                    ? trBi('تم تصفير عداد الكيلوواط لهذا المخرج بنجاح', 'Outlet kWh counter reset successfully')
                                    : trBi('تعذر تصفير العداد', 'Failed to reset counter')),
                                backgroundColor: ok ? AppColors.emeraldActive : AppColors.dangerRed,
                              ),
                            );
                            if (ok) widget.onSaved();
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: Text(trBi('تصفير kWh', 'Reset kWh'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
                              }, successMsg: trBi('تم حفظ حدود الواط والتنبيهات بنجاح', 'Watt limits & alerts saved successfully'));
                              if (mounted) Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: Text(trBi('حفظ الحدود', 'Save Limits'), style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
      builder: (ctx) => Directionality(
        textDirection: AppLocaleController.instance.textDirection,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(trBi('🔗 ربط المخرج في مجموعة متزامنة', '🔗 Sync Outlet in Link Group'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trBi(
                  'المخارج المشتركة في نفس المجموعة تعمل وتنطفئ معاً تلقائياً عند تبديل أي مخرج منها:',
                  'Outlets assigned to the same group automatically turn ON and OFF together:',
                ),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              ...[0, 1, 2, 3, 4].map((grp) {
                final selected = _sock.linkGroup == grp;
                final title = grp == 0
                    ? trBi('بدون ربط (مستقل)', 'Unlinked (Independent)')
                    : trBi('مجموعة ربط رقم $grp (🔗$grp)', 'Link Group #$grp (🔗$grp)');
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
                      successMsg: grp == 0
                          ? trBi('تم إلغاء ربط المخرج بالمجموعات', 'Outlet unlinked from groups')
                          : trBi('تم ربط المخرج في مجموعة #$grp بنجاح', 'Outlet linked to group #$grp'),
                    );
                    if (mounted) Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
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
        builder: (ctx, setDialogState) => Directionality(
          textDirection: AppLocaleController.instance.textDirection,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(trBi('🔔 وضع الجرس اللحظي (Doorbell Mode)', '🔔 Momentary Doorbell Mode'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trBi(
                    'عند تفعيل وضع الجرس، يعمل المخرج كنبضة لحظية ثم ينطفئ تلقائياً بعد عدد الثواني المحدد:',
                    'When enabled, turning ON this outlet acts as a momentary pulse and automatically turns OFF after the set seconds:',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.emeraldActive,
                  title: Text(trBi('تفعيل وضع الجرس', 'Enable Doorbell Mode'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  value: enabled,
                  onChanged: (v) => setDialogState(() => enabled = v),
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(trBi('مدة النبضة قبل الفصل:', 'Pulse Duration:'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(trBi('$pulseSec ثانية', '$pulseSec sec'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.emeraldActive)),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(trBi('إلغاء', 'Cancel'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldActive, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _sock = _sock.copyWith(doorbellMode: enabled, doorbellPulseSec: pulseSec));
                  await _applyPatch(
                    {'doorbell_mode': enabled, 'doorbell_pulse_sec': pulseSec},
                    successMsg: enabled
                        ? trBi('تم تفعيل وضع الجرس ($pulseSec ثانية)', 'Doorbell mode enabled ($pulseSec sec)')
                        : trBi('تم إيقاف وضع الجرس', 'Doorbell mode disabled'),
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: Text(trBi('حفظ', 'Save'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 7. Quick Appliance Protection Presets
  Future<void> _applyQuickPreset(String presetKey) async {
    Map<String, dynamic> patch = {};
    String label = '';
    switch (presetKey) {
      case 'fridge':
        label = trBi('ثلاجة / ديب فريزر (درع كمبروسر 180 ثانية + حد 600W)', 'Fridge / Freezer (180s compressor guard + 600W limit)');
        patch = {
          'name': trBi('ثلاجة', 'Fridge'),
          'icon': 'fridge',
          'max_watt_limit': 600.0,
          'compressor_protect': true,
          'compressor_delay_sec': 180,
          'min_watt_cutoff': null,
          'is_router': false,
        };
        break;
      case 'ac':
        label = trBi('تكييف (درع كمبروسر 180 ثانية + حد 2600W)', 'Air Conditioner (180s compressor guard + 2600W limit)');
        patch = {
          'name': trBi('تكييف', 'AC'),
          'icon': 'fridge',
          'max_watt_limit': 2600.0,
          'compressor_protect': true,
          'compressor_delay_sec': 180,
          'min_watt_cutoff': null,
          'is_router': false,
        };
        break;
      case 'router':
        label = trBi('راوتر الإنترنت (محمي من الإطفاء الشامل وفصل الفولت)', 'Wi-Fi Router (Exempt from Master Off & Voltage Trip)');
        patch = {
          'name': trBi('الراوتر', 'Router'),
          'icon': 'router',
          'max_watt_limit': 120.0,
          'compressor_protect': false,
          'is_router': true,
        };
        break;
      case 'charger':
        label = trBi('شاحن ذكي (فصل تلقائي عند اكتمال الشحن < 2.5W لمدة 60 ثانية)', 'Smart Charger (Auto cut-off < 2.5W for 60s)');
        patch = {
          'name': trBi('شاحن', 'Charger'),
          'icon': 'charger',
          'max_watt_limit': 150.0,
          'min_watt_cutoff': 2.5,
          'cutoff_delay_sec': 60,
          'compressor_protect': false,
          'is_router': false,
        };
        break;
      case 'heater':
        label = trBi('سخان / كاتل (حد أمان 2200W + إطفاء تلقائي بعد 45 دقيقة)', 'Heater / Kettle (2200W limit + 45m auto-off)');
        patch = {
          'name': trBi('سخان', 'Heater'),
          'icon': 'heater',
          'max_watt_limit': 2200.0,
          'auto_off_delay_sec': 2700,
          'compressor_protect': false,
          'is_router': false,
        };
        break;
      case 'pc':
        label = trBi('كمبيوتر / شاشة (حد 800W)', 'PC / Workstation (800W limit)');
        patch = {
          'name': trBi('كمبيوتر', 'PC'),
          'icon': 'computer',
          'max_watt_limit': 800.0,
          'compressor_protect': false,
          'is_router': false,
        };
        break;
    }
    await _applyPatch(patch, successMsg: trBi('تم تطبيق قالب الحماية: $label', 'Applied preset: $label'));
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

  void _toggleOutletLockWithAuth(bool isDark) {
    final displaySockName = trOutletName(_sock.name, _sock.index);
    final nextLock = !_sock.isLocked;
    showDialog(
      context: context,
      builder: (_) => PinBiometricDialog(
        title: nextLock
            ? trBi('تأكيد قفل وحماية: $displaySockName 🔒', 'Confirm Lock & Child Guard: $displaySockName 🔒')
            : trBi('تأكيد فتح قفل: $displaySockName 🔓', 'Confirm Unlock: $displaySockName 🔓'),
        isDark: isDark,
        onSuccessWithPin: (pin) async {
          setState(() => _sock = _sock.copyWith(isLocked: nextLock));
          await _applyPatch(
            {'is_locked': nextLock},
            successMsg: nextLock
                ? trBi(
                    '🔒 تم قفل "$displaySockName" وتفعيل قفل الأطفال الفردي له',
                    '🔒 "$displaySockName" locked & protected with individual Child Guard',
                  )
                : trBi(
                    '🔓 تم فتح قفل "$displaySockName" بنجاح',
                    '🔓 "$displaySockName" unlocked successfully',
                  ),
          );
        },
        onSuccess: () async {
          setState(() => _sock = _sock.copyWith(isLocked: nextLock));
          await _applyPatch(
            {'is_locked': nextLock},
            successMsg: nextLock
                ? trBi(
                    '🔒 تم قفل "$displaySockName" وتفعيل قفل الأطفال الفردي له',
                    '🔒 "$displaySockName" locked & protected with individual Child Guard',
                  )
                : trBi(
                    '🔓 تم فتح قفل "$displaySockName" بنجاح',
                    '🔓 "$displaySockName" unlocked successfully',
                  ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeController.instance.isDark;
    final surfaceColor = isDark ? AppColors.cardSurfaceDark : Colors.white;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final activeColor = AppColors.parseHexColor(_sock.colorHex, fallback: AppColors.emeraldActive);
    final displaySockName = trOutletName(_sock.name, _sock.index);

    return Directionality(
      textDirection: AppLocaleController.instance.textDirection,
      child: Container(
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
                          '$displaySockName (${trBi("مخرج", "Outlet")} ${_sock.index})',
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
                iconColor: AppColors.emeraldActive,
                title: _sock.isFavorite
                    ? trBi('إزالة من المفضلة', 'Remove from Favorites')
                    : trBi('إضافة إلى المفضلة', 'Add to Favorites'),
                subtitle: trBi('الوصول السريع للمخرج من تبويب المفضلة', 'Quick access from the Favorites tab'),
                onTap: () async {
                  final next = !_sock.isFavorite;
                  setState(() => _sock = _sock.copyWith(isFavorite: next));
                  await _applyPatch(
                    {'is_favorite': next},
                    successMsg: next
                        ? trBi('تمت إضافة "$displaySockName" إلى المفضلة ⭐', 'Added "$displaySockName" to Favorites ⭐')
                        : trBi('تمت إزالة "$displaySockName" من المفضلة', 'Removed "$displaySockName" from Favorites'),
                  );
                  if (mounted) Navigator.pop(context);
                },
              ),

              // 2. Rename Outlet
              _buildMenuRow(
                icon: Icons.edit_outlined,
                iconColor: AppColors.emeraldActive,
                title: trBi('تغيير اسم وأيقونة المخرج', 'Rename Outlet & Change Icon'),
                subtitle: displaySockName,
                onTap: _openRenameModal,
              ),

              // 3. Outlet Colour (6 Colors)
              _buildMenuRow(
                icon: Icons.palette_outlined,
                iconColor: activeColor,
                title: trBi('لون المخرج (Outlet colour)', 'Outlet Color'),
                subtitle: trBi('اختر من 6 ألوان مميزة لحالة التشغيل', 'Choose from 6 signature active colors'),
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
                title: trBi('جدولة المخرج والمؤقت بالثواني', 'Outlet Schedule & Second Timer'),
                subtitle: _sock.autoOffDelaySec != null && _sock.autoOffDelaySec! > 0
                    ? trBi('إطفاء تلقائي مفعل بعد ${_sock.autoOffDelaySec} ثانية', 'Auto-off active after ${_sock.autoOffDelaySec}s')
                    : trBi('جدول زمني • مؤقت بالثواني/الدقائق • دورة • إطفاء تلقائي', 'Daily schedule • Sec/Min timer • Cycle • Auto-off'),
                onTap: _openOutletScheduleModal,
              ),

              // 5. Watt Limits & Alert
              _buildMenuRow(
                icon: Icons.bolt_rounded,
                iconColor: AppColors.emeraldActive,
                title: trBi('حدود الواط والتنبيه (Watt limits)', 'Watt Limits & Alerts'),
                subtitle: trBi(
                  'أقصى سحب: ${_sock.maxWattLimit.toInt()}W'
                  '${_sock.minWattCutoff != null ? " • فصل خمول < ${_sock.minWattCutoff}W" : ""}'
                  '${_sock.alertWattThreshold != null ? " • تنبيه عند ${_sock.alertWattThreshold!.toInt()}W" : ""}',
                  'Max: ${_sock.maxWattLimit.toInt()}W'
                  '${_sock.minWattCutoff != null ? " • Idle < ${_sock.minWattCutoff}W" : ""}'
                  '${_sock.alertWattThreshold != null ? " • Alert @ ${_sock.alertWattThreshold!.toInt()}W" : ""}',
                ),
                onTap: _openWattLimitsModal,
              ),

              // 6. Restart Outlet (OFF 5s -> ON)
              _buildMenuRow(
                icon: Icons.restart_alt_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: trBi('إعادة تشغيل المخرج (Restart — 5 ثوانٍ)', 'Restart Outlet (5s Power Cycle)'),
                subtitle: trBi('يفصل التيار 5 ثوانٍ ثم يعيد التشغيل تلقائياً في السيرفر', 'Cuts power for 5 seconds then turns back ON automatically'),
                onTap: () async {
                  Navigator.pop(context);
                  final res = await _repo.restartSocket(widget.stripMac, _sock.index);
                  widget.onSaved();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? trBi('جاري إعادة تشغيل المخرج...', 'Restarting outlet...')),
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
                title: trBi('ربط في مجموعة (Link group)', 'Link Group Sync'),
                subtitle: _sock.linkGroup > 0
                    ? trBi('مربوط حالياً في مجموعة #${_sock.linkGroup} (🔗${_sock.linkGroup})', 'Linked in Group #${_sock.linkGroup} (🔗${_sock.linkGroup})')
                    : trBi('غير مربوط بمجموعة', 'Not linked to a group'),
                onTap: _openLinkGroupModal,
              ),

              // 8. Doorbell Mode
              _buildMenuRow(
                icon: Icons.notifications_active_rounded,
                iconColor: const Color(0xFFF97316),
                title: trBi('وضع الجرس اللحظي (Doorbell mode)', 'Momentary Doorbell Mode'),
                subtitle: _sock.doorbellMode
                    ? trBi('مفعل (نبضة ${_sock.doorbellPulseSec} ثوانٍ ثم إطفاء)', 'Active (${_sock.doorbellPulseSec}s pulse then OFF)')
                    : trBi('غير مفعل', 'Disabled'),
                onTap: _openDoorbellModal,
              ),

              // 9. Per-Outlet Lock (PIN/Biometric + Individual Child Lock)
              _buildMenuRow(
                icon: _sock.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                iconColor: _sock.isLocked ? const Color(0xFFF59E0B) : Colors.grey,
                title: _sock.isLocked
                    ? trBi('فتح قفل المخرج وإلغاء قفل الأطفال الفردي 🔓', 'Unlock Outlet & Disable Individual Child Guard 🔓')
                    : trBi('قفل المخرج بالبصمة/PIN + قفل الأطفال الفردي 🔒', 'Lock Outlet (PIN/Biometrics + Child Guard) 🔒'),
                subtitle: _sock.isLocked
                    ? trBi('مقفول حالياً — محمي بالبصمة/PIN وضد أزرار المشترك الفيزيائية', 'Locked — Protected by PIN/Biometrics & physical button Child Guard')
                    : trBi('طلب البصمة/PIN عند التبديل ومنع الأطفال من فصله من زر المشترك', 'Require PIN/Biometrics to switch & block physical button presses'),
                trailing: Switch(
                  value: _sock.isLocked,
                  activeColor: const Color(0xFFF59E0B),
                  onChanged: (_) => _toggleOutletLockWithAuth(isDark),
                ),
                onTap: () => _toggleOutletLockWithAuth(isDark),
              ),

              // 10. Pin Current State
              _buildMenuRow(
                icon: Icons.push_pin_rounded,
                iconColor: _sock.isPinnedState ? AppColors.dangerRed : Colors.grey,
                title: _sock.isPinnedState
                    ? trBi('إلغاء تثبيت الحالة (Unpin state)', 'Unpin Outlet State')
                    : trBi('تثبيت الحالة الحالية (Pin current state)', 'Pin Current State'),
                subtitle: _sock.isPinnedState
                    ? trBi('المخرج مثبّت حالياً وممنوع تغييره يدوياً أو من التطبيق', 'Outlet state is pinned and locked against changes')
                    : trBi('منع تشغيل أو إطفاء المخرج نهائياً حتى إلغاء التثبيت', 'Prevent turning ON or OFF until unpinned'),
                trailing: Switch(
                  value: _sock.isPinnedState,
                  activeColor: AppColors.emeraldActive,
                  onChanged: (val) async {
                    setState(() => _sock = _sock.copyWith(isPinnedState: val));
                    await _applyPatch(
                      {'is_pinned_state': val},
                      successMsg: val
                          ? trBi('تم تثبيت حالة "$displaySockName" الحالية 📌', 'Pinned "$displaySockName" current state 📌')
                          : trBi('تم إلغاء تثبيت حالة "$displaySockName"', 'Unpinned "$displaySockName" state'),
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
                        ? trBi('تم تثبيت حالة "$displaySockName" الحالية 📌', 'Pinned "$displaySockName" current state 📌')
                        : trBi('تم إلغاء تثبيت حالة "$displaySockName"', 'Unpinned "$displaySockName" state'),
                  );
                  if (mounted) Navigator.pop(context);
                },
              ),

              // 11. Router Protection Toggle
              _buildMenuRow(
                icon: Icons.router_rounded,
                iconColor: _sock.isRouter ? AppColors.routerCyan : Colors.grey,
                title: trBi('حماية الراوتر (استثناء من إيقاف الكل وفصل الفولت)', 'Router Protection (Exempt from Master Off & Voltage Trip)'),
                subtitle: _sock.isRouter
                    ? trBi('مفعل — محمي من الفصل الشامل', 'Active — Exempt from Master Off')
                    : trBi('غير مفعل', 'Disabled'),
                trailing: Switch(
                  value: _sock.isRouter,
                  activeColor: AppColors.routerCyan,
                  onChanged: (val) async {
                    setState(() => _sock = _sock.copyWith(isRouter: val));
                    await _applyPatch(
                      {'is_router': val},
                      successMsg: val
                          ? trBi('تم تفعيل حماية الراوتر لهذا المخرج 🌐', 'Router protection enabled 🌐')
                          : trBi('تم إلغاء وضع الراوتر', 'Router protection disabled'),
                    );
                    if (mounted) Navigator.pop(context);
                  },
                ),
                onTap: () async {
                  final val = !_sock.isRouter;
                  setState(() => _sock = _sock.copyWith(isRouter: val));
                  await _applyPatch(
                    {'is_router': val},
                    successMsg: val
                        ? trBi('تم تفعيل حماية الراوتر لهذا المخرج 🌐', 'Router protection enabled 🌐')
                        : trBi('تم إلغاء وضع الراوتر', 'Router protection disabled'),
                  );
                  if (mounted) Navigator.pop(context);
                },
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Quick Protection Presets Bar
              Text(
                trBi('🛡️ قوالب الحماية الذكية السريعة بضغطة واحدة:', '🛡️ 1-Tap Smart Appliance Protection Presets:'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: subColor),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPresetChip(trBi('❄️ ثلاجة', '❄️ Fridge'), 'fridge', isDark),
                    _buildPresetChip(trBi('🌬️ تكييف', '🌬️ AC'), 'ac', isDark),
                    _buildPresetChip(trBi('🌐 راوتر', '🌐 Router'), 'router', isDark),
                    _buildPresetChip(trBi('📱 شاحن ذكي', '📱 Charger'), 'charger', isDark),
                    _buildPresetChip(trBi('🔥 سخان', '🔥 Heater'), 'heater', isDark),
                    _buildPresetChip(trBi('💻 كمبيوتر', '💻 PC'), 'pc', isDark),
                  ],
                ),
              ),
            ],
          ),
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
    final isDark = AppThemeController.instance.isDark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
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
      title: Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: textColor)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: subColor)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildPresetChip(String label, String key, bool isDark) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        backgroundColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: textColor)),
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
    final isDark = AppThemeController.instance.isDark;
    final displaySockName = trOutletName(widget.socket.name, widget.socket.index);
    return Directionality(
      textDirection: AppLocaleController.instance.textDirection,
      child: Container(
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
                Expanded(
                  child: Text(
                    trBi('🕒 جدولة ومؤقت — $displaySockName', '🕒 Schedule & Timer — $displaySockName'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.emeraldActive,
              indicatorColor: AppColors.emeraldActive,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              tabs: [
                Tab(text: trBi('جدول يومي', 'Daily')),
                Tab(text: trBi('مؤقت ذكي', 'Timer')),
                Tab(text: trBi('دورة ترددية', 'Cycle')),
                Tab(text: trBi('إطفاء تلقائي', 'Auto-Off')),
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
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                trBi('الجداول والمؤقتات المسجلة لهذا المخرج (${_schedules.length}):', 'Registered schedules & timers for this outlet (${_schedules.length}):'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 115,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldActive))
                  : _schedules.isEmpty
                      ? Center(
                          child: Text(
                            trBi('لا توجد جداول مسجلة حالياً', 'No schedules registered yet'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )
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
                                '${sc.scheduleType} → ${sc.targetState ? trBi("تشغيل", "ON") : trBi("إيقاف", "OFF")}'
                                '${sc.holdState ? " 🔒" : ""}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                sc.cronExpression ??
                                    (sc.durationSec != null ? trBi('المدة: ${sc.durationSec} ثانية', 'Duration: ${sc.durationSec}s') : '') +
                                        (sc.autoOffDelaySec != null ? trBi('إطفاء بعد: ${sc.autoOffDelaySec} ثانية', 'Auto-off: ${sc.autoOffDelaySec}s') : ''),
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
            title: Text(trBi('وقت التنفيذ اليومي:', 'Daily Execution Time:'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
              Text(trBi('الإجراء المطلوب:', 'Target Action:'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text(trBi('تشغيل (ON)', 'Turn ON')),
                selected: _cronTargetOn,
                selectedColor: AppColors.emeraldActive.withOpacity(0.2),
                onSelected: (_) => setState(() => _cronTargetOn = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(trBi('إيقاف (OFF)', 'Turn OFF')),
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
            title: Text(trBi('🔒 تثبيت حالة الجدولة (Hold state)', '🔒 Hold Scheduled State'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            subtitle: Text(trBi('منع التغيير اليدوي أثناء سريان الجدول', 'Prevent manual changes while schedule is active'), style: const TextStyle(fontSize: 11)),
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
              label: Text(trBi('إضافة الجدول الزمني', 'Add Daily Schedule'), style: const TextStyle(fontWeight: FontWeight.w900)),
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
                    labelText: _timerInSeconds ? trBi('المدة بالثواني', 'Duration in Seconds') : trBi('المدة بالدقائق', 'Duration in Minutes'),
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
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(trBi('دقائق', 'Min'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(trBi('ثواني', 'Sec'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(trBi('الإجراء عند انتهاء المؤقت:', 'Action when timer ends:'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              const SizedBox(width: 10),
              ChoiceChip(
                label: Text(trBi('إيقاف (OFF)', 'Turn OFF')),
                selected: !_timerTargetOn,
                selectedColor: AppColors.dangerRed.withOpacity(0.2),
                onSelected: (_) => setState(() => _timerTargetOn = false),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: Text(trBi('تشغيل (ON)', 'Turn ON')),
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
              label: Text(trBi('بدء المؤقت التنازلي الآن', 'Start Countdown Timer Now'), style: const TextStyle(fontWeight: FontWeight.w900)),
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
              Text(trBi('وحدة دورة التشغيل والإيقاف:', 'Cycle Time Unit:'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ToggleButtons(
                isSelected: [!_cycleInSeconds, _cycleInSeconds],
                borderRadius: BorderRadius.circular(10),
                constraints: const BoxConstraints(minHeight: 32, minWidth: 58),
                selectedColor: Colors.white,
                fillColor: AppColors.emeraldActive,
                onPressed: (idx) => setState(() => _cycleInSeconds = (idx == 1)),
                children: [
                  Text(trBi('دقائق', 'Min'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                  Text(trBi('ثواني', 'Sec'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
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
                    labelText: trBi('مدة التشغيل (ON)', 'ON Duration'),
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
                    labelText: trBi('مدة الإيقاف (OFF)', 'OFF Duration'),
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
              label: Text(trBi('تفعيل الدورة الترددية', 'Activate Repeating Cycle'), style: const TextStyle(fontWeight: FontWeight.w900)),
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
          Text(
            trBi(
              'ينطفئ المخرج تلقائياً في كل مرة يتم تشغيله فيها بعد المدة المحددة:',
              'Automatically turns OFF this outlet after the specified duration every time it is switched ON:',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _autoOffCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _autoOffInSeconds
                        ? trBi('مهلة الإطفاء التلقائي (ثواني)', 'Auto-off delay (Seconds)')
                        : trBi('مهلة الإطفاء التلقائي (دقائق)', 'Auto-off delay (Minutes)'),
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
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(trBi('دقائق', 'Min'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(trBi('ثواني', 'Sec'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
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
                child: Text(trBi('إلغاء الإطفاء التلقائي', 'Disable Auto-Off')),
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
                  label: Text(trBi('حفظ الإطفاء التلقائي', 'Save Auto-Off'), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

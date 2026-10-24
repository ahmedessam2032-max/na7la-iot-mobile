import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/strip_model.dart';
import '../../data/repositories/strip_repository.dart';

class ProtectionScreen extends StatefulWidget {
  final StripModel strip;
  final bool isDark;

  const ProtectionScreen({
    super.key,
    required this.strip,
    required this.isDark,
  });

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen> {
  final _repo = StripRepository();
  late double _minVoltage;
  late double _maxVoltage;
  late bool _voltageProtectEnabled;
  late bool _autoRecoverVoltage;
  late int _voltageRecoverDelaySec;
  late Set<int> _exemptSockets;
  late String _powerReturnState;
  late double _maxTotalWatt;
  late int _maxTempC;
  late bool _autoShedding;
  late bool _biometricControl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _minVoltage = widget.strip.minVoltage.clamp(150.0, 220.0);
    _maxVoltage = widget.strip.maxVoltage.clamp(230.0, 280.0);
    _voltageProtectEnabled = widget.strip.voltageProtectEnabled;
    _autoRecoverVoltage = widget.strip.autoRecoverVoltage;
    _voltageRecoverDelaySec = widget.strip.voltageRecoverDelaySec;
    _exemptSockets = widget.strip.voltageExemptSockets
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toSet();
    _powerReturnState = widget.strip.powerReturnState.isNotEmpty
        ? widget.strip.powerReturnState
        : 'LAST';
    _maxTotalWatt = widget.strip.maxTotalWatt.clamp(500.0, 3800.0);
    _maxTempC = widget.strip.maxTempC.clamp(50, 95);
    _autoShedding = widget.strip.autoSheddingEnabled;
    _biometricControl = widget.strip.biometricControl;
  }

  Future<void> _saveAllProtection() async {
    setState(() => _isSaving = true);
    final exemptStr = (_exemptSockets.toList()..sort()).join(',');
    final ok = await _repo.updateProtection(widget.strip.macAddress, {
      'min_voltage': _minVoltage,
      'max_voltage': _maxVoltage,
      'voltage_protect_enabled': _voltageProtectEnabled,
      'auto_recover_voltage': _autoRecoverVoltage,
      'voltage_recover_delay_sec': _voltageRecoverDelaySec,
      'voltage_exempt_sockets': exemptStr,
      'power_return_state': _powerReturnState,
      'max_total_watt': _maxTotalWatt,
      'max_temp_c': _maxTempC,
      'auto_shedding_enabled': _autoShedding,
      'biometric_control': _biometricControl,
    });
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      widget.strip.minVoltage = _minVoltage;
      widget.strip.maxVoltage = _maxVoltage;
      widget.strip.voltageProtectEnabled = _voltageProtectEnabled;
      widget.strip.autoRecoverVoltage = _autoRecoverVoltage;
      widget.strip.voltageRecoverDelaySec = _voltageRecoverDelaySec;
      widget.strip.voltageExemptSockets = exemptStr;
      widget.strip.powerReturnState = _powerReturnState;
      widget.strip.maxTotalWatt = _maxTotalWatt;
      widget.strip.maxTempC = _maxTempC;
      widget.strip.autoSheddingEnabled = _autoShedding;
      widget.strip.biometricControl = _biometricControl;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛡️ تم حفظ وتطبيق إعدادات الحماية وحدود المشترك على السيرفر والهاردوير بنجاح'),
          backgroundColor: AppColors.emeraldPrimary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ فشل حفظ إعدادات الحماية، تحقق من الاتصال'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = widget.isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight;
    final mutedBg = widget.isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight;
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حدود الواط والفولت والحماية الذكية 🛡️',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary),
              ),
              Text(
                widget.strip.stripName,
                style: GoogleFonts.cairo(fontSize: 11, color: textSecondary),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emeraldPrimary),
                  ),
                  child: Text(
                    '⚡ ${widget.strip.voltage.toStringAsFixed(0)}V',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.emeraldPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Voltage Protection Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cleanCardDecoration(isDark: widget.isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🛡️ حارس الجهد الكهربائي (Voltage Guard)',
                                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: textPrimary),
                              ),
                              Text(
                                'فصل المخارج تلقائياً عند خروج فولت الكهرباء عن النطاق الآمن (عدد مرات الفصل: ${widget.strip.voltageBreachCount})',
                                style: GoogleFonts.cairo(fontSize: 10.5, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _voltageProtectEnabled,
                          activeColor: AppColors.emeraldPrimary,
                          onChanged: (v) => setState(() => _voltageProtectEnabled = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mutedBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الحد الأدنى للفصل (Low Cut-off):',
                                style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                              ),
                              Text(
                                '${_minVoltage.round()} V',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.emeraldPrimary,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _minVoltage,
                            min: 150,
                            max: 220,
                            divisions: 70,
                            activeColor: AppColors.emeraldPrimary,
                            onChanged: _voltageProtectEnabled ? (val) => setState(() => _minVoltage = val) : null,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الحد الأقصى للفصل (High Cut-off):',
                                style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                              ),
                              Text(
                                '${_maxVoltage.round()} V',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.warningAmber,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _maxVoltage,
                            min: 230,
                            max: 280,
                            divisions: 50,
                            activeColor: AppColors.warningAmber,
                            onChanged: _voltageProtectEnabled ? (val) => setState(() => _maxVoltage = val) : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Voltage Exempt Outlets
                    Text(
                      'استثناء مخارج من فصل الجهد (تبقى تعمل حتى لو تذبذب الجهد):',
                      style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.strip.sockets.map((s) {
                        final isEx = _exemptSockets.contains(s.socketIndex);
                        return FilterChip(
                          selected: isEx,
                          selectedColor: AppColors.emeraldPrimary.withOpacity(0.2),
                          checkmarkColor: AppColors.emeraldPrimary,
                          backgroundColor: mutedBg,
                          label: Text(
                            '#${s.socketIndex} ${s.name}',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isEx ? AppColors.emeraldPrimary : textPrimary,
                            ),
                          ),
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _exemptSockets.add(s.socketIndex);
                              } else {
                                _exemptSockets.remove(s.socketIndex);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: borderColor),

                    // Auto Recover Voltage
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '🔄 إعادة التشغيل التلقائي عند استقرار الجهد',
                        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: textPrimary),
                      ),
                      subtitle: Text(
                        'يعيد تشغيل المخارج المفصولة تلقائياً بعد عودة الفولت للنطاق الآمن',
                        style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                      ),
                      value: _autoRecoverVoltage,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (v) => setState(() => _autoRecoverVoltage = v),
                    ),
                    if (_autoRecoverVoltage) ...[
                      Text(
                        'مهلة التأخير قبل إعادة التشغيل (لحماية الكمبروسر):',
                        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [5, 15, 30, 60, 180].map((sec) {
                          final isSel = _voltageRecoverDelaySec == sec;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _voltageRecoverDelaySec = sec),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.emeraldPrimary : mutedBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSel ? AppColors.emeraldPrimary : borderColor),
                                ),
                                child: Text(
                                  sec >= 60 ? '${sec ~/ 60} د' : '$sec ث',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
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
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Power Return State & Overload Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cleanCardDecoration(isDark: widget.isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔌 حالة المشترك بعد انقطاع وعودة الكهرباء (Power Return)',
                      style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w900, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اختر ماذا يفعل المشترك بالمخارج عند عودة التيار الكهربائي:',
                      style: GoogleFonts.cairo(fontSize: 10.5, color: textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildReturnStateChip('LAST', 'آخر حالة 🔄', textPrimary, mutedBg, borderColor),
                        const SizedBox(width: 8),
                        _buildReturnStateChip('ON', 'تشغيل الكل ⚡', textPrimary, mutedBg, borderColor),
                        const SizedBox(width: 8),
                        _buildReturnStateChip('OFF', 'إيقاف الكل ⏻', textPrimary, mutedBg, borderColor),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: borderColor),
                    const SizedBox(height: 8),

                    // Max Total Watt
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '⚡ الحد الأقصى لقدرة المشترك الإجمالية:',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: textPrimary),
                        ),
                        Text(
                          '${_maxTotalWatt.round()} W',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _maxTotalWatt,
                      min: 500,
                      max: 3800,
                      divisions: 33,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (v) => setState(() => _maxTotalWatt = v),
                    ),

                    // Max Temp C
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🌡️ فصل الأمان الحراري للوحة المشترك:',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: textPrimary),
                        ),
                        Text(
                          '$_maxTempC °C',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dangerRed,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _maxTempC.toDouble(),
                      min: 50,
                      max: 95,
                      divisions: 45,
                      activeColor: AppColors.dangerRed,
                      onChanged: (v) => setState(() => _maxTempC = v.round()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Smart Load Shedding & Biometric Control
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cleanCardDecoration(isDark: widget.isDark),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '🚨 إسقاط الأحمال الذكي التدريجي (Smart Load Shedding)',
                        style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary),
                      ),
                      subtitle: Text(
                        'فصل أعلى مخرج استهلاكاً تلقائياً عند تجاوز الحمل الكلي بدلاً من فصل المشترك بالكامل (مع حماية الراوتر)',
                        style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                      ),
                      value: _autoShedding,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (v) => setState(() => _autoShedding = v),
                    ),
                    Divider(color: borderColor),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '🔐 اشتراط البصمة / PIN للتحكم في المشترك',
                        style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w900, color: textPrimary),
                      ),
                      subtitle: Text(
                        'طلب تأكيد البصمة أو رمز PIN قبل إيقاف أو تعديل إعدادات هذا المشترك',
                        style: GoogleFonts.cairo(fontSize: 10, color: textSecondary),
                      ),
                      value: _biometricControl,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (v) => setState(() => _biometricControl = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAllProtection,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: Text(
                    'حفظ وتطبيق جميع إعدادات الحماية على الهاردوير',
                    style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnStateChip(
    String value,
    String label,
    Color textPrimary,
    Color mutedBg,
    Color borderColor,
  ) {
    final isSel = _powerReturnState == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _powerReturnState = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSel ? AppColors.emeraldPrimary : mutedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? AppColors.emeraldPrimary : borderColor),
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isSel ? Colors.white : textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

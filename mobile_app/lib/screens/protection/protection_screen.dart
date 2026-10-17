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
  late bool _autoShedding;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _minVoltage = widget.strip.minVoltage;
    _maxVoltage = widget.strip.maxVoltage;
    _voltageProtectEnabled = widget.strip.voltageProtectEnabled;
    _autoShedding = widget.strip.autoSheddingEnabled;
  }

  Future<void> _updateProtectionSettings() async {
    setState(() => _isSaving = true);
    await _repo.updateProtection(widget.strip.macAddress, {
      'min_voltage': _minVoltage,
      'max_voltage': _maxVoltage,
      'voltage_protect_enabled': _voltageProtectEnabled,
      'auto_shedding_enabled': _autoShedding,
    });
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات الحماية بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Voltage Guard Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.inkCardDecoration(isDark: widget.isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🛡️ حارس الجهد الكهربائي (Voltage Guard)',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'الجهد: ${widget.strip.currentVoltage?.toStringAsFixed(0) ?? 224}V',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'فصل المخارج تلقائياً إذا خرجت كهرباء الحكومة عن النطاق الآمن:',
                  style: GoogleFonts.cairo(fontSize: 10, color: widget.isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 14),

                // Sliders Container
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.isDark ? AppColors.cardMutedDark : AppColors.inkBlack,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الحد الأدنى للفصل (Low Cut-off):',
                              style: GoogleFonts.cairo(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                          Text('${_minVoltage.round()} V',
                              style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.honeyYellow, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Slider(
                        value: _minVoltage,
                        min: 160,
                        max: 200,
                        divisions: 40,
                        activeColor: AppColors.honeyYellow,
                        onChanged: (val) => setState(() => _minVoltage = val),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الحد الأقصى للفصل (High Cut-off):',
                              style: GoogleFonts.cairo(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                          Text('${_maxVoltage.round()} V',
                              style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.honeyAmber, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Slider(
                        value: _maxVoltage,
                        min: 235,
                        max: 270,
                        divisions: 35,
                        activeColor: AppColors.honeyAmber,
                        onChanged: (val) => setState(() => _maxVoltage = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _updateProtectionSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.honeyAmber,
                    foregroundColor: AppColors.inkBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.inkBlack, width: 2),
                    ),
                  ),
                  child: Text('حفظ حدود الجهد الآمن', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Staggered Boot Sequence Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.inkCardDecoration(isDark: widget.isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⏱️ ترتيب الإقلاع المتتابع بعد عودة النور',
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                Text(
                  'حماية الكمبريسور وتفادي تيار البدء العالي (Inrush Current):',
                  style: GoogleFonts.cairo(fontSize: 10, color: widget.isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 12),
                _buildTimelineItem('🌐 راوتر الإنترنت', '00:00 (فوراً)', AppColors.routerCyan),
                _buildTimelineItem('📱 شاحن الموبايل', '+ 00:05 ثوانٍ', AppColors.honeyYellow),
                _buildTimelineItem('❄️ تلاجة المطبخ', '+ 03:00 دقائق (كمبريسور)', AppColors.honeyAmber),
                _buildTimelineItem('🌀 تكييف الصالة', '+ 05:00 دقائق (كمبريسور)', Colors.redAccent),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Overload Shedding & Scenes
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.inkCardDecoration(isDark: widget.isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '🚨 تخفيف الأحمال الذكي (Load Shedding)',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'فصل أعلى مخرج استهلاكاً إذا تخطى السحب 16A مع بقاء الراوتر',
                    style: GoogleFonts.cairo(fontSize: 10),
                  ),
                  value: _autoShedding,
                  activeColor: AppColors.honeyAmber,
                  onChanged: (val) {
                    setState(() => _autoShedding = val);
                    _updateProtectionSettings();
                  },
                ),
                const Divider(),
                Text(
                  '🎬 السيناريوهات السريعة (Smart Scenes):',
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSceneButton('🌙 وضع النوم'),
                    const SizedBox(width: 8),
                    _buildSceneButton('🎬 وضع السينما'),
                    const SizedBox(width: 8),
                    _buildSceneButton('🚪 خارج المنزل'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(time, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneButton(String title) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم تفعيل $title')),
          );
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          side: const BorderSide(color: AppColors.inkBlack, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(title, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

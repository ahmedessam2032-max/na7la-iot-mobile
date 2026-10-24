import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/file_downloader_service.dart';
import '../../data/models/strip_model.dart';
import '../../data/repositories/strip_repository.dart';

class EnergyAnalyticsScreen extends StatefulWidget {
  final StripModel strip;
  final bool? isDark;

  const EnergyAnalyticsScreen({
    super.key,
    required this.strip,
    this.isDark,
  });

  @override
  State<EnergyAnalyticsScreen> createState() => _EnergyAnalyticsScreenState();
}

class _EnergyAnalyticsScreenState extends State<EnergyAnalyticsScreen> {
  final StripRepository _repo = StripRepository();
  String _period = 'day'; // day | week | month
  String _tariffMode = 'TIERS'; // TIERS | FLAT
  double _flatRate = 1.45;
  bool _loading = true;
  bool _exporting = false;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    final data = await _repo.getEnergyStats(
      widget.strip.mac,
      period: _period,
      tariffMode: _tariffMode,
      flatRate: _flatRate,
    );
    if (!mounted) return;
    setState(() {
      if (data['ok'] == true) {
        _stats = data;
        _tariffMode = (data['tariff_mode'] ?? _tariffMode).toString();
        _flatRate = ((data['flat_rate_egp'] ?? _flatRate) as num).toDouble();
      }
      _loading = false;
    });
  }

  String _formatDuration(int sec) {
    if (sec < 60) return '$sec ث';
    final hrs = sec ~/ 3600;
    final mins = (sec % 3600) ~/ 60;
    if (hrs > 0) return '${hrs}س ${mins}د';
    return '$mins دقيقة';
  }

  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $hh:$mm';
  }

  void _openEditFlatRateDialog() {
    final ctrl = TextEditingController(text: _flatRate.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚙️ تعديل سعر الكيلوواط الموحد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'السعر بالجنيه لكل كيلوواط/ساعة',
            suffixText: 'ج.م / kWh',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldActive, foregroundColor: Colors.white),
            onPressed: () async {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                setState(() {
                  _flatRate = val;
                  _tariffMode = 'FLAT';
                });
                await _repo.updateUserPreferences({'electricity_rate_egp': val, 'tariff_mode': 'FLAT'});
                await _fetchStats();
              }
            },
            child: const Text('حفظ وتطبيق', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalKwh = ((_stats['total_kwh'] ?? widget.strip.totalKwh) as num).toDouble();
    final peakWatt = ((_stats['peak_watt'] ?? widget.strip.totalWatt) as num).toDouble();
    final currentWatt = ((_stats['current_watt'] ?? widget.strip.totalWatt) as num).toDouble();
    final tiersCost = ((_stats['tiers_cost_egp'] ?? 0.0) as num).toDouble();
    final flatCost = ((_stats['flat_cost_egp'] ?? widget.strip.totalCostEgp) as num).toDouble();
    final activeCost = _tariffMode == 'TIERS' ? tiersCost : flatCost;
    final chartBars = (_stats['chart_bars'] as List?) ?? [];
    final outlets = (_stats['outlets'] as List?) ?? [];
    final runLog = (_stats['run_log'] as List?) ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkOuter : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 مراقب الاستهلاك وتقرير الطاقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text(widget.strip.name, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _fetchStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.emeraldActive,
        onRefresh: _fetchStats,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // 1. Period Selector: Day / Week / Month
            Container(
              padding: const EdgeInsets.all(4),
              decoration: AppTheme.inkCardDecoration(isDark: isDark, radius: 14),
              child: Row(
                children: [
                  _buildPeriodTab('day', 'اليوم (Day)', isDark),
                  _buildPeriodTab('week', 'الأسبوع (Week)', isDark),
                  _buildPeriodTab('month', 'الشهر (Month)', isDark),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Hero 3-KPI Card (kWh | Peak W | Active Cost EGP)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldActive.withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildHeroMetric('الاستهلاك', '${totalKwh.toStringAsFixed(3)} kWh', Icons.electric_meter_rounded),
                  Container(width: 1, height: 38, color: Colors.white24),
                  _buildHeroMetric('أقصى سحب (Peak)', '${peakWatt.toStringAsFixed(1)} W', Icons.bolt_rounded),
                  Container(width: 1, height: 38, color: Colors.white24),
                  _buildHeroMetric('التكلفة المقدرة', '${activeCost.toStringAsFixed(2)} ج.م', Icons.payments_rounded),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Egyptian Tiers vs Flat Rate Calculator Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.inkCardDecoration(isDark: isDark, radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🧮 طريقة حساب الفاتورة (شرائح مصر / سعر موحد)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                      TextButton.icon(
                        onPressed: _openEditFlatRateDialog,
                        icon: const Icon(Icons.edit_rounded, size: 15, color: AppColors.emeraldActive),
                        label: Text('${_flatRate.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.emeraldActive)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTariffModeCard(
                          mode: 'TIERS',
                          title: '🇪🇬 الشرائح المصرية',
                          subtitle: 'حساب تصاعدي رسمي (7 شرائح)',
                          cost: tiersCost,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTariffModeCard(
                          mode: 'FLAT',
                          title: '💵 سعر موحد ثابت',
                          subtitle: '${_flatRate.toStringAsFixed(2)} ج.م لكل kWh',
                          cost: flatCost,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Bar Chart Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.inkCardDecoration(isDark: isDark, radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('📈 منحنى الاستهلاك الزمني (kWh)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'الآن: ${currentWatt.toStringAsFixed(1)} W',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.emeraldActive),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: AppColors.emeraldActive)))
                  else
                    SizedBox(
                      height: 145,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: chartBars.map((b) {
                          final val = ((b['kwh'] ?? 0.0) as num).toDouble();
                          final maxBar = chartBars
                              .map((e) => ((e['kwh'] ?? 0.0) as num).toDouble())
                              .fold<double>(0.1, (prev, el) => el > prev ? el : prev);
                          final ratio = (val / (maxBar <= 0 ? 1.0 : maxBar)).clamp(0.08, 1.0);
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                val.toStringAsFixed(val < 0.1 && val > 0 ? 2 : 1),
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 26,
                                height: 92 * ratio,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.emeraldActive, AppColors.emeraldDeep],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (b['label'] ?? '').toString(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Per-Outlet Breakdown (حسب المخرج)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.inkCardDecoration(isDark: isDark, radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔌 توزيع الاستهلاك حسب المخرج (By Outlet)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  ...outlets.map((o) {
                    final name = (o['name'] ?? 'مقبس').toString();
                    final kwh = ((o['kwh'] ?? 0.0) as num).toDouble();
                    final pct = ((o['percentage'] ?? 0.0) as num).toDouble();
                    final curW = ((o['current_watt'] ?? 0.0) as num).toDouble();
                    final cost = _tariffMode == 'TIERS'
                        ? ((o['tiers_cost_egp'] ?? 0.0) as num).toDouble()
                        : ((o['flat_cost_egp'] ?? 0.0) as num).toDouble();
                    final color = AppColors.parseHexColor(o['color_hex']?.toString());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 6),
                                  Text('(${curW.toStringAsFixed(1)}W)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '${kwh.toStringAsFixed(3)} kWh • ${cost.toStringAsFixed(2)} EGP (${pct.toStringAsFixed(0)}%)',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (pct / 100.0).clamp(0.02, 1.0),
                              minHeight: 7,
                              color: color,
                              backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 6. Run Log — Last 30 Days (سجل جلسات التشغيل — آخر 30 يوماً)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.inkCardDecoration(isDark: isDark, radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🕒 سجل جلسات التشغيل (Run log — آخر 30 يوماً)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      Text('${runLog.length} جلسة', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.emeraldActive)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (runLog.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('لا توجد جلسات مسجلة بعد، ستظهر فور تشغيل أي مخرج', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    )
                  else
                    ...runLog.take(25).map((ss) {
                      final isOpen = ss['is_open'] == true;
                      final sockName = (ss['socket_name'] ?? 'مقبس').toString();
                      final durSec = ((ss['duration_sec'] ?? 0) as num).toInt();
                      final kwhUsed = ((ss['kwh_used'] ?? 0.0) as num).toDouble();
                      final avgW = ((ss['avg_watt'] ?? 0.0) as num).toDouble();
                      final peakW = ((ss['peak_watt'] ?? 0.0) as num).toDouble();
                      final costEgp = ((ss['cost_egp'] ?? 0.0) as num).toDouble();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOpen ? AppColors.emeraldActive.withOpacity(0.45) : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isOpen ? Icons.play_circle_fill_rounded : Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: isOpen ? AppColors.emeraldActive : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(sockName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                                    if (isOpen) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.emeraldActive.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('يعمل الآن', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.emeraldActive)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  _formatDuration(durSec),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.emeraldActive),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_formatTimestamp(ss['started_at']?.toString())} ← ${isOpen ? "الآن" : _formatTimestamp(ss['ended_at']?.toString())}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    '${kwhUsed.toStringAsFixed(3)} kWh • avg ${avgW.toStringAsFixed(0)}W (max ${peakW.toStringAsFixed(0)}W) • ${costEgp.toStringAsFixed(2)} EGP',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
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
            ),
            const SizedBox(height: 16),

            // 7. Export Excel / CSV Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldActive,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _exporting
                    ? null
                    : () async {
                        setState(() => _exporting = true);
                        final res = await FileDownloaderService.downloadAndOpenEnergyCsv(widget.strip.mac);
                        if (!mounted) return;
                        setState(() => _exporting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'تم تصدير ملف الإكسل بنجاح'),
                            backgroundColor: res['success'] == true ? AppColors.emeraldActive : AppColors.dangerRed,
                          ),
                        );
                      },
                icon: _exporting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.table_view_rounded),
                label: const Text('تصدير التقرير الكامل إلى Excel (.CSV)', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(String key, String label, bool isDark) {
    final active = _period == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_period != key) {
            setState(() => _period = key);
            _fetchStats();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.emeraldActive : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMetric(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            value,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.88)),
        ),
      ],
    );
  }

  Widget _buildTariffModeCard({
    required String mode,
    required String title,
    required String subtitle,
    required double cost,
    required bool isDark,
  }) {
    final selected = _tariffMode == mode;
    return GestureDetector(
      onTap: () async {
        setState(() => _tariffMode = mode);
        await _repo.updateUserPreferences({'tariff_mode': mode});
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.emeraldActive.withOpacity(0.12)
              : (isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.emeraldActive : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
                if (selected) const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.emeraldActive),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              '${cost.toStringAsFixed(2)} ج.م',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: selected ? AppColors.emeraldActive : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

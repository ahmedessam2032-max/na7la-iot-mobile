import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../../core/services/file_downloader_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/localization/app_locale.dart';
import '../../data/models/strip_model.dart';

class EnergyAnalyticsScreen extends StatefulWidget {
  final StripModel strip;
  final bool isDark;

  const EnergyAnalyticsScreen({
    super.key,
    required this.strip,
    required this.isDark,
  });

  @override
  State<EnergyAnalyticsScreen> createState() => _EnergyAnalyticsScreenState();
}

class _EnergyAnalyticsScreenState extends State<EnergyAnalyticsScreen> {
  bool _isDownloading = false;
  double _tariffPrice = 1.45;

  @override
  void initState() {
    super.initState();
    SecureStorageService.getTariffPrice().then((p) {
      if (mounted) setState(() => _tariffPrice = p);
    });
  }

  Future<void> _downloadExcel() async {
    setState(() => _isDownloading = true);
    try {
      final token = await SecureStorageService.getToken();
      final url = '${ApiConstants.baseUrl}/strips/${widget.strip.macAddress}/export-energy';
      final res = await http.get(
        Uri.parse(url),
        headers: {if (token != null) 'X-Na7la-Token': token},
      );

      if (res.statusCode == 200) {
        final savedPath = await FileDownloaderService.saveBytes(
          res.bodyBytes,
          'Na7la_Energy_${widget.strip.macAddress}.xlsx',
        );

        if (mounted && savedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تنزيل ملف الإكسيل بنجاح في: $savedPath'),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل تنزيل ملف التقرير من السيرفر')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocaleController.instance;
    final double totalKwh = widget.strip.totalKwh;
    final double estimatedCost = totalKwh * _tariffPrice;
    final bg = widget.isDark ? AppColors.darkBg : AppColors.lightBg;
    final textPrimary = widget.isDark ? Colors.white : AppColors.inkBlack;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          locale.tr('analytics_title'),
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tier & Cost Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.inkCardDecoration(isDark: widget.isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.honeyAmber,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.inkBlack, width: 1.5),
                          ),
                          child: Text(
                            locale.tr('analytics_tier_current'),
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.inkBlack,
                            ),
                          ),
                        ),
                        Text(
                          '${estimatedCost.toStringAsFixed(1)} ${locale.tr('egp')}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.honeyAmber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      locale.tr('analytics_calc_title'),
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${locale.tr('analytics_cumulative')} ${totalKwh.toStringAsFixed(2)} kWh',
                          style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          locale.tr('analytics_tier_remaining'),
                          style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (totalKwh / 200.0).clamp(0.1, 1.0),
                        minHeight: 10,
                        backgroundColor: widget.isDark ? Colors.white12 : Colors.black12,
                        valueColor: const AlwaysStoppedAnimation(AppColors.honeyYellow),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weekly Energy Chart
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
                          locale.tr('analytics_weekly_chart'),
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.honeyYellow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.inkBlack, width: 1.5),
                          ),
                          child: Text(
                            locale.tr('analytics_weekly_badge'),
                            style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, _) {
                                  final days = locale.isArabic
                                      ? ['سبت', 'أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة']
                                      : ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
                                  if (val.toInt() >= 0 && val.toInt() < days.length) {
                                    return Text(days[val.toInt()], style: GoogleFonts.cairo(fontSize: 9));
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            _buildBar(0, 3.2),
                            _buildBar(1, 4.5),
                            _buildBar(2, 2.8),
                            _buildBar(3, 6.1, isPeak: true),
                            _buildBar(4, 3.9),
                            _buildBar(5, 5.2, isPeak: true),
                            _buildBar(6, 4.1),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locale.tr('analytics_peak_hours'),
                      style: GoogleFonts.cairo(fontSize: 10, color: widget.isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sockets Leaderboard & Excel Export
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.inkCardDecoration(isDark: widget.isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      locale.tr('analytics_leaderboard'),
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    ...widget.strip.sockets.map((s) {
                      final pct = totalKwh > 0 ? (s.rawEnergyKwh / totalKwh) : 0.25;
                      final sName = locale.isArabic
                          ? s.name
                          : (s.isRouter ? locale.tr('outlet_router') : s.name.replaceAll('مقبس', locale.tr('socket_prefix')));
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(sName, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                                Text(
                                  '${(pct * 100).toStringAsFixed(0)}% (${(s.rawEnergyKwh * _tariffPrice).toStringAsFixed(1)} ${locale.tr('egp')})',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: pct.clamp(0.05, 1.0),
                              minHeight: 6,
                              backgroundColor: widget.isDark ? Colors.white12 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation(s.isRouter ? AppColors.routerCyan : AppColors.honeyAmber),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _isDownloading ? null : _downloadExcel,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkBlack),
                            )
                          : const Icon(Icons.table_chart_rounded, size: 18),
                      label: Text(
                        locale.tr('analytics_export_btn'),
                        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _buildBar(int x, double y, {bool isPeak = false}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isPeak ? AppColors.honeyAmber : AppColors.honeyYellow,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          borderSide: const BorderSide(color: AppColors.inkBlack, width: 1.5),
        ),
      ],
    );
  }
}

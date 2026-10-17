import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

class HoneyJarGauge extends StatelessWidget {
  final double currentWatts;
  final double maxWatts;
  final bool isDark;

  const HoneyJarGauge({
    super.key,
    required this.currentWatts,
    this.maxWatts = 1800.0,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage = (currentWatts / maxWatts).clamp(0.05, 0.95);
    final int displayPct = (percentage * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Jar Lid
        Container(
          width: 50,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.inkBlack,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            border: Border.all(
              color: AppColors.honeyYellow.withOpacity(0.4),
              width: 1.5,
            ),
          ),
        ),
        // Jar Glass Body
        Container(
          width: 82,
          height: 104,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardMutedDark : AppColors.cardMutedLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.inkBlack,
              width: 2.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Ruler Ticks on the left
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 10,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 16,
                    itemBuilder: (context, i) => Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 4),
                      color: AppColors.inkBlack.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              // Animated Honey Liquid
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                width: double.infinity,
                height: 104 * percentage,
                decoration: const BoxDecoration(
                  color: AppColors.honeyAmber,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.inkBlack,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.inkBlack,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.honeyYellow, width: 1),
                    ),
                    child: Text(
                      '$displayPct%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.honeyYellow,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'مؤشر الحمل الآمن',
          style: GoogleFonts.cairo(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white70 : AppColors.inkBlack.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

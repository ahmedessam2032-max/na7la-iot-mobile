import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Sunny Honey (Modern Light Palette)
  static const Color honeyYellow = Color(0xFFFACC15);
  static const Color honeyAmber = Color(0xFFF59E0B);
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color outerYellow = Color(0xFFF8FAFC); // Modern clean background
  static const Color cardSurfaceLight = Color(0xFFFFFFFF);
  static const Color cardMutedLight = Color(0xFFFEF3C7);
  static const Color inkBlack = Color(0xFF0F172A);
  static const Color routerCyan = Color(0xFF0EA5E9);
  static const Color routerBgLight = Color(0xFFF0F9FF);

  // Midnight Hive (Dark Palette)
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkOuter = Color(0xFF0B0F19);
  static const Color cardSurfaceDark = Color(0xFF1E293B);
  static const Color cardMutedDark = Color(0xFF131B2A);
  static const Color cardActiveDark = Color(0xFF332A15);
  static const Color routerBgDark = Color(0xFF0C243B);
  static const Color darkBorder = Color(0xFF334155);
}

class AppTheme {
  static BoxDecoration inkCardDecoration({
    required bool isDark,
    Color? surfaceColor,
    double radius = 24.0,
    double shadowOffset = 4.0,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: surfaceColor ?? (isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0x60000000) : const Color(0x10000000),
          offset: Offset(shadowOffset, shadowOffset),
          blurRadius: shadowOffset * 2,
        ),
      ],
    );
  }

  static ThemeData lightTheme() {
    final baseText = GoogleFonts.cairoTextTheme();
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.honeyYellow,
      scaffoldBackgroundColor: AppColors.lightBg,
      textTheme: baseText.apply(
        bodyColor: AppColors.inkBlack,
        displayColor: AppColors.inkBlack,
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.honeyYellow,
        secondary: AppColors.honeyAmber,
        surface: AppColors.cardSurfaceLight,
      ),
    );
  }

  static ThemeData darkTheme() {
    final baseText = GoogleFonts.cairoTextTheme();
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.honeyYellow,
      scaffoldBackgroundColor: AppColors.darkOuter,
      textTheme: baseText.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.honeyYellow,
        secondary: AppColors.honeyAmber,
        surface: AppColors.cardSurfaceDark,
      ),
    );
  }
}

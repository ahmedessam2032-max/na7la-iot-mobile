import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Sunny Honey (Light Palette)
  static const Color honeyYellow = Color(0xFFF9E04B);
  static const Color honeyAmber = Color(0xFFF59B1B);
  static const Color outerYellow = Color(0xFFE2C835);
  static const Color cardSurfaceLight = Color(0xFFFFFBEB);
  static const Color cardMutedLight = Color(0xFFFEF08A);
  static const Color inkBlack = Color(0xFF18181B);
  static const Color routerCyan = Color(0xFF22D3EE);
  static const Color routerBgLight = Color(0xFFE0F2FE);

  // Midnight Hive (Dark Palette)
  static const Color darkBg = Color(0xFF0F1117);
  static const Color darkOuter = Color(0xFF07080B);
  static const Color cardSurfaceDark = Color(0xFF181B24);
  static const Color cardMutedDark = Color(0xFF13161E);
  static const Color cardActiveDark = Color(0xFF271E14);
  static const Color routerBgDark = Color(0xFF10232B);
  static const Color darkBorder = Color(0xFF32384A);
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
        color: borderColor ?? (isDark ? AppColors.darkBorder : AppColors.inkBlack),
        width: 2.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0xFF060709) : AppColors.inkBlack,
          offset: Offset(shadowOffset, shadowOffset),
          blurRadius: 0,
        ),
      ],
    );
  }

  static ThemeData lightTheme() {
    final baseText = GoogleFonts.cairoTextTheme();
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.honeyYellow,
      scaffoldBackgroundColor: AppColors.outerYellow,
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

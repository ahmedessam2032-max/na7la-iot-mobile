import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand Warm Honey Accents
  static const Color honeyYellow = Color(0xFFF59E0B); // Warm honey amber (replaces washed out yellow)
  static const Color honeyAmber = Color(0xFFD97706);  // Deep amber for high contrast text
  static const Color honeyGlow = Color(0xFFFBBF24);   // Glowing accent for active sockets
  static const Color emeraldActive = Color(0xFF10B981); // Emerald green for active sockets

  // Ceramic Light Palette (High Contrast WCAG AAA)
  static const Color lightBg = Color(0xFFF8FAFC);         // Calm ceramic white background
  static const Color outerYellow = Color(0xFFF8FAFC);
  static const Color cardSurfaceLight = Color(0xFFFFFFFF); // Pure white card
  static const Color cardMutedLight = Color(0xFFF1F5F9);   // Off-socket muted gray
  static const Color borderLight = Color(0xFFE2E8F0);      // Elegant subtle border (no black comic lines)
  static const Color textPrimaryLight = Color(0xFF0F172A); // Deep slate charcoal (100% readable)
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate gray

  // Midnight Obsidian Dark Palette
  static const Color darkOuter = Color(0xFF0B0F19);       // Deep obsidian black
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardSurfaceDark = Color(0xFF131B2A);  // Rich obsidian navy
  static const Color cardMutedDark = Color(0xFF1E293B);    // Off-socket surface
  static const Color cardActiveDark = Color(0xFF1E2638);   // Active socket surface
  static const Color borderDark = Color(0xFF334155);       // Muted slate border
  static const Color textPrimaryDark = Color(0xFFF8FAFC);  // Crisp white
  static const Color textSecondaryDark = Color(0xFF94A3B8);// Light slate gray

  // Protection & Special Roles
  static const Color routerCyan = Color(0xFF0284C7);      // Protected router cyan
  static const Color routerBgLight = Color(0xFFE0F2FE);
  static const Color routerBgDark = Color(0xFF082F49);
  static const Color dangerRed = Color(0xFFEF4444);

  // Backward compatibility alias
  static const Color inkBlack = Color(0xFF0F172A);
  static const Color darkBorder = Color(0xFF334155);
}

class AppTheme {
  static BoxDecoration inkCardDecoration({
    required bool isDark,
    Color? surfaceColor,
    double radius = 20.0,
    double shadowOffset = 2.0,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: surfaceColor ?? (isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? (isDark ? AppColors.borderDark : AppColors.borderLight),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0x50000000) : const Color(0x0A000000),
          offset: Offset(0, shadowOffset),
          blurRadius: shadowOffset * 3,
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
      cardColor: AppColors.cardSurfaceLight,
      dividerColor: AppColors.borderLight,
      textTheme: baseText.apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
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
      cardColor: AppColors.cardSurfaceDark,
      dividerColor: AppColors.borderDark,
      textTheme: baseText.apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.honeyYellow,
        secondary: AppColors.honeyAmber,
        surface: AppColors.cardSurfaceDark,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // WattQ 1.0.27 Emerald Green Primary + Na7la Warm Accents
  static const Color emeraldActive = Color(0xFF10B981);
  static const Color emeraldDeep = Color(0xFF059669);
  static const Color emeraldLightBg = Color(0xFFECFDF5);

  static const Color honeyYellow = Color(0xFFF59E0B);
  static const Color honeyAmber = Color(0xFFD97706);
  static const Color honeyGlow = Color(0xFFFBBF24);

  // Clean Material 3 Light Palette (WattQ 1.0.27 Style)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color outerYellow = Color(0xFFF8FAFC);
  static const Color cardSurfaceLight = Color(0xFFFFFFFF);
  static const Color cardMutedLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Clean Material 3 Dark Slate Palette (WattQ 1.0.27 Dark Mode)
  static const Color darkOuter = Color(0xFF0F172A);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardSurfaceDark = Color(0xFF151F32);
  static const Color cardMutedDark = Color(0xFF1E293B);
  static const Color cardActiveDark = Color(0xFF1E2638);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Protection & Special Roles
  static const Color routerCyan = Color(0xFF0284C7);
  static const Color routerBgLight = Color(0xFFE0F2FE);
  static const Color routerBgDark = Color(0xFF082F49);
  static const Color dangerRed = Color(0xFFEF4444);

  // Backward compatibility aliases
  static const Color inkBlack = Color(0xFF0F172A);
  static const Color darkBorder = Color(0xFF334155);

  // 6 Outlet Custom Colors (WattQ 1.0.27)
  static const List<Map<String, dynamic>> outletPalette = [
    {'hex': '#10B981', 'name': 'أخضر زمردي', 'color': Color(0xFF10B981)},
    {'hex': '#EF4444', 'name': 'أحمر', 'color': Color(0xFFEF4444)},
    {'hex': '#F97316', 'name': 'برتقالي', 'color': Color(0xFFF97316)},
    {'hex': '#EAB308', 'name': 'أصفر ذهبي', 'color': Color(0xFFEAB308)},
    {'hex': '#3B82F6', 'name': 'أزرق', 'color': Color(0xFF3B82F6)},
    {'hex': '#8B5CF6', 'name': 'بنفسجي', 'color': Color(0xFF8B5CF6)},
  ];

  static Color parseHexColor(String? hex, {Color fallback = emeraldActive}) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    try {
      String clean = hex.trim().replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
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
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0x40000000) : const Color(0x0A000000),
          offset: Offset(0, shadowOffset),
          blurRadius: shadowOffset * 4,
        ),
      ],
    );
  }

  static ThemeData lightTheme() {
    final baseText = GoogleFonts.cairoTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.emeraldActive,
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.cardSurfaceLight,
      dividerColor: AppColors.borderLight,
      textTheme: baseText.apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.emeraldActive,
        secondary: AppColors.honeyYellow,
        surface: AppColors.cardSurfaceLight,
      ),
    );
  }

  static ThemeData darkTheme() {
    final baseText = GoogleFonts.cairoTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.emeraldActive,
      scaffoldBackgroundColor: AppColors.darkOuter,
      cardColor: AppColors.cardSurfaceDark,
      dividerColor: AppColors.borderDark,
      textTheme: baseText.apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emeraldActive,
        secondary: AppColors.honeyYellow,
        surface: AppColors.cardSurfaceDark,
      ),
    );
  }
}

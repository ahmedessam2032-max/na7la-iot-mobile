import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../storage/secure_storage.dart';

class AppThemeController extends ChangeNotifier {
  static final AppThemeController instance = AppThemeController._internal();
  AppThemeController._internal();

  bool _isDark = false;
  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    _isDark = await SecureStorageService.isDarkMode();
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    await SecureStorageService.setDarkMode(value);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    await SecureStorageService.setDarkMode(_isDark);
    notifyListeners();
  }
}

class AppColors {
  // WattQ 1.0.27 Emerald Green Primary + Na7la Warm Accents
  static const Color emeraldActive = Color(0xFF10B981);
  static const Color emeraldPrimary = Color(0xFF10B981);
  static const Color emeraldDeep = Color(0xFF059669);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color emeraldLightBg = Color(0xFFECFDF5);
  static const Color emeraldSurfaceLight = Color(0xFFECFDF5);

  static const Color honeyYellow = Color(0xFFF59E0B);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color honeyAmber = Color(0xFFD97706);
  static const Color honeyGlow = Color(0xFFFBBF24);

  // Telemetry Bar Colors
  static const Color telemetryBarLight = Color(0xFFF0FDF4);
  static const Color telemetryBarDark = Color(0xFF1E293B);

  // Clean Material 3 Light Palette (WattQ 1.0.27 Style)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color outerYellow = Color(0xFFF8FAFC);
  static const Color cardSurfaceLight = Color(0xFFFFFFFF);
  static const Color cardMutedLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);

  // Clean Material 3 Dark Slate Palette (WattQ 1.0.27 Dark Mode)
  static const Color darkOuter = Color(0xFF0F172A);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardSurfaceDark = Color(0xFF151F32);
  static const Color cardMutedDark = Color(0xFF1E293B);
  static const Color cardActiveDark = Color(0xFF1E2638);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);

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
    {'hex': '#10B981', 'name': 'أخضر زمردي', 'nameEn': 'Emerald Green', 'color': Color(0xFF10B981)},
    {'hex': '#EF4444', 'name': 'أحمر', 'nameEn': 'Coral Red', 'color': Color(0xFFEF4444)},
    {'hex': '#F97316', 'name': 'برتقالي', 'nameEn': 'Warm Orange', 'color': Color(0xFFF97316)},
    {'hex': '#EAB308', 'name': 'أصفر ذهبي', 'nameEn': 'Golden Amber', 'color': Color(0xFFEAB308)},
    {'hex': '#3B82F6', 'name': 'أزرق', 'nameEn': 'Royal Blue', 'color': Color(0xFF3B82F6)},
    {'hex': '#8B5CF6', 'name': 'بنفسجي', 'nameEn': 'Electric Violet', 'color': Color(0xFF8B5CF6)},
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
  static BoxDecoration cleanCardDecoration({
    required bool isDark,
    Color? surfaceColor,
    double radius = 20.0,
    double shadowOffset = 2.0,
    Color? borderColor,
  }) =>
      inkCardDecoration(
        isDark: isDark,
        surfaceColor: surfaceColor,
        radius: radius,
        shadowOffset: shadowOffset,
        borderColor: borderColor,
      );

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
    final baseText = GoogleFonts.cairoTextTheme().apply(
      bodyColor: AppColors.textPrimaryLight,
      displayColor: AppColors.textPrimaryLight,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.emeraldActive,
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.cardSurfaceLight,
      canvasColor: AppColors.cardSurfaceLight,
      dividerColor: AppColors.borderLight,
      textTheme: baseText,
      iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardMutedLight,
        selectedColor: AppColors.emeraldActive.withOpacity(0.18),
        side: const BorderSide(color: AppColors.borderLight),
        labelStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryLight,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
        secondaryLabelStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryLight,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return AppColors.textPrimaryLight;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.emeraldActive;
            return AppColors.cardMutedLight;
          }),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.borderLight)),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cardSurfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
        titleTextStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryLight,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.cardSurfaceLight,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryLight,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryLight,
          fontSize: 13,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardSurfaceLight,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimaryLight,
        iconColor: AppColors.textPrimaryLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardMutedLight,
        labelStyle: GoogleFonts.cairo(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w700),
        hintStyle: GoogleFonts.cairo(color: AppColors.textSecondaryLight),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emeraldActive, width: 1.6),
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.emeraldActive,
        secondary: AppColors.emeraldActive,
        surface: AppColors.cardSurfaceLight,
        onSurface: AppColors.textPrimaryLight,
        onPrimary: Colors.white,
      ),
    );
  }

  static ThemeData darkTheme() {
    final baseText = GoogleFonts.cairoTextTheme().apply(
      bodyColor: AppColors.textPrimaryDark,
      displayColor: AppColors.textPrimaryDark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.emeraldActive,
      scaffoldBackgroundColor: AppColors.darkOuter,
      cardColor: AppColors.cardSurfaceDark,
      canvasColor: AppColors.cardSurfaceDark,
      dividerColor: AppColors.borderDark,
      textTheme: baseText,
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardMutedDark,
        selectedColor: AppColors.emeraldActive.withOpacity(0.24),
        side: const BorderSide(color: AppColors.borderDark),
        labelStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryDark,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
        secondaryLabelStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryDark,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return AppColors.textPrimaryDark;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.emeraldActive;
            return AppColors.cardMutedDark;
          }),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.borderDark)),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cardSurfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
        titleTextStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryDark,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.cardSurfaceDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryDark,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: GoogleFonts.cairo(
          color: AppColors.textPrimaryDark,
          fontSize: 13,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardSurfaceDark,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimaryDark,
        iconColor: AppColors.textPrimaryDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardMutedDark,
        labelStyle: GoogleFonts.cairo(color: AppColors.textSecondaryDark, fontWeight: FontWeight.w700),
        hintStyle: GoogleFonts.cairo(color: AppColors.textSecondaryDark),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emeraldActive, width: 1.6),
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emeraldActive,
        secondary: AppColors.emeraldActive,
        surface: AppColors.cardSurfaceDark,
        onSurface: AppColors.textPrimaryDark,
        onPrimary: Colors.white,
      ),
    );
  }
}

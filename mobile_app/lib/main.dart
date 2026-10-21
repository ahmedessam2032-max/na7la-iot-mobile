import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/secure_storage.dart';
import 'core/localization/app_locale.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await AppLocaleController.instance.init();
  final token = await SecureStorageService.getToken();
  final isDark = await SecureStorageService.isDarkMode();

  runApp(
    ProviderScope(
      child: Na7laApp(
        initialHasToken: token != null && token.isNotEmpty,
        initialDarkMode: isDark,
      ),
    ),
  );
}

class Na7laApp extends StatelessWidget {
  final bool initialHasToken;
  final bool initialDarkMode;

  const Na7laApp({
    super.key,
    required this.initialHasToken,
    required this.initialDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocaleController.instance,
      builder: (context, _) {
        final localeCtrl = AppLocaleController.instance;
        return MaterialApp(
          title: localeCtrl.tr('app_title'),
          debugShowCheckedModeBanner: false,
          locale: localeCtrl.locale,
          supportedLocales: const [
            Locale('ar', 'EG'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: initialDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: initialHasToken ? const HomeDashboardScreen() : const LoginScreen(),
        );
      },
    );
  }
}

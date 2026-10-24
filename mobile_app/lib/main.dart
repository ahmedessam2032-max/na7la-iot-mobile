import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/secure_storage.dart';
import 'core/localization/app_locale.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_dashboard_screen.dart';
import 'widgets/app_lock_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLocaleController.instance.init();
  await AppThemeController.instance.init();
  final token = await SecureStorageService.getToken();

  runApp(
    ProviderScope(
      child: Na7laApp(
        initialHasToken: token != null && token.isNotEmpty,
      ),
    ),
  );
}

class Na7laApp extends StatelessWidget {
  final bool initialHasToken;

  const Na7laApp({
    super.key,
    required this.initialHasToken,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppLocaleController.instance,
        AppThemeController.instance,
      ]),
      builder: (context, _) {
        final localeCtrl = AppLocaleController.instance;
        final themeCtrl = AppThemeController.instance;

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: themeCtrl.isDark ? Brightness.light : Brightness.dark,
          ),
        );

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
          themeMode: themeCtrl.themeMode,
          home: initialHasToken ? const AppLockGate(child: HomeDashboardScreen()) : const LoginScreen(),
        );
      },
    );
  }
}

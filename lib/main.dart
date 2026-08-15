import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await AuthService.instance.initializeGoogleSignIn();

  runApp(const AracGiderTakipApp());
}

class AracGiderTakipApp extends StatelessWidget {
  const AracGiderTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Araç Gider Takip',
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: isDark
                    ? Brightness.dark
                    : Brightness.light,
                systemNavigationBarColor: isDark ? Colors.black : Colors.white,
                systemNavigationBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarDividerColor: isDark
                    ? Colors.black
                    : Colors.white,
                systemNavigationBarContrastEnforced: false,
                systemStatusBarContrastEnforced: false,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthGate(),
        );
      },
    );
  }
}

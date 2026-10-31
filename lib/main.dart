import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home.dart';
import 'lock_screen.dart';
import 'notification_service.dart';
import 'security_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await SecurityService.instance.checkInitialLock();
  runApp(const SereneApp());
}

class SereneApp extends StatefulWidget {
  const SereneApp({super.key});
  @override
  State<SereneApp> createState() => _SereneAppState();
}

class _SereneAppState extends State<SereneApp> {
  Locale _locale = const Locale('ar'); // Default warmly to Arabic or user selection

  @override
  Widget build(BuildContext context) {
    const primarySeed = Color(0xFF356B60); // Serene Sage & Sea

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Serene',
      locale: _locale,
      supportedLocales: const [
        Locale('ar'),
        Locale('fr'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.system,
      // Calming light theme
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.light,
          surface: const Color(0xFFF9FAF9),
          surfaceContainerHighest: const Color(0xFFE8EFEA),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 2,
          indicatorColor: primarySeed.withValues(alpha: 0.18),
        ),
      ),
      // Calming, gentle dark theme (soft on eyes during late-night distress)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.dark,
          surface: const Color(0xFF131816),
          surfaceContainerHighest: const Color(0xFF1D2421),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 2,
          indicatorColor: primarySeed.withValues(alpha: 0.3),
        ),
      ),
      home: ListenableBuilder(
        listenable: SecurityService.instance,
        builder: (ctx, _) {
          if (SecurityService.instance.isLocked) {
            return LockScreen(
              onUnlocked: () => SecurityService.instance.unlock(),
            );
          }
          return Gate(onLocale: (newLocale) => setState(() => _locale = newLocale));
        },
      ),
    );
  }
}

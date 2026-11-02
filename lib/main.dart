import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home.dart';
import 'lock_screen.dart';
import 'notification_service.dart';
import 'responsive.dart';
import 'security_service.dart';
import 'splash_screen.dart';
import 'storage.dart';
import 'theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nothing that runs before the first frame may be able to leave the app
  // stuck on the native launch screen. Every start-up step is best-effort and
  // the whole sequence has a deadline: if one plugin misbehaves we log it and
  // still open the UI instead of showing a blank screen forever.
  await _startUp().timeout(const Duration(seconds: 10), onTimeout: () {});
  runApp(const SereneApp());
}

Future<void> _startUp() async {
  // Remove personal data that older builds wrote to the phone. Best effort and
  // cheap: the keys are simply absent on a fresh install.
  await _attempt('clearing legacy data', Store.purgeLegacyPersonalData);
  // Load the saved appearance first so the splash already uses it.
  await _attempt('loading the theme', ThemeService.instance.load);
  await _attempt('initialising notifications', NotificationService.instance.init);
  // Re-create the daily reminder so a timezone/DST change is reflected even
  // if the user does not open settings again. The saved preference is kept on
  // failure; the next successful launch retries.
  await _attempt(
    'restoring the daily reminder',
    NotificationService.instance.restoreScheduleIfEnabled,
  );
  await _attempt('checking the app lock', SecurityService.instance.checkInitialLock);
}

/// Runs one start-up step, reporting — never rethrowing — its failure.
Future<void> _attempt(String label, Future<void> Function() step) async {
  try {
    await step();
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'serene',
        context: ErrorDescription('while $label'),
      ),
    );
  }
}

class SereneApp extends StatefulWidget {
  const SereneApp({super.key});
  @override
  State<SereneApp> createState() => _SereneAppState();
}

class _SereneAppState extends State<SereneApp> with WidgetsBindingObserver {
  static const _supportedCodes = {'ar', 'fr', 'en'};

  Locale _locale =
      const Locale('fr'); // French is the default first-run language
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeService.instance.addListener(_onThemeChanged);
    _restoreLocale();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  /// Leaving the app locks it again. The salted PIN hash is saved in encrypted
  /// storage, so the lock also survives a full restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // The system biometric prompt can briefly pause the activity. Locking
      // then would immediately re-show the lock screen the user just cleared.
      if (SecurityService.instance.isAuthenticating) return;
      unawaited(_lockIfPinSet());
    }
  }

  Future<void> _lockIfPinSet() async {
    try {
      if (await SecurityService.instance.isLockEnabled()) {
        SecurityService.instance.lock();
      }
    } catch (_) {
      // Never block the app on a storage hiccup.
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  /// Keeps the language the user picked last time, so the very first
  /// "welcome back" screen already speaks their language.
  Future<void> _restoreLocale() async {
    try {
      final code = await Store.getString('locale');
      if (code != null && _supportedCodes.contains(code)) {
        Store.setLocaleHint(code);
        if (mounted) setState(() => _locale = Locale(code));
        return;
      }
    } catch (_) {
      // Fall back to the default language if storage is unavailable.
    }
    // First launch: the hotline country follows the default app language
    // instead of staying on the last hard-coded fallback.
    Store.setLocaleHint(_locale.languageCode);
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
    Store.setLocaleHint(locale.languageCode);
    Store.setString('locale', locale.languageCode);
  }

  Widget _buildHome() {
    return ListenableBuilder(
      listenable: SecurityService.instance,
      builder: (ctx, _) {
        if (SecurityService.instance.isLocked) {
          return LockScreen(
            onUnlocked: () => SecurityService.instance.unlock(),
          );
        }
        return Gate(onLocale: _setLocale);
      },
    );
  }

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
      themeMode: ThemeService.instance.mode,
      // Adapt text and spacing to the device (small phones, tablets, and the
      // user's accessibility font size) without touching every screen.
      builder: Responsive.wrap,
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
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _showSplash
            ? SplashScreen(
                key: const ValueKey('splash'),
                onFinished: () => setState(() => _showSplash = false),
              )
            : KeyedSubtree(
                key: const ValueKey('app'),
                child: _buildHome(),
              ),
      ),
    );
  }
}

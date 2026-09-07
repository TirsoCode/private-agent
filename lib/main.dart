import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:developer';
import 'config/feature_flags.dart';
import 'config/responsive.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'overlay_main.dart';
import 'services/crash_log.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: Colors.white,
        dialogBackgroundColor: Colors.transparent,
        primaryColor: const Color(0xFF4F46E5),
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          background: Colors.transparent,
          primary: Color(0xFF4F46E5),
          surface: Colors.white,
          onSurface: Color(0xFF1E293B),
          onPrimary: Colors.white,
        ),
      ),
      builder: (context, child) {
        return Container(color: Colors.transparent, child: child);
      },
      home: const OverlayApp(),
    ),
  );
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void Function(String task)? onOverlayTask;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    FlutterError.onError = (details) {
      CrashLog.record(
        details.exception,
        details.stack,
        'FlutterError',
      );
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      CrashLog.record(error, stack, 'platform');
      return true;
    };

    if (FeatureFlags.floatingOverlayEnabled) {
      FlutterOverlayWindow.overlayListener.listen((event) {
        log("Main app received from overlay: $event");
        if (event is String && event.trim().isNotEmpty) {
          if (onOverlayTask != null) {
            onOverlayTask!(event.trim());
          } else {
            log("Warning: overlay task received but no handler registered yet");
          }
        }
      });
    }

    bool onboardingCompleted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('themeMode');
      if (themeStr == 'dark') {
        themeNotifier.value = ThemeMode.dark;
      } else {
        themeNotifier.value = ThemeMode.light;
      }
      onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    } catch (e, st) {
      CrashLog.record(e, st, 'main_prefs');
      onboardingCompleted = false;
    }

    runApp(PrivateAgentApp(onboardingCompleted: onboardingCompleted));
  }, (error, stack) {
    CrashLog.record(error, stack, 'zone');
  });
}

class PrivateAgentApp extends StatefulWidget {
  final bool onboardingCompleted;
  const PrivateAgentApp({super.key, required this.onboardingCompleted});

  @override
  State<PrivateAgentApp> createState() => _PrivateAgentAppState();
}

class _PrivateAgentAppState extends State<PrivateAgentApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CrashLog.showRecoveryDialogIfNeeded(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).shortestSide < 340;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          title: 'PrivateAgent',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          builder: (context, child) {
            // Adapt text size to small screens (e.g. 3.0" Doogee U10).
            final scale = screenTextScale(MediaQuery.sizeOf(context));
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF4F46E5), // Indigo-600
            scaffoldBackgroundColor: const Color(
              0xFFF8FAFC,
            ), // Slate-50 background
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5), // Indigo-600
              secondary: Color(0xFF0EA5E9), // Sky-500
              surface: Color(0xFFFFFFFF),
              onSurface: Color(0xFF1E293B), // Slate-800
              surfaceContainerHighest: Color(0xFFF1F5F9), // Slate-100
              error: Colors.redAccent,
            ),
            useMaterial3: true,
            visualDensity: compact
                ? VisualDensity.compact
                : VisualDensity.standard,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            appBarTheme: AppBarTheme(
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: compact ? 44 : null,
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFF1E293B),
              iconTheme: IconThemeData(color: Color(0xFF1E293B)),
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xFFFFFFFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1.2,
                ), // Slate-200
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF6366F1), // Indigo-500
            scaffoldBackgroundColor: const Color(
              0xFF0B0F19,
            ), // Midnight deep slate
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1), // Indigo-500
              secondary: Color(0xFF38BDF8), // Sky-400
              surface: Color(0xFF151D30), // Midnight gray-blue card background
              onSurface: Color(0xFFF8FAFC), // Slate-50 text
              surfaceContainerHighest: Color(0xFF1E293B), // Slate-800
              error: Colors.redAccent,
            ),
            useMaterial3: true,
            visualDensity: compact
                ? VisualDensity.compact
                : VisualDensity.standard,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            appBarTheme: AppBarTheme(
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: compact ? 44 : null,
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFFF8FAFC),
              iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xFF151D30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFF243049).withOpacity(0.4),
                  width: 1.2,
                ),
              ),
            ),
          ),
          home: widget.onboardingCompleted
              ? const HomeScreen()
              : const OnboardingScreen(),
        );
      },
    );
  }
}
